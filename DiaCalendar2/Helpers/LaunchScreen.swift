//
//  LaunchScreen.swift
//  DiaCalendar2
//
//  Created by Bum Son on 5/13/26.
//

import SwiftUI

struct LaunchScreen<RootView: View, Logo: View>: Scene {
    @ViewBuilder var logo: Logo
    @ViewBuilder var rootcontent: RootView
    var body: some Scene {
        WindowGroup {
            rootcontent
        }
    }
}
