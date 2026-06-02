//
//  DiaCalendar2WatchApp.swift
//  DiaCalendar2Watch Watch App
//
//  Created by Bum Son on 5/31/26.
//

import SwiftUI

@main
struct DiaCalendar2Watch_Watch_AppApp: App {
    init() {
        WatchConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
