//
//  HolidaySyncService.swift
//  DiaCalendar2
//

import Foundation
import OSLog

enum HolidayRefreshResult: Sendable {
    case success(count: Int)
    case failure(message: String)
}

actor HolidaySyncService {
    private let repo: HolidayRepository
    private let syncStateRepo: SyncStateRepository
    private let log = Logger(subsystem: "DiaCalendar2", category: "HolidaySync")

    init(repo: HolidayRepository, syncStateRepo: SyncStateRepository) {
        self.repo = repo
        self.syncStateRepo = syncStateRepo
    }

    /// 사용자가 Settings에서 "공휴일 정보 갱신" 버튼을 눌렀을 때만 호출.
    /// fetch → 파싱 → SwiftData replaceAll → `.holidaysDidUpdate` 통지.
    @discardableResult
    func refresh() async -> HolidayRefreshResult {
        log.info("[Holiday] refresh 시작")
        do {
            let remote = try await SupabaseAPI.listHolidays()
            log.info("[Holiday] Supabase \(remote.count, privacy: .public) row 수신")

            var dtos: [HolidayRecordDTO] = []
            var rawByDate: [Date: String] = [:]
            var skipped = 0
            for r in remote {
                guard let day = Self.parseKSTMidnight(r.locdate) else {
                    skipped += 1
                    log.warning("[Holiday] 파싱 실패: locdate=\(r.locdate, privacy: .public) name=\(r.datename, privacy: .public)")
                    continue
                }
                dtos.append(HolidayRecordDTO(date: day, name: r.datename))
                rawByDate[day] = r.locdate
            }
            log.info("[Holiday] 파싱 성공 \(dtos.count, privacy: .public)개, 건너뜀 \(skipped, privacy: .public)개")

            await repo.replaceAll(with: dtos, locdateRaws: rawByDate)
            let savedCount = await repo.count()
            log.info("[Holiday] SwiftData 저장 완료 (count=\(savedCount, privacy: .public))")

            await syncStateRepo.setLastHolidaySyncAt(Date())
            await MainActor.run {
                NotificationCenter.default.post(name: .holidaysDidUpdate, object: nil)
            }
            return .success(count: savedCount)
        } catch {
            log.error("[Holiday] 실패: \(error.localizedDescription, privacy: .public)")
            return .failure(message: error.localizedDescription)
        }
    }

    func lastSyncAt() async -> Date? {
        await syncStateRepo.lastHolidaySyncAt()
    }

    /// "yyyy-MM-dd" 또는 "yyyyMMdd" 형식을 KST 자정 Date로 변환.
    static func parseKSTMidnight(_ raw: String) -> Date? {
        let cleaned = raw.replacingOccurrences(of: "-", with: "")
        guard cleaned.count == 8, let intVal = Int(cleaned) else { return nil }
        let year = intVal / 10000
        let month = (intVal % 10000) / 100
        let day = intVal % 100
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return ShiftRotationEngine.calendar.date(from: components)
    }
}
