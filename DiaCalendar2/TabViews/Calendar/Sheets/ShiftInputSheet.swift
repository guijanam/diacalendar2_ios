//
//  ShiftInputSheet.swift
//  DiaCalendar2
//

import SwiftUI

struct ShiftInputSheet: View {
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let loadTypes: () async -> [ShiftInputTypeDTO]
    /// "기준 근무" 옵션 (office.diaSelects 우선, 없으면 패턴). ShiftSetup의 4단계와 동일한 데이터.
    let loadOptions: () async -> [String]
    /// 해당 날짜에 지근이 설정되어 있는지 확인. 지근충당 등록 제한에 사용.
    let isJiGeunDay: (Date) async -> Bool
    let onConfirm: (ShiftInputTypeDTO, _ days: Int, _ targetShiftName: String) -> Void

    @State private var types: [ShiftInputTypeDTO] = []
    @State private var options: [String] = []
    @State private var selectedTypeId: UUID?
    @State private var selectedTarget: String = ""
    @State private var days: Int = 1
    /// 현재 선택된 유형/일수 기준으로 지근충당 제한을 통과했는지.
    /// 지근충당이 아닌 경우 항상 true.
    @State private var jiGeunCheckPassed = true

    private static let dayRange = Array(1...10)

    /// "지근충당" 식별 이름. 이 이름의 유형은 지근이 설정된 날에만 등록 가능.
    private static let jiGeunInputName = "지근충당"

    private var selectedType: ShiftInputTypeDTO? {
        types.first { $0.id == selectedTypeId }
    }

    /// 선택된 유형이 지근충당인지.
    private var isJiGeunInput: Bool {
        selectedType?.name == Self.jiGeunInputName
    }

