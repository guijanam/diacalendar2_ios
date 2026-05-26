//
//  MyInfomationView.swift
//  DiaCalendar2
//

import SwiftUI

private enum InfoTab: String, CaseIterable {
    case memo = "메모내역"
    case attendance = "근태내역"
    case shiftInput = "휴무충당내역"
}

struct MyInfomationView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab: InfoTab = .memo
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var memos: [DateMemoDTO] = []
    @State private var attendanceRecords: [AttendanceRecordDTO] = []
    @State private var shiftInputRecords: [ShiftInputRecordDTO] = []
    @State private var attendanceTypes: [AttendanceTypeDTO] = []
    /// 휴무충당 유형의 id 집합. 휴무충당내역 화면은 이 유형만 표시한다.
    @State private var hyumuChungdangTypeIds: Set<UUID> = []
    @State private var memoSearchQuery: String = ""
    @State private var isSearchPresented: Bool = false

    private let calendar = ShiftRotationEngine.calendar

    /// 휴무충당내역 화면 대상 = 휴무충당 유형의 충당 레코드만.
    private var hyumuChungdangRecords: [ShiftInputRecordDTO] {
        shiftInputRecords.filter { hyumuChungdangTypeIds.contains($0.shiftInputTypeId) }
    }

    private var availableYears: [Int] {
        let memoYears = memos.map { calendar.component(.year, from: $0.startDate) }
        let attendanceYears = normalAttendanceRecords.map { calendar.component(.year, from: $0.date) }
        let shiftInputYears = hyumuChungdangRecords.map { calendar.component(.year, from: $0.date) }
        let all = Set(memoYears + attendanceYears + shiftInputYears)
        return all.isEmpty ? [selectedYear] : all.sorted(by: >)
    }

    private var filteredMemos: [DateMemoDTO] {
        let byYear = memos.filter { calendar.component(.year, from: $0.startDate) == selectedYear }
        guard !memoSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return byYear }
        let q = memoSearchQuery.lowercased()
        return byYear.filter { $0.title.lowercased().contains(q) || $0.body.lowercased().contains(q) }
    }

    /// 근태내역 대상 = 일반 근태(휴가)만. 지근/지휴는 제외.
    private var normalAttendanceRecords: [AttendanceRecordDTO] {
        attendanceRecords.filter { $0.category == .normal }
    }

    private var filteredAttendanceRecords: [AttendanceRecordDTO] {
        normalAttendanceRecords.filter { calendar.component(.year, from: $0.date) == selectedYear }
    }

    private var filteredShiftInputRecords: [ShiftInputRecordDTO] {
        hyumuChungdangRecords.filter { calendar.component(.year, from: $0.date) == selectedYear }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("탭", selection: $selectedTab) {
                    ForEach(InfoTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGroupedBackground))

                Divider()

                Group {
                    switch selectedTab {
                    case .memo:
                        memoListView
                            .searchable(
                                text: $memoSearchQuery,
                                isPresented: $isSearchPresented,
                                placement: .navigationBarDrawer(displayMode: .always),
                                prompt: "제목, 내용 검색"
                            )
                    case .attendance: attendanceListView
                    case .shiftInput: shiftInputListView
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("내정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(availableYears, id: \.self) { year in
                            Button {
                                selectedYear = year
                            } label: {
                                if year == selectedYear {
                                    Label(String(format: "%d년", year), systemImage: "checkmark")
                                } else {
                                    Text(String(format: "%d년", year))
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(String(format: "%d년", selectedYear))
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                    }
                }
            }
            .task { await loadAll() }
            .onChange(of: memos) { _, _ in ensureSelectedYearValid() }
            .onChange(of: attendanceRecords) { _, _ in ensureSelectedYearValid() }
            .onChange(of: shiftInputRecords) { _, _ in ensureSelectedYearValid() }
            .onChange(of: selectedTab) { _, _ in
                memoSearchQuery = ""
                isSearchPresented = false
            }
        }
    }

    // MARK: - 메모내역

    private var memoListView: some View {
        let grouped = Dictionary(grouping: filteredMemos) { memo in
            calendar.startOfDay(for: memo.startDate)
        }
        let sortedDays = grouped.keys.sorted(by: >)

        return Group {
            if filteredMemos.isEmpty {
                if memoSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    emptyView("메모 없음", "작성된 메모가 없습니다.")
                } else {
                    emptyView("검색 결과 없음", "'\(memoSearchQuery)'와 일치하는 메모가 없습니다.")
                }
            } else {
                List {
                    ForEach(sortedDays, id: \.self) { day in
                        Section(header: Text(dateHeader(day))) {
                            ForEach(
                                (grouped[day] ?? []).sorted { $0.updatedAt > $1.updatedAt },
                                id: \.id
                            ) { memo in
                                memoRow(memo)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func memoRow(_ memo: DateMemoDTO) -> some View {
        let baseColor = Color(hex: memo.colorHex) ?? .accentColor
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(baseColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(memo.title.isEmpty ? "메모" : memo.title)
                    .strikethrough(memo.isDone)
                    .font(.headline)
                    .foregroundStyle(.primary.opacity(memo.isDone ? 0.4 : 1.0))
                    .lineLimit(2)

                if !memo.body.isEmpty {
                    Text(memo.body)
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(memo.isDone ? 0.4 : 1.0))
                        .lineLimit(2)
                }

                if !calendar.isDate(memo.startDate, inSameDayAs: memo.endDate) {
                    Text(memoDateRange(memo))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if memo.isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
        .padding(12)
        .background(baseColor.opacity(cardAlpha))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 근태내역

    private var attendanceListView: some View {
        let grouped = Dictionary(grouping: filteredAttendanceRecords, by: \.name)
        let sortedNames = grouped.keys.sorted { a, b in
            let latestA = grouped[a]!.map(\.date).max() ?? .distantPast
            let latestB = grouped[b]!.map(\.date).max() ?? .distantPast
            return latestA > latestB
        }

        return Group {
            if filteredAttendanceRecords.isEmpty {
                emptyView("근태 없음", "등록된 근태 내역이 없습니다.")
            } else {
                List {
                    ForEach(sortedNames, id: \.self) { name in
                        Section(header: attendanceHeader(name: name, used: (grouped[name] ?? []).count)) {
                            ForEach(
                                (grouped[name] ?? []).sorted { $0.date > $1.date },
                                id: \.id
                            ) { record in
                                attendanceRow(record)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func attendanceHeader(name: String, used: Int) -> some View {
        let type = attendanceTypes.first(where: { $0.name == name })
        let limit = type.flatMap { $0.limitCount.flatMap { $0 > 0 ? $0 : nil } }
        let isExhausted = limit.map { used >= $0 } ?? false
        let label = limit.map { "\(name) (\(used)/\($0))" } ?? "\(name) (\(used))"

        Text(label)
            .strikethrough(isExhausted)
            .foregroundStyle(isExhausted ? .secondary : .primary)
    }

    @ViewBuilder
    private func attendanceRow(_ record: AttendanceRecordDTO) -> some View {
        HStack(spacing: 12) {
            if !record.originalShiftName.isEmpty {
                Text(record.originalShiftName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }

            Text(record.shortName)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(fullDateString(record.date))
                    .font(.subheadline)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 휴무충당내역

    private var shiftInputListView: some View {
        let sorted = filteredShiftInputRecords.sorted { $0.date > $1.date }

        return Group {
            if sorted.isEmpty {
                emptyView("충당 없음", "등록된 휴무충당 내역이 없습니다.")
            } else {
                List {
                    Section(header: Text("총 \(sorted.count)건")) {
                        ForEach(sorted, id: \.id) { record in
                            shiftInputRow(record)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func shiftInputRow(_ record: ShiftInputRecordDTO) -> some View {
        let badgeColor = Color(hex: record.colorHex) ?? .accentColor
        HStack(spacing: 12) {
            Text(record.targetShiftName)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(badgeColor)
                .clipShape(Capsule())
            
            Text(fullDateString(record.date))
                .font(.subheadline)
        }
        .padding(12)
        //.background(badgeColor.opacity(cardAlpha))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 공통

    private func emptyView(_ title: String, _ description: String) -> some View {
        ContentUnavailableView(title, systemImage: "tray", description: Text(description))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardAlpha: Double {
        ContrastPalette.cardBackgroundAlpha(for: colorScheme)
    }

    private func dateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func fullDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func memoDateRange(_ memo: DateMemoDTO) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M월 d일"
        return "\(formatter.string(from: memo.startDate)) – \(formatter.string(from: memo.endDate))"
    }

    // MARK: - 데이터 로드

    private func ensureSelectedYearValid() {
        if !availableYears.contains(selectedYear), let first = availableYears.first {
            selectedYear = first
        }
    }

    private func loadAll() async {
        let full = DateInterval(start: .distantPast, end: .distantFuture)
        async let m = appEnvironment.dateMemoRepository.memos(in: full)
        async let a = appEnvironment.attendanceRecordRepository.records(in: full)
        async let s = appEnvironment.shiftInputRecordRepository.records(in: full)
        async let t = appEnvironment.shiftInputTypeRepository.all()
        async let at = appEnvironment.attendanceTypeRepository.all()
        memos = await m
        attendanceRecords = await a
        shiftInputRecords = await s
        hyumuChungdangTypeIds = Set(
            await t
                .filter { $0.name == FullCalendarViewModelModel.hyumuChungdangTypeName }
                .map { $0.id }
        )
        attendanceTypes = await at
    }
}

#Preview {
    MyInfomationView()
}
