//
//  SharedSubscriptionState.swift
//  DiaCalendar2Widget
//
//  앱↔위젯 익스텐션이 구독 상태를 공유하기 위한 App Group UserDefaults 래퍼.
//  메인 앱이 구독/VIP 상태를 write하고, 위젯은 read만 한다.
//
//  ⚠️ 이 파일은 메인 앱 타깃의 DiaCalendar2/RevenueCat/SharedSubscriptionState.swift 와
//     내용이 동일하게 유지되어야 한다. (FileSystem Synchronized Group 특성상 폴더 경계를
//     넘어 한 파일을 두 타깃이 공유하기 어려워 위젯 폴더에 사본을 둔다.)
//

import Foundation

enum SharedSubscriptionState {

    /// App Group 식별자. 메인 앱과 위젯 익스텐션 양쪽 entitlements에 동일하게 추가되어야 한다.
    static let appGroupID = "group.com.developergui7.DiaCalendar2"

    private static let widgetUnlockedKey = "widget_unlocked"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// 위젯이 데이터를 표시할 수 있는지 여부(구독 OR VIP면 true).
    /// App Group 미설정/값 없음일 때는 안전하게 `false`(잠금)를 반환한다.
    static var widgetUnlocked: Bool {
        get { defaults?.bool(forKey: widgetUnlockedKey) ?? false }
        set { defaults?.set(newValue, forKey: widgetUnlockedKey) }
    }
}