    // 1. 저장 버튼 활성화 조건 분리
    private var isSaveDisabled: Bool {
        selectedType == nil || selectedTarget.isEmpty || (isJiGeunInput && !jiGeunCheckPassed)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "시작일",
                        selection: .constant(date),
                        displayedComponents: .date
                    )
                    .disabled(true)
                }

                Section("충당 유형") {
                    if types.isEmpty {
                        ProgressView()
                    } else {
                        Picker("유형", selection: $selectedTypeId) {
                            Text("선택").tag(UUID?.none)
                            ForEach(types) { t in
                                HStack {
                                    Circle()
                                        .fill(Color(hex: t.colorHex) ?? .gray)
                                        .frame(width: 10, height: 10)
                                    Text(t.name)
                                }
                                .tag(Optional(t.id))
                            }
                        }
                    }
                    if isJiGeunInput && !jiGeunCheckPassed {
                        Label(
                            days > 1
                                ? "지근충당은 등록 범위의 모든 날에 지근이 설정되어 있어야 합니다."
                                : "지근충당은 지근이 설정된 날에만 등록할 수 있습니다.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }

                Section("교체할 근무") {
                    if options.isEmpty {
                        Text("교번 설정이 필요합니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("시작 근무", selection: $selectedTarget) {
                            Text("선택").tag("")
                            ForEach(Array(options.enumerated()), id: \.offset) { _, name in
                                Text(name).tag(name)
                            }
                        }
                    }
                }

                Section("일수") {
                    Picker("일수", selection: $days) {
                        ForEach(Self.dayRange, id: \.self) { n in
                            Text("\(n)일").tag(n)
                        }
                    }
                    Text("2일 이상이면 시작 근무부터 교번 순서대로 순차 교체됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("충당 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                // 2. 상단 저장 버튼 (분리된 로직 사용)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        saveShiftInput()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            // 3. 화면 하단에 큼직한 저장 버튼 고정
            .safeAreaInset(edge: .bottom) {
                bottomSaveButton
            }
            .task {
                async let t = loadTypes()
                async let o = loadOptions()
                types = await t
                options = await o
                if selectedTypeId == nil { selectedTypeId = types.first?.id }
                await refreshJiGeunCheck()
            }
            .onChange(of: selectedTypeId) { _, _ in
                Task { await refreshJiGeunCheck() }
            }
            .onChange(of: days) { _, _ in
                Task { await refreshJiGeunCheck() }
            }
        }
    }

    /// 지근충당일 때 등록 범위(시작일 ~ 시작일+days-1)의 모든 날에 지근이 설정됐는지 확인한다.
    /// 지근충당이 아니면 항상 통과.
    private func refreshJiGeunCheck() async {
        guard isJiGeunInput else {
            jiGeunCheckPassed = true
            return
        }
        let cal = Calendar.current
        let baseDay = cal.startOfDay(for: date)
        for offset in 0..<days {
            guard let day = cal.date(byAdding: .day, value: offset, to: baseDay) else { continue }
            if await isJiGeunDay(day) == false {
                jiGeunCheckPassed = false
                return
            }
        }
        jiGeunCheckPassed = true
    }

    // MARK: - Subviews & Methods

    // 4. 하단 고정 저장 버튼 뷰
    private var bottomSaveButton: some View {
        VStack {
            Button {
                saveShiftInput()
            } label: {
                Text("저장")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(isSaveDisabled ? Color.gray.opacity(0.5) : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(isSaveDisabled)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    // 5. 저장 실행 로직 분리
    private func saveShiftInput() {
        guard let t = selectedType, !isSaveDisabled else { return }
        onConfirm(t, days, selectedTarget)
        dismiss()
    }
}

//import SwiftUI
//
//struct ShiftInputSheet: View {
//    @Environment(\.dismiss) private var dismiss
//
//    let date: Date
//    let loadTypes: () async -> [ShiftInputTypeDTO]
//    /// "기준 근무" 옵션 (office.diaSelects 우선, 없으면 패턴). ShiftSetup의 4단계와 동일한 데이터.
//    let loadOptions: () async -> [String]
//    let onConfirm: (ShiftInputTypeDTO, _ days: Int, _ targetShiftName: String) -> Void
//
//    @State private var types: [ShiftInputTypeDTO] = []
//    @State private var options: [String] = []
//    @State private var selectedTypeId: UUID?
//    @State private var selectedTarget: String = ""
//    @State private var days: Int = 1
//
//    private static let dayRange = Array(1...10)
//
//    private var selectedType: ShiftInputTypeDTO? {
//        types.first { $0.id == selectedTypeId }
//    }
//
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section {
//                    DatePicker(
//                        "시작일",
//                        selection: .constant(date),
//                        displayedComponents: .date
//                    )
//                    .disabled(true)
//                }
//
//                Section("충당 유형") {
//                    if types.isEmpty {
//                        ProgressView()
//                    } else {
//                        Picker("유형", selection: $selectedTypeId) {
//                            Text("선택").tag(UUID?.none)
//                            ForEach(types) { t in
//                                HStack {
//                                    Circle()
//                                        .fill(Color(hex: t.colorHex) ?? .gray)
//                                        .frame(width: 10, height: 10)
//                                    Text(t.name)
//                                }
//                                .tag(Optional(t.id))
//                            }
//                        }
//                    }
//                }
//
//                Section("교체할 근무") {
//                    if options.isEmpty {
//                        Text("교번 설정이 필요합니다.")
//                            .font(.caption)
//                            .foregroundStyle(.secondary)
//                    } else {
//                        Picker("시작 근무", selection: $selectedTarget) {
//                            Text("선택").tag("")
//                            ForEach(Array(options.enumerated()), id: \.offset) { _, name in
//                                Text(name).tag(name)
//                            }
//                        }
//                    }
//                }
//
//                Section("일수") {
//                    Picker("일수", selection: $days) {
//                        ForEach(Self.dayRange, id: \.self) { n in
//                            Text("\(n)일").tag(n)
//                        }
//                    }
//                    Text("2일 이상이면 시작 근무부터 교번 순서대로 순차 교체됩니다.")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                }
//            }
//            .navigationTitle("충당 등록")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .topBarLeading) {
//                    Button("취소") { dismiss() }
//                }
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button("저장") {
//                        guard let t = selectedType else { return }
//                        onConfirm(t, days, selectedTarget)
//                        dismiss()
//                    }
//                    .disabled(selectedType == nil || selectedTarget.isEmpty)
//                }
//            }
//            .task {
//                async let t = loadTypes()
//                async let o = loadOptions()
//                types = await t
//                options = await o
//                if selectedTypeId == nil { selectedTypeId = types.first?.id }
//            }
//        }
//    }
//}
