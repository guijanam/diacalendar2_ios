//
//  SubwayLine.swift
//  DiaCalendar2
//
//  열번(numTr) 문자열 파싱과 서울 지하철 실시간 위치 코드 매핑 헬퍼.
//  뷰 의존성 없는 순수 함수만 둔다.
//

import Foundation

enum SubwayLine {

    /// numTr 문자열을 열번 토큰 배열로 분해한다.
    /// 괄호 묶음(`(39)` 등)은 제거하고 공백으로 분리한다.
    /// 예) "(39)2030 2080 2134(23)" -> ["2030", "2080", "2134"]
    ///     "2205 2239 2273"          -> ["2205", "2239", "2273"]
    static func tokens(from raw: String) -> [String] {
        let withoutParens = raw.replacingOccurrences(
            of: "\\([^)]*\\)",
            with: " ",
            options: .regularExpression
        )
        return withoutParens
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// 내가 교대할 열번 = 항상 첫 토큰.
    static func myTrainNo(from raw: String) -> String? {
        tokens(from: raw).first
    }

    /// 열번 문자열에서 호선 번호를 추출. 첫 글자가 숫자(1~9)이고
    /// 전체가 정수로 파싱 가능할 때만 유효.
    /// 예) "2300" -> 2, "K2317" -> nil, "" -> nil
    static func line(fromTrainNo raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, first.isNumber else { return nil }
        guard let lineDigit = first.wholeNumberValue, (1...9).contains(lineDigit) else { return nil }
        guard Int(trimmed) != nil else { return nil }
        return lineDigit
    }

    /// 해당 열번이 실시간 위치 버튼을 노출할 자격이 있는지.
    static func isPositionable(trainNo raw: String) -> Bool {
        line(fromTrainNo: raw) != nil
    }

    /// numTr 열번을 실시간 API의 trainNo와 비교할 "매칭 키"로 변환한다.
    /// numTr는 맨 앞 1자리가 호선 표시(2204→2호선)이므로 그 자리를 떼고 비교한다.
    /// API trainNo도 뒤 3자리가 실제 열번이라, 양쪽 모두 뒤 3자리(suffix)로 맞춘다.
    /// 예) numTr "2204" -> "204",  API trainNo "2204" -> "204"
    static func matchKey(_ trainNo: String) -> String {
        let trimmed = trainNo.trimmingCharacters(in: .whitespaces)
        return String(trimmed.suffix(3))
    }

    /// 두 열번이 같은 열차를 가리키는지(앞 호선자리 무시, 뒤 3자리 비교).
    static func sameTrain(_ a: String, _ b: String) -> Bool {
        matchKey(a) == matchKey(b)
    }

    /// 홀수 열번 여부. 2호선 홀수 열번은 성수에서 열번이 바뀌므로
    /// 교대 전 "전 열번" 조회 트리거로 쓴다.
    static func isOdd(_ trainNo: String) -> Bool {
        guard let n = Int(trainNo.trimmingCharacters(in: .whitespaces)) else { return false }
        return n % 2 != 0
    }

    /// updnLine 코드 -> 한국어. 2호선은 내/외선, 그 외는 상/하행.
    static func directionLabel(updnLine: String, line: Int) -> String {
        if line == 2 {
            return updnLine == "0" ? "내선순환" : "외선순환"
        }
        return updnLine == "0" ? "상행" : "하행"
    }

    /// trainSttus 코드 -> 한국어.
    static func statusLabel(_ code: String) -> String {
        switch code {
        case "0": return "진입"
        case "1": return "도착"
        case "2": return "출발"
        case "3": return "전역 출발"
        default:  return "운행중"
        }
    }
}
