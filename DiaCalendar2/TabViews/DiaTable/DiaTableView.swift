//
//  DiaTableView.swift
//  DiaCalendar2
//
//  Created by Bum Son on 5/15/26.
//

import SwiftData
import SwiftUI

// MARK: - ViewModel

private let typeNameOrder: [String] = [
    "평일", "평평", "휴일", "평휴", "휴휴", "휴평", "토", "토휴", "평토", "휴토"
]

/// 교번순서 탭의 식별자 (DiaRecord typeName 과 충돌하지 않도록 별도 탭으로 취급).
let turnOrderTabName = "교번순서"

@Observable
@MainActor
final class DiaTableViewModel {
    var groupedRecords: [String: [DiaRecordDTO]] = [:]
    var typeNames: [String] = []
    /// 사용자가 근무설정에서 고른 position 의 dia_turns(교번) 값들. 순서대로 표시.
    var turnOrder: [String] = []
    var isLoading = false

    func load(
        diaRepo: DiaRecordRepository,
        configRepo: UserShiftConfigRepository,
        officeRepo: OfficeRecordRepository
    ) async {
        isLoading = true
        defer { isLoading = false }

        guard let config = await configRepo.load(), !config.officeName.isEmpty else { return }

        // 교번순서: position 에 따라 diaTurns1(기관사) / diaTurns2(차장) 등을 순서대로.
        if let office = await officeRepo.office(code: config.officeCode) {
            turnOrder = config.position.pattern(in: office)
        }

        let records = await diaRepo.dias(forOffice: config.officeName)

        var grouped: [String: [DiaRecordDTO]] = [:]
        for record in records {
            let key = record.typeName ?? "기타"
            grouped[key, default: []].append(record)
        }
        for key in grouped.keys {
            grouped[key]?.sort { lhs, rhs in
                lhs.diaId.localizedStandardCompare(rhs.diaId) == .orderedAscending
            }
        }

        let knownKeys = typeNameOrder.filter { grouped[$0] != nil }
        let otherKeys = grouped.keys
            .filter { !typeNameOrder.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        // 교번순서 탭을 맨 앞에 배치 (교번 데이터가 있을 때만).
        let leadingTabs = turnOrder.isEmpty ? [] : [turnOrderTabName]
        typeNames = leadingTabs + knownKeys + otherKeys
        groupedRecords = grouped
    }
}

// MARK: - Card

private struct DiaCardView: View {
    let record: DiaRecordDTO

    var body: some View {
        HStack(spacing: 5) {
            Text(record.diaId)
                .font(.system(.footnote, design: .monospaced).bold())
                .foregroundColor(Color.primary)
                .frame(width: 18, alignment: .center)

            Divider()
                .background(Color.red)
                .frame(height: 24)
            Text(record.workTime ?? "")
                .font(.system(.footnote, design: .monospaced).bold())
                .foregroundColor(Color.accentColor)
                .frame(width: 42, alignment: .center)

            //timeText(record.workTime, expandable: false)
            Divider()
                .background(Color.red)
                .frame(height: 24)
            timeText(record.firstTime, expandable: true)
            Divider()
                .background(Color.accentColor)
                .frame(height: 24)
            timeText(record.secondTime, expandable: true)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 5))
    }

    private func timeText(_ value: String?, expandable: Bool) -> some View {
        Text(value ?? "—")
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(value == nil ? .tertiary : .primary)
            .lineLimit(2)
            .fixedSize(horizontal: !expandable, vertical: true)
            .frame(maxWidth: expandable ? .infinity : nil, alignment: .leading)
    }
}

// MARK: - Main View

