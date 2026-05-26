//
//  ShiftRotationEngine.swift
//  DiaCalendar2
//

import Foundation

enum ShiftRotationError: Error, LocalizedError {
    case emptyPattern
    case referenceShiftNotFound

    var errorDescription: String? {
        switch self {
        case .emptyPattern: return "교번 패턴이 비어있습니다."
        case .referenceShiftNotFound: return "기준 근무를 패턴에서 찾을 수 없습니다."
        }
    }
}

/// Pure function that generates rotating shift assignments.
/// Mirrors `ShiftRepositoryImpl.generateAndSaveSchedules` in the Android project.
nonisolated enum ShiftRotationEngine {
    /// Korean-style calendar used for day arithmetic.
    nonisolated static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? TimeZone.current
        cal.firstWeekday = 1
        return cal
    }()

    /// Returns the start of day for `date` in the rotation calendar.
    nonisolated static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Compute the rotating schedule.
    ///
    /// - Parameters:
    ///   - pattern: e.g. ["1","2","비","주휴"]
    ///   - startDate: first date to emit (inclusive)
    ///   - referenceDate: date where `todayShift` (at `todayShiftIndex`) is anchored
    ///   - todayShift: shift name that occurs on `referenceDate`
    ///   - todayShiftIndex: optional explicit index into `pattern` for `todayShift`
    ///     (resolves ambiguity when the pattern contains duplicates).
    ///   - years: how many years from `startDate` to generate
    nonisolated static func rotate(
        pattern: [String],
        startDate: Date,
        referenceDate: Date,
        todayShift: String,
        todayShiftIndex: Int? = nil,
        years: Int = 3
    ) throws -> [ShiftScheduleDTO] {
        guard !pattern.isEmpty else { throw ShiftRotationError.emptyPattern }

        let refIndex: Int
        if let idx = todayShiftIndex, idx >= 0, idx < pattern.count {
            refIndex = idx
        } else if let found = pattern.firstIndex(of: todayShift) {
            refIndex = found
        } else {
            throw ShiftRotationError.referenceShiftNotFound
        }

        let cal = calendar
        let startDay = cal.startOfDay(for: startDate)
        let refDay = cal.startOfDay(for: referenceDate)
        let endDay = cal.date(byAdding: .year, value: years, to: startDay) ?? startDay
        let daysFromRefToStart = cal.dateComponents([.day], from: refDay, to: startDay).day ?? 0
        let totalDays = (cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1
        let size = pattern.count

        var out: [ShiftScheduleDTO] = []
        out.reserveCapacity(totalDays)
        for offset in 0..<totalDays {
            let totalOffset = daysFromRefToStart + offset
            // Mirror Kotlin's `((x % n) + n) % n` to keep mod non-negative.
            let raw = (refIndex + totalOffset) % size
            let idx = (raw + size) % size
            let date = cal.date(byAdding: .day, value: offset, to: startDay) ?? startDay
            out.append(ShiftScheduleDTO(date: date, shiftName: pattern[idx]))
        }
        return out
    }

    /// Helper: chunk an array for batched DB inserts.
    nonisolated static func chunk<T>(_ items: [T], size: Int) -> [[T]] {
        guard size > 0, !items.isEmpty else { return items.isEmpty ? [] : [items] }
        var result: [[T]] = []
        var i = 0
        while i < items.count {
            let end = min(i + size, items.count)
            result.append(Array(items[i..<end]))
            i = end
        }
        return result
    }
}
