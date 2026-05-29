import Foundation

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

/// 승무소 이름과 웹사이트 URL / 비밀번호 매핑 테이블.
/// 새 승무소를 추가하거나 URL·비밀번호를 변경할 때 이 파일만 수정하면 됩니다.
enum OfficeWebURLMap {

    struct Entry {
        let url: String
        /// nil이면 비밀번호 없이 바로 열립니다.
        let password: String?
    }

    // MARK: - 매핑 테이블 (승무소명: Entry)

    private static let table: [String: Entry] = [
        "동대문승무소": Entry(url: "https://dia-supervisor.vercel.app", password: "8707"),
        "대공원승무소": Entry(url: "http://seoulmetroline7.co.kr/login.php",      password: "5678"),
        "영등포승무소": Entry(url: "https://work.line5.kr/calendar.php",           password: "5678"),
    ]

    // MARK: - 외부 Safari 전용 매핑
    /// DayDetailSheet의 "승무소웹" 버튼에서 외부 Safari로 열 URL.
    /// 위 `table`과 용도가 달라 별도 관리한다. 항목이 없으면 버튼은 표시되지 않는다.
    private static let externalTable: [String: String] = [
        "동대문승무소": "https://dongseoung-day-cowoker.vercel.app",
        // "대공원승무소": "https://...",
        // "영등포승무소": "https://...",
    ]

    /// 승무소웹 시트 하단의 "보조" 버튼이 가리킬 URL.
    /// externalTable과 함께 같은 WebView에서 토글된다.
    private static let secondaryExternalTable: [String: String] = [
        "동대문승무소": "https://dongseoung-month-cowoker.vercel.app",
        // "대공원승무소": "https://...",
        // "영등포승무소": "https://...",
    ]

    // MARK: - API

    static func entry(for officeName: String) -> Entry? {
        table[officeName]
    }

    static func url(for officeName: String) -> URL? {
        guard let urlString = table[officeName]?.url else { return nil }
        return URL(string: urlString)
    }

    static func externalURL(for officeName: String) -> URL? {
        guard let urlString = externalTable[officeName] else { return nil }
        return URL(string: urlString)
    }

    static func secondaryExternalURL(for officeName: String) -> URL? {
        guard let urlString = secondaryExternalTable[officeName] else { return nil }
        return URL(string: urlString)
    }
}