struct DiaTableView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var viewModel = DiaTableViewModel()
    @State private var selectedTab: String = ""
    @State private var selectedTurn: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.typeNames.isEmpty {
                    ContentUnavailableView(
                        "근무표",
                        systemImage: "tram",
                        description: Text("아직 표시할 정보가 없습니다.")
                    )
                } else {
                    typeTabContent
                }
            }
            .navigationTitle("근무표")
            .navigationBarTitleDisplayMode(.inline)
        }
        .paywallGate(.diaTableUsageLimited)
        .task {
            await viewModel.load(
                diaRepo: appEnvironment.diaRecordRepository,
                configRepo: appEnvironment.userShiftConfigRepository,
                officeRepo: appEnvironment.officeRecordRepository
            )
            if selectedTab.isEmpty, let first = viewModel.typeNames.first {
                selectedTab = first
            }
        }
    }

    @ViewBuilder
    private var typeTabContent: some View {
        VStack(spacing: 0) {
            if selectedTab == turnOrderTabName {
                turnOrderGrid
                Divider()
                turnPickerBar
            } else {
                recordList
            }
            Divider()
            tabBar
        }
    }

    /// 교번순서 탭 하단 드롭다운. 선택한 교번을 그리드에서 하이라이트.
    private var turnPickerBar: some View {
        HStack(spacing: 8) {
            Menu {
                // Menu 는 항목을 아래→위로 쌓으므로, 위에서부터 오름차순으로 보이도록 역순 전달.
                ForEach(sortedUniqueTurns.reversed(), id: \.self) { turn in
                    Button {
                        selectedTurn = turn
                    } label: {
                        if selectedTurn == turn {
                            Label(turn, systemImage: "checkmark")
                        } else {
                            Text(turn)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text(selectedTurn ?? "교번 선택")
                        .foregroundStyle(selectedTurn == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: Capsule())
            }
            .buttonStyle(.plain)

            if selectedTurn != nil {
                Button {
                    selectedTurn = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// 드롭다운 목록: 중복 제거 후 숫자(오름차순) → "대" 포함 → "휴" 포함 순.
    private var sortedUniqueTurns: [String] {
        let unique = Array(Set(viewModel.turnOrder))
        func rank(_ s: String) -> Int {
            if s.contains("휴") { return 2 }
            if s.contains("대") { return 1 }
            return 0
        }
        // 문자열에서 숫자만 추출 (없으면 nil) → 그룹 내 숫자 오름차순 정렬용.
        func number(_ s: String) -> Int? {
            Int(s.filter(\.isNumber))
        }
        return unique.sorted { lhs, rhs in
            let lr = rank(lhs), rr = rank(rhs)
            if lr != rr { return lr < rr }
            // 같은 그룹: 숫자 오름차순 (대2 < 대11), 숫자 없으면 자연 정렬 폴백.
            if let ln = number(lhs), let rn = number(rhs), ln != rn {
                return ln < rn
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    /// 교번순서 탭: dia_turns 값을 순서대로 가로 7칸씩 배열.
    private var turnOrderGrid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 6),
            count: 7
        )
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(viewModel.turnOrder.enumerated()), id: \.offset) { _, turn in
                    let isMatch = turnMatchesSearch(turn)
                    Text(turnDisplayText(turn))
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            isMatch ? Color.yellow.opacity(0.45) : turnBackground(turn),
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                        .overlay {
                            if isMatch {
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.orange, lineWidth: 2)
                            }
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    /// 드롭다운에서 선택된 교번과 일치하는지.
    private func turnMatchesSearch(_ turn: String) -> Bool {
        guard let selected = selectedTurn else { return false }
        return turn == selected
    }

    /// "~"가 포함된 교번은 "~" 한 글자로 표시.
    private func turnDisplayText(_ turn: String) -> String {
        turn.contains("~") ? "~" : turn
    }

    /// "휴" → 연한 빨강, "대" → 연한 초록 (다크모드 자동 대응 시맨틱 컬러).
    private func turnBackground(_ turn: String) -> Color {
        if turn.contains("휴") {
            return Color.red.opacity(0.18)
        } else if turn.contains("대") {
            return Color.green.opacity(0.18)
        }
        return Color(.secondarySystemBackground)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.typeNames, id: \.self) { name in
                    Button {
                        selectedTab = name
                    } label: {
                        Text(name)
                            .font(.subheadline.weight(selectedTab == name ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedTab == name
                                    ? Color.accentColor
                                    : Color(.systemFill),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedTab == name ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.18), value: selectedTab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var recordList: some View {
        let records = viewModel.groupedRecords[selectedTab] ?? []
        return ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(records, id: \.diaId) { record in
                    DiaCardView(record: record)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Preview

//#Preview {
//    let schema = Schema([
//        WorkShift.self, DateMemo.self, SyncState.self,
//        OfficeRecord.self, DiaRecord.self,
//        UserShiftConfig.self, ShiftSchedule.self,
//        ShiftSwapRecord.self, ShiftInputType.self, ShiftInputRecord.self,
//        CustomShift.self, HolidayRecord.self,
//        AttendanceType.self, AttendanceRecord.self,
//    ])
//    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: schema, configurations: [config])
//    let ctx = container.mainContext
//
//    ctx.insert(UserShiftConfig(
//        id: "singleton", officeCode: 1, officeName: "서울본부",
//        position: "기관사", shiftPatternCsv: "1,2,비,주휴",
//        startDate: .now, referenceDate: .now,
//        todayShift: "1", todayShiftIndex: 0, createdAt: .now
//    ))
//
//    let typeNames = ["기관사", "차장"]
//    for type_ in typeNames {
//        for i in 1...5 {
//            ctx.insert(DiaRecord(
//                officeName: "서울본부", officeCode: 1,
//                diaId: String(format: "%03d", i),
//                typeName: type_,
//                firstTime: "06:\(String(format: "%02d", i * 5))",
//                secondTime: "14:\(String(format: "%02d", i * 3))",
//                workTime: "08:00"
//            ))
//        }
//    }
//
//    return DiaTableView()
//        .environment(AppEnvironment(modelContainer: container))
//        .modelContainer(container)
//}
