//
//  AttendanceSheet.swift
//  DiaCalendar2
//

import SwiftUI

struct AttendanceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let loadTypes: () async -> [AttendanceTypeDTO]
    let onConfirm: (AttendanceTypeDTO, _ days: Int) -> Void

    @State private var types: [AttendanceTypeDTO] = []
    @State private var selectedTypeId: UUID?
    @State private var days: Int = 1

    private static let dayRange = Array(1...10)

    private var selectedType: AttendanceTypeDTO? {
        types.first { $0.id == selectedTypeId }
    }

    // 1. 저장 버튼 활성화 조건 분리
    private var isSaveDisabled: Bool {
        selectedType == nil
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

                Section("휴가 종류") {
                    if types.isEmpty {
                        Text("등록된 휴가 종류가 없습니다.\nSettings → 휴가 종류 편집에서 먼저 등록해주세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("종류", selection: $selectedTypeId) {
                            Text("선택").tag(UUID?.none)
                            ForEach(types) { t in
                                Text("\(t.name) (\(t.shortName))").tag(Optional(t.id))
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
                    Text("휴가는 며칠 연속 등록할 수 있으며 모든 날 같은 종류로 표시됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("근태 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                // 2. 상단 저장 버튼 (분리된 로직 사용)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        saveAttendance()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            // 3. 화면 하단에 큼직한 저장 버튼 고정
            .safeAreaInset(edge: .bottom) {
                bottomSaveButton
            }
            .task {
                types = await loadTypes()
                if selectedTypeId == nil { selectedTypeId = types.first?.id }
            }
        }
    }

    // MARK: - Subviews & Methods

    // 4. 하단 고정 저장 버튼 뷰
    private var bottomSaveButton: some View {
        VStack {
            Button {
                saveAttendance()
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
    private func saveAttendance() {
        guard let t = selectedType else { return }
        onConfirm(t, days)
        dismiss()
    }
}

//import SwiftUI
//
//struct AttendanceSheet: View {
//    @Environment(\.dismiss) private var dismiss
//
//    let date: Date
//    let loadTypes: () async -> [AttendanceTypeDTO]
//    let onConfirm: (AttendanceTypeDTO, _ days: Int) -> Void
//
//    @State private var types: [AttendanceTypeDTO] = []
//    @State private var selectedTypeId: UUID?
//    @State private var days: Int = 1
//
//    private static let dayRange = Array(1...10)
//
//    private var selectedType: AttendanceTypeDTO? {
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
//                Section("휴가 종류") {
//                    if types.isEmpty {
//                        Text("등록된 휴가 종류가 없습니다.\nSettings → 휴가 종류 편집에서 먼저 등록해주세요.")
//                            .font(.caption)
//                            .foregroundStyle(.secondary)
//                    } else {
//                        Picker("종류", selection: $selectedTypeId) {
//                            Text("선택").tag(UUID?.none)
//                            ForEach(types) { t in
//                                Text("\(t.name) (\(t.shortName))").tag(Optional(t.id))
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
//                    Text("휴가는 며칠 연속 등록할 수 있으며 모든 날 같은 종류로 표시됩니다.")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                }
//            }
//            .navigationTitle("근태 등록")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .topBarLeading) {
//                    Button("취소") { dismiss() }
//                }
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button("저장") {
//                        guard let t = selectedType else { return }
//                        onConfirm(t, days)
//                        dismiss()
//                    }
//                    .disabled(selectedType == nil)
//                }
//            }
//            .task {
//                types = await loadTypes()
//                if selectedTypeId == nil { selectedTypeId = types.first?.id }
//            }
//        }
//    }
//}
