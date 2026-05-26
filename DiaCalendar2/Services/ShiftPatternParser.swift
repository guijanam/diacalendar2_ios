//
//  ShiftPatternParser.swift
//  DiaCalendar2
//

import Foundation

/// Parses the various shift-pattern string formats coming from Supabase.
/// Handles:
///   * PostgreSQL array literal: `{1,2,비}` or `{"1","2","비"}`
///   * JSON array literal: `["1","2","비"]`
///   * Plain CSV: `1, 2, 비`
///   * `nil`, empty string, `{}`, `[]`
enum ShiftPatternParser {
    static func parse(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return [] }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "{}" || trimmed == "[]" { return [] }

        let stripped = trimmed
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "\"", with: "")

        return stripped
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
