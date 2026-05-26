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

@Observable
@MainActor
final class DiaTableViewModel {
    var groupedRecords: [String: [DiaRecordDTO]] = [:]
    var typeNames: [String] = []
    var isLoading = false

    func load(diaRepo: DiaRecordRepository, configRepo: UserShiftConfigRepository) async {
        isLoading = true
        defer { isLoading = false }

        guard let config = await configRepo.load(), !config.officeName.isEmpty else { return }

        let records = await diaRepo.dias(forOffice: config.officeName)
        guard !records.isEmpty else { return }

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
        typeNames = knownKeys + otherKeys
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
                configRepo: appEnvironment.userShiftConfigRepository
            )
            if selectedTab.isEmpty, let first = viewModel.typeNames.first {
                selectedTab = first
            }
        }
    }

    @ViewBuilder
    private var typeTabContent: some View {
        VStack(spacing: 0) {
            recordList
            Divider()
            tabBar
        }
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
