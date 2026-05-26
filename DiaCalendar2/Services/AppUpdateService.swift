//
//  AppUpdateService.swift
//  DiaCalendar2
//

import Foundation
import OSLog

@Observable
@MainActor
final class AppUpdateService {
    private(set) var isUpdateRequired: Bool = false
    private(set) var storeURL: String = ""

    private let log = Logger(subsystem: "DiaCalendar2", category: "AppUpdateService")

    /// 앱 포그라운드 진입마다 호출. 네트워크 오류 시 차단하지 않는다 (fail open).
    func checkForUpdate() async {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        do {
            let dto = try await SupabaseAPI.fetchAppVersion()
            let needsUpdate = isVersion(current, lessThan: dto.minVersion)
            log.info("[AppUpdate] current=\(current, privacy: .public) min=\(dto.minVersion, privacy: .public) → needsUpdate=\(needsUpdate, privacy: .public)")
            isUpdateRequired = needsUpdate
            storeURL = dto.storeURL
        } catch {
            log.error("[AppUpdate] version check failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func isVersion(_ lhs: String, lessThan rhs: String) -> Bool {
        let l = lhs.split(separator: ".").compactMap { Int($0) }
        let r = rhs.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(l.count, r.count) {
            let lv = i < l.count ? l[i] : 0
            let rv = i < r.count ? r[i] : 0
            if lv < rv { return true }
            if lv > rv { return false }
        }
        return false
    }
}
