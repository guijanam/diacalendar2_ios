//
//  AttendanceTypeListView.swift
//  DiaCalendar2
//
//  휴가 종류(근태) CRUD 화면.
//  사용자가 이름과 달력 표시 약어를 자유롭게 편집/추가/삭제.
//

import SwiftUI

/// 편집 시트의 모드. `sheet(item:)`을 사용해 SwiftUI가 시점을 명확히 캡처하도록 한다.
/// (`isPresented:` + 별도 state로 했을 때 스와이프 편집이 가끔 "추가" 화면으로 뜨던 문제 회피)
private enum AttendanceEditorRoute: Identifiable {
    case create
    case edit(AttendanceTypeDTO)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let dto): return dto.id.uuidString
        }
    }

    var initial: AttendanceTypeDTO? {
        if case .edit(let dto) = self { return dto }
        return nil
    }
}

struct AttendanceTypeListView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var items: [AttendanceTypeDTO] = []
    @State private var editorRoute: AttendanceEditorRoute?

    var body: some View {
        List {
            if items.isEmpty {
                Text("등록된 휴가 종류가 없습니다.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Text(item.shortName)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(HolidayPalette.red)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Text(item.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if let limit = item.limitCount, limit > 0 {
                            Text("\(limit)일")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                await env.attendanceTypeRepository.delete(id: item.id)
                                await reload()
                            }
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        Button {
                            editorRoute = .edit(item)
                        } label: {
                            Label("편집", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("휴가 종류 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorRoute = .create
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editorRoute) { route in
            NavigationStack {
                AttendanceTypeEditView(initial: route.initial) { name, shortName, limit, month, day in
                    let id = route.initial?.id
                    Task {
                        _ = await env.attendanceTypeRepository.upsert(
                            id: id,
                            name: name,
                            shortName: shortName,
                            limitCount: limit,
                            resetMonth: month,
                            resetDay: day
                        )
                        await reload()
                    }
                }
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        items = await env.attendanceTypeRepository.all()
    }
}

struct AttendanceTypeEditView: View {
    @Environment(\.dismiss) private var dismiss
    let initial: AttendanceTypeDTO?
    let onSave: (_ name: String, _ shortName: String,
                 _ limitCount: Int?, _ resetMonth: Int?, _ resetDay: Int?) -> Void

    @State private var name: String = ""
    @State private var shortName: String = ""
    @State private var limitEnabled: Bool = false
    @State private var limitCount: Int = 15
    @State private var resetEnabled: Bool = true
    @State private var resetMonth: Int = 1
    @State private var resetDay: Int = 1

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !shortName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("이름") {
                TextField("예: 연차", text: $name)
            }
            Section {
                TextField("예: 연", text: $shortName)
            } header: {
                Text("달력 표시 약어")
            } footer: {
                Text("달력 셀에 표시될 짧은 문자열입니다. 1~3자 권장.")
            }

            Section {
                Toggle("사용 갯수 제한", isOn: $limitEnabled)
                if limitEnabled {
                    Stepper("총 갯수: \(limitCount)일", value: $limitCount, in: 1...365)
                }
            } header: {
                Text("총 갯수")
            } footer: {
                Text("끄면 무제한으로 표시됩니다. 내정보 탭의 근태내역에서 사용 현황을 확인할 수 있습니다.")
            }

            Section {
                Toggle("주기별 초기화", isOn: $resetEnabled)
                if resetEnabled {
                    Picker("월", selection: $resetMonth) {
                        ForEach(1...12, id: \.self) { Text("\($0)월").tag($0) }
                    }
                    Picker("일", selection: $resetDay) {
                        ForEach(1...maxDay(month: resetMonth), id: \.self) { Text("\($0)일").tag($0) }
                    }
                }
            } header: {
                Text("초기화 날짜")
            } footer: {
                Text("기본값은 매년 1월 1일입니다. 회계연도 등 다른 기준일을 쓰는 경우 변경하세요.")
            }
        }
        .navigationTitle(initial == nil ? "새 휴가 종류" : "휴가 종류 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") {
                    onSave(
                        name.trimmingCharacters(in: .whitespaces),
                        shortName.trimmingCharacters(in: .whitespaces),
                        limitEnabled ? limitCount : nil,
                        resetEnabled ? resetMonth : nil,
                        resetEnabled ? resetDay : nil
                    )
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .onChange(of: resetMonth) { _, newMonth in
            let cap = maxDay(month: newMonth)
            if resetDay > cap { resetDay = cap }
        }
        .onAppear {
            if let initial {
                name = initial.name
                shortName = initial.shortName
                if let n = initial.limitCount, n > 0 {
                    limitEnabled = true
                    limitCount = n
                }
                if let m = initial.resetMonth, let d = initial.resetDay {
                    resetEnabled = true
                    resetMonth = m
                    resetDay = d
                } else {
                    resetEnabled = false
                }
            }
        }
    }

    private func maxDay(month: Int) -> Int {
        // 윤년 영향을 받지 않게 평년 기준 (2월 28일까지).
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return 28
        default: return 31
        }
    }
}
