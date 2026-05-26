import Foundation

/// 승무소별 웹사이트 인증 상태를 UserDefaults에 저장합니다.
/// 한 번 인증하면 앱을 재시작해도 다시 묻지 않습니다.
enum WebPasswordStore {
    private static let keyPrefix = "web_authed_"

    static func isAuthenticated(for officeName: String) -> Bool {
        UserDefaults.standard.bool(forKey: keyPrefix + officeName)
    }

    static func markAuthenticated(for officeName: String) {
        UserDefaults.standard.set(true, forKey: keyPrefix + officeName)
    }

    /// 특정 승무소의 인증을 초기화합니다 (비밀번호 변경 시 사용).
    static func reset(for officeName: String) {
        UserDefaults.standard.removeObject(forKey: keyPrefix + officeName)
    }
}
