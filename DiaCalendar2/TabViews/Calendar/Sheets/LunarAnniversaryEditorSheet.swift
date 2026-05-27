//
//  LunarAnniversaryEditorSheet.swift
//  DiaCalendar2
//

import SwiftUI

struct LunarAnniversaryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: LunarAnniversaryEditorMode
    let onSave: (LunarAnniversaryDTO) -> Void
    let onDelete: ((UUID) -> Void)?

    @State private var title: String = ""
    @State private var lunarMonth: Int = 1
    @State private var lunarDay: Int = 1
    @State private var isLeapMonth: Bool = false
    @State private var colorHex: String = DateMemoDTO.defaultColorHex
    @State private var existingId: UUID? = nil
    @State private var showDeleteAlert: Bool = false

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var computedSolarDate: Date? {
        LunarSolarConverter.solarDate(
            lunarYear: Calendar.current.component(.year, from: Date()),
            lunarMonth: lunarMonth,
            lunarDay: lunarDay,
            isLeapMonth: isLeapMonth,
            calendar: Calendar.current
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("제목") {
                    TextField("예: 어머니 생신", text: $title)
                }

                Section {
                    Picker("월", selection: $lunarMonth) {
                        ForEach(1...12, id: \.self) { Text(String(format: "%d월", $0)).tag($0) }
                    }
                    Picker("일", selection: $lunarDay) {
                        ForEach(1...30, id: \.self) { Text(String(format: "%d일", $0)).tag($0) }
                    }
                    Toggle("윤달", isOn: $isLeapMonth)
                } header: {
                    Text("음력 날짜")
                } footer: {
                    Text("매년 해당 음력 날짜의 양력 날짜에 기념일이 표시됩니다.")
                }

                Section("올해 양력 날짜") {
                    if let solar = computedSolarDate {
                        Text(solar, format: .dateTime.year().month().day())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("변환 불가").foregroundStyle(.secondary)
                    }
                }

                Section("배경색") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(DateMemoDTO.palette, id: \.self) { hex in
                            let color = Color(hex: hex) ?? .gray
                            Circle()
                                .fill(color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle().stroke(Color.primary, lineWidth: colorHex == hex ? 2 : 0)
                                )
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if existingId != nil {
                    Section {
                        Button("삭제", role: .destructive) { showDeleteAlert = true }
                    }
                }
            }
            .navigationTitle(existingId == nil ? "음력 기념일 추가" : "음력 기념일 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        let dto = LunarAnniversaryDTO(
                            id: existingId ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespaces),
                            lunarMonth: lunarMonth,
                            lunarDay: lunarDay,
                            isLeapMonth: isLeapMonth,
                            colorHex: colorHex,
                            createdAt: Date()
                        )
                        onSave(dto)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .alert("기념일을 삭제하시겠습니까?", isPresented: $showDeleteAlert) {
                Button("삭제", role: .destructive) {
                    if let id = existingId { onDelete?(id) }
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            }
            .onAppear {
                switch mode {
                case .new(let month, let day):
                    lunarMonth = month
                    lunarDay = day
                case .edit(let dto):
                    existingId = dto.id
                    title = dto.title
                    lunarMonth = dto.lunarMonth
                    lunarDay = dto.lunarDay
                    isLeapMonth = dto.isLeapMonth
                    colorHex = dto.colorHex
                }
            }
        }
    }
}
