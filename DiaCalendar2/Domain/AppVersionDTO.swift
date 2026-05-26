//
//  AppVersionDTO.swift
//  DiaCalendar2
//

import Foundation

struct AppVersionDTO: Decodable, Sendable {
    let minVersion: String
    let latestVersion: String
    let storeURL: String

    private enum CodingKeys: String, CodingKey {
        case minVersion    = "min_version"
        case latestVersion = "latest_version"
        case storeURL      = "store_url"
    }
}
