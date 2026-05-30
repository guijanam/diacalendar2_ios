//
//  CoworkerViewModel.swift
//  DiaCalendar2
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class CoworkerViewModel {
    enum Tab { case calendar, list }

    var coworkers: [CoworkerDTO] = []
    var groups: [CoworkerGroupDTO] = []
    /// nil = 전체
    var selectedGroupId: UUID?
    var selectedTab: Tab = .calendar

    var currentYear: Int = Calendar.current.component(.year, from: Date())
    var currentMonth: Int = Calendar.current.component(.month, from: Date())

    /// 내 유효 근무 (날짜 → 근무명). startOfDay 키.
    var myScheduleMap: [Date: String] = [:]
    /// coworkerId → (날짜 → 근무명)
    var coworkerSchedules: [UUID: [Date: String]] = [:]
    /// 공휴일 날짜 집합 (startOfDay 키)
    var holidayDates: Set<Date> = []

    var isLoading = true

    private let appEnvironment: AppEnvironment
    private let cal = ShiftRotationEngine.calendar

    init(appEnvironment: AppEnvironment) {
        self.appEnvironment = appEnvironment
    }

    var filteredCoworkers: [CoworkerDTO] {
        guard let selectedGroupId else { return coworkers }
        return coworkers.filter { $0.groupIds.contains(selectedGroupId) }
    }

    private var repo: CoworkerRepository { appEnvironment.coworkerRepository }

    // MARK: - Loading

    func reloadAll() async {
        async let c = repo.allCoworkers()
        async let g = repo.allGroups()
        coworkers = await c
        groups = await g
        // 선택된 그룹이 사라졌으면 전체로
        if let id = selectedGroupId, !groups.contains(where: { $0.id == id }) {
            selectedGroupId = nil
        }
        await reloadMonth()
        isLoading = false
    }

    func onMonthChanged(year: Int, month: Int) async {
        currentYear = year
        currentMonth = month
        await reloadMonth()
    }

    func goToPreviousMonth() async {
        var (y, m) = (currentYear, currentMonth)
        m -= 1
        if m < 1 { m = 12; y -= 1 }
        await onMonthChanged(year: y, month: m)
    }

    func goToNextMonth() async {
        var (y, m) = (currentYear, currentMonth)
        m += 1
        if m > 12 { m = 1; y += 1 }
        await onMonthChanged(year: y, month: m)
    }

    /// 해당 월의 내 유효근무 + 동료 스케줄 + 공휴일을 재계산.
    func reloadMonth() async {
        guard let monthInterval = monthInterval(year: currentYear, month: currentMonth) else { return }

        // 내 유효 근무 (base + swap/input/attendance 우선순위 적용)
        async let baseTask = appEnvironment.shiftScheduleRepository.schedules(in: monthInterval)
        async let swapTask = appEnvironment.shiftSwapRecordRepository.swaps(in: monthInterval)
        async let inputTask = appEnvironment.shiftInputRecordRepository.records(in: monthInterval)
        async let attendanceTask = appEnvironment.attendanceRecordRepository.records(in: monthInterval)
        async let holidayTask = appEnvironment.holidayRepository.map()

        let base = await baseTask
        let swaps = await swapTask
        let inputs = await inputTask
        let attendances = await attendanceTask
        let holidayMap = await holidayTask

        myScheduleMap = buildEffectiveMyMap(
            base: base, swaps: swaps, inputs: inputs, attendances: attendances
        )
        holidayDates = Set(holidayMap.keys.map { cal.startOfDay(for: $0) })

        // 동료 스케줄 (런타임 계산)
        var schedules: [UUID: [Date: String]] = [:]
        for coworker in filteredCoworkers {
            schedules[coworker.id] = CoworkerRepository.scheduleForMonth(
                coworker, year: currentYear, month: currentMonth
            )
        }
        coworkerSchedules = schedules
    }

    func onGroupSelected(_ groupId: UUID?) async {
        selectedGroupId = groupId
        await reloadMonth()
    }

    // MARK: - Reorder

    func moveCoworkers(from source: IndexSet, to destination: Int) async {
        var list = filteredCoworkers
        list.move(fromOffsets: source, toOffset: destination)
        // 필터된 항목의 새 순서를 전체 정렬에 반영.
        let filteredIds = list.map { $0.id }
        let others = coworkers.filter { !filteredIds.contains($0.id) }
        let orderedIds = filteredIds + others.map { $0.id }
        await repo.updateCoworkerSortOrders(orderedIds: orderedIds)
        coworkers = await repo.allCoworkers()
        await reloadMonth()
    }

    // MARK: - Helpers

    private func monthInterval(year: Int, month: Int) -> DateInterval? {
        guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
        let start = cal.startOfDay(for: first)
        guard let end = cal.date(byAdding: DateComponents(month: 1), to: start) else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// CalendarAggregator와 동일 우선순위: Attendance → ShiftInput → ShiftSwap → base.
    /// 단, 지근 위에 충당이 있으면 충당 우선(지근충당).
    private func buildEffectiveMyMap(
        base: [ShiftScheduleDTO],
        swaps: [ShiftSwapRecordDTO],
        inputs: [ShiftInputRecordDTO],
        attendances: [AttendanceRecordDTO]
    ) -> [Date: String] {
        func key(_ d: Date) -> Date { cal.startOfDay(for: d) }

        let swapByDay = Dictionary(swaps.map { (key($0.date), $0.swappedShiftName) }, uniquingKeysWith: { _, b in b })
        let inputByDay = Dictionary(inputs.map { (key($0.date), $0.targetShiftName) }, uniquingKeysWith: { _, b in b })
        let attendanceByDay = Dictionary(attendances.map { (key($0.date), $0) }, uniquingKeysWith: { _, b in b })

        var result: [Date: String] = [:]
        var days = Set<Date>()
        base.forEach { days.insert(key($0.date)) }
        attendanceByDay.keys.forEach { days.insert($0) }

        let baseByDay = Dictionary(base.map { (key($0.date), $0.shiftName) }, uniquingKeysWith: { _, b in b })

        for day in days {
            let attendance = attendanceByDay[day]
            let input = inputByDay[day]
            let inputOverridesAttendance = attendance?.category == .jigeun && input != nil

            if let attendance, !inputOverridesAttendance {
                result[day] = attendance.shortName
            } else if let input {
                result[day] = input
            } else if let swap = swapByDay[day] {
                result[day] = swap
            } else if let baseName = baseByDay[day] {
                result[day] = baseName
            }
        }
        return result
    }
}
