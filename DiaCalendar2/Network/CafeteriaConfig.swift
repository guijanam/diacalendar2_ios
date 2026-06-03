//
//  CafeteriaConfig.swift
//  DiaCalendar2
//
//  구내식당 메뉴는 근무/공휴일용 메인 Supabase와는 별개의 인스턴스에서 가져온다.
//  (참고: 구버전 /Users/heebum/Documents/AppStore Project/DiaCalendar/DiaCalendar/ApiService.swift)
//

import Foundation

enum CafeteriaConfig {
    static let url = "https://drbaihybmbhshhvjoovq.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRyYmFpaHlibWJoc2hodmpvb3ZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTgzMTQsImV4cCI6MjA4ODU3NDMxNH0.NvPbKCTnDh6qZxSzeFLFYC85hu2lYD4q4t8ZvmoRjMc"
    static let restURL = "\(url)/rest/v1"

    /// 메뉴 업로드(분석) 웹 페이지. CafeteriaMenuSheet 상단의 업로드 버튼이 여는 주소.
    static let uploadURL = URL(string: "https://cafeteria-nine-psi.vercel.app/analyze")!
}
