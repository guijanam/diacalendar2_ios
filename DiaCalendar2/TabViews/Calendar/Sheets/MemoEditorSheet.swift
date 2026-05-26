//
//  MemoEditorSheet.swift
//  DiaCalendar2
//

import SwiftUI

struct MemoEditorSheet: View {

    // 1. 포커스 상태를 구분하기 위한 열거형 추가
    enum FocusField {
        case title
        case bodyText
    }

    private enum RecurrenceEndKind: String, CaseIterable, Identifiable {
        case never
        case onDate
        case afterCount

        var id: String { rawValue }
        var title: String {
            switch self {
            case .never: return "계속"
            case .onDate: return "특정 날짜"
            case .afterCount: return "횟수"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: MemoEditorMode
    let calendar: Calendar
    let onSave: (DateMemoDTO) -> Void
    let onDelete: ((UUID) -> Void)?

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var colorHex: String = DateMemoDTO.defaultColorHex
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var existingId: UUID?
    @State private var isDone: Bool = false

    @State private var showDeleteAlert: Bool = false
    @State private var recurrenceEnabled: Bool = false
    @State private var recurrenceFrequency: EventRecurrenceFrequency = .weekly
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceEndKind: RecurrenceEndKind = .never
    @State private var recurrenceEndDate: Date = Date()
    @State private var recurrenceOccurrenceCount: Int = 10

    // 2. FocusState 변수 추가
    @FocusState private var focusedField: FocusField?

    init(
        mode: MemoEditorMode,
        calendar: Calendar,
        onSave: @escaping (DateMemoDTO) -> Void,
        onDelete: ((UUID) -> Void)? = nil
    ) {
        self.mode = mode
        self.calendar = calendar
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    // 1. 저장 버튼 활성화 조건 (상/하단 버튼 모두 이 조건을 사용합니다)
    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("제목") {
                    TextField("제목", text: $title)
                        // 3. TextField에 포커스 상태 연결
                        .focused($focusedField, equals: .title)
                }

                Section("내용") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $bodyText)
                            .frame(minHeight: 140)
                        if bodyText.isEmpty {
                            Text("내용을 입력하세요")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                }

                Section("기간") {
                    DatePicker("시작", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { oldValue, newValue in
                            if endDate < newValue {
                                endDate = newValue
                            }
                        }
                    if !recurrenceEnabled {
                        DatePicker("종료", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                Section("반복") {
                    Toggle("반복", isOn: $recurrenceEnabled)
                    if recurrenceEnabled {
                        Picker("주기", selection: $recurrenceFrequency) {
                            ForEach(EventRecurrenceFrequency.allCases, id: \.self) { freq in
                                Text(freq.title).tag(freq)
                            }
                        }
                        Stepper("간격: \(recurrenceInterval)", value: $recurrenceInterval, in: 1...99)
                        Picker("종료", selection: $recurrenceEndKind) {
                            ForEach(RecurrenceEndKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        if recurrenceEndKind == .onDate {
                            DatePicker(
                                "종료일",
                                selection: $recurrenceEndDate,
                                in: startDate...,
                                displayedComponents: [.date]
                            )
                        } else if recurrenceEndKind == .afterCount {
                            Stepper("\(recurrenceOccurrenceCount)회", value: $recurrenceOccurrenceCount, in: 1...365)
                        }
                    }
                }

                Section {
                    Toggle("완료", isOn: $isDone)
                }

                Section("배경색") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(DateMemoDTO.palette, id: \.self) { hex in
                            colorSwatch(hex: hex)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if existingId != nil, onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("메모 삭제")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .environment(\.calendar, calendar)
            .alert("메모를 삭제하시겠습니까?", isPresented: $showDeleteAlert) {
                Button("삭제", role: .destructive) {
                    if let id = existingId {
                        onDelete?(id)
                        dismiss()
                    }
                }
                Button("취소", role: .cancel) {}
            }
            .navigationTitle(existingId == nil ? "새 메모" : "메모 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveMemo() // 분리해둔 저장 로직 호출
                    }
                    .disabled(isSaveDisabled) // 비활성화 조건 동일하게 적용
                }
            }
            // 3. 화면 하단 저장 버튼 유지
            .safeAreaInset(edge: .bottom) {
                bottomSaveButton
            }
            .onAppear {
                applyMode()
                // 4. 시트가 나타날 때 약간의 지연 후 포커스 주기
                // 시트가 올라오는 애니메이션 중에 키보드가 같이 올라오면 버벅일 수 있으므로 0.1~0.5초 정도 여유를 줍니다.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedField = .title
                }
            }
        }
    }
    
    // MARK: - Subviews & Methods

    private var bottomSaveButton: some View {
        VStack {
            Button {
                saveMemo()
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
    
    private func saveMemo() {
        let dto = DateMemoDTO(
            id: existingId ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: bodyText,
            colorHex: colorHex,
            startDate: calendar.startOfDay(for: startDate),
            endDate: recurrenceEnabled ? calendar.startOfDay(for: startDate) : calendar.startOfDay(for: endDate),
            updatedAt: Date(),
            isDone: isDone,
            recurrence: recurrenceEnabled ? buildRecurrence() : nil
        )
        onSave(dto)
        dismiss()
    }

    private func buildRecurrence() -> EventRecurrence {
        let end: EventRecurrenceEnd
        switch recurrenceEndKind {
        case .never: end = .never
        case .onDate: end = .onDate(recurrenceEndDate)
        case .afterCount: end = .afterCount(recurrenceOccurrenceCount)
        }
        return EventRecurrence(
            frequency: recurrenceFrequency,
            interval: recurrenceInterval,
            end: end
        )
    }

    @ViewBuilder
    private func colorSwatch(hex: String) -> some View {
        let isSelected = colorHex == hex
        let color = Color(hex: hex) ?? .gray
        Button {
            colorHex = hex
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(height: 36)
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary, lineWidth: 2)
                        .frame(height: 36)
                    Image(systemName: "checkmark")
                        .foregroundStyle(.primary)
                        .font(.system(size: 14, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func applyMode() {
        switch mode {
        case .new(let date):
            let day = calendar.startOfDay(for: date)
            startDate = day
            endDate = day
            recurrenceEndDate = calendar.date(byAdding: .month, value: 1, to: day) ?? day
            colorHex = DateMemoDTO.defaultColorHex
            existingId = nil
        case .edit(let dto):
            title = dto.title
            bodyText = dto.body
            colorHex = dto.colorHex
            startDate = dto.startDate
            endDate = dto.endDate
            existingId = dto.id
            isDone = dto.isDone

            if let recurrence = dto.recurrence {
                recurrenceEnabled = true
                recurrenceFrequency = recurrence.frequency
                recurrenceInterval = recurrence.interval
                switch recurrence.end {
                case .never:
                    recurrenceEndKind = .never
                    recurrenceEndDate = calendar.date(byAdding: .month, value: 1, to: dto.startDate) ?? dto.startDate
                case .onDate(let date):
                    recurrenceEndKind = .onDate
                    recurrenceEndDate = date
                case .afterCount(let count):
                    recurrenceEndKind = .afterCount
                    recurrenceOccurrenceCount = count
                    recurrenceEndDate = calendar.date(byAdding: .month, value: 1, to: dto.startDate) ?? dto.startDate
                }
            }
        }
    }
}
