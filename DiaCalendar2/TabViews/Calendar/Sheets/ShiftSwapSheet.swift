//
//  ShiftSwapSheet.swift
//  DiaCalendar2
//


import SwiftUI

struct ShiftSwapSheet: View {
    @Environment(\.dismiss) private var dismiss

    let date: Date
    /// "기준 근무" 옵션 (office.diaSelects 우선, 없으면 패턴). ShiftSetup의 4단계와 동일한 데이터.
    let loadOptions: () async -> [String]
    let onConfirm: (_ targetShiftName: String, _ days: Int) -> Void

    @State private var options: [String] = []
    @State private var selected: String = ""
    @State private var days: Int = 1

    private static let dayRange = Array(1...10)

    // 1. 저장 버튼 활성화 조건 분리
    private var isSaveDisabled: Bool {
        selected.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "시작 날짜",
                        selection: .constant(date),
                        displayedComponents: .date
                    )
                    .disabled(true)
                }

                Section("교체할 근무") {
                    if options.isEmpty {
                        Text("선택 가능한 근무가 없습니다. 먼저 교번을 설정해주세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("시작 근무", selection: $selected) {
                            Text("선택").tag("")
                            ForEach(Array(options.enumerated()), id: \.offset) { _, name in
                                Text(name).tag(name)
                            }
                        }
                    }
                }

                Section("교체 일수") {
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
            .navigationTitle("교번교체")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                // 2. 상단 저장 버튼 (분리된 로직 사용)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        saveShiftSwap()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            // 3. 화면 하단에 큼직한 저장 버튼 고정
            .safeAreaInset(edge: .bottom) {
                bottomSaveButton
            }
            .task {
                options = await loadOptions()
            }
        }
    }

    // MARK: - Subviews & Methods

    // 4. 하단 고정 저장 버튼 뷰
    private var bottomSaveButton: some View {
        VStack {
            Button {
                saveShiftSwap()
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
    private func saveShiftSwap() {
        onConfirm(selected, days)
        dismiss()
    }
}

//import SwiftUI
//
//struct ShiftSwapSheet: View {
//    @Environment(\.dismiss) private var dismiss
//
//    let date: Date
//    /// "기준 근무" 옵션 (office.diaSelects 우선, 없으면 패턴). ShiftSetup의 4단계와 동일한 데이터.
//    let loadOptions: () async -> [String]
//    let onConfirm: (_ targetShiftName: String, _ days: Int) -> Void
//
//    @State private var options: [String] = []
//    @State private var selected: String = ""
//    @State private var days: Int = 1
//
//    private static let dayRange = Array(1...10)
//
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section {
//                    DatePicker(
//                        "시작 날짜",
//                        selection: .constant(date),
//                        displayedComponents: .date
//                    )
//                    .disabled(true)
//                }
//
//                Section("교체할 근무") {
//                    if options.isEmpty {
//                        Text("선택 가능한 근무가 없습니다. 먼저 교번을 설정해주세요.")
//                            .font(.caption)
//                            .foregroundStyle(.secondary)
//                    } else {
//                        Picker("시작 근무", selection: $selected) {
//                            Text("선택").tag("")
//                            ForEach(Array(options.enumerated()), id: \.offset) { _, name in
//                                Text(name).tag(name)
//                            }
//                        }
//                    }
//                }
//
//                Section("교체 일수") {
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
//            .navigationTitle("교번교체")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .topBarLeading) {
//                    Button("취소") { dismiss() }
//                }
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button("저장") {
//                        onConfirm(selected, days)
//                        dismiss()
//                    }
//                    .disabled(selected.isEmpty)
//                }
//            }
//            .task {
//                options = await loadOptions()
//            }
//        }
//    }
//}
