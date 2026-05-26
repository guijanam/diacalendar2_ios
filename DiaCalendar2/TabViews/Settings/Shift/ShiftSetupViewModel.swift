//
//  ShiftSetupViewModel.swift
//  DiaCalendar2
//

import Foundation
import SwiftUI

enum ShiftSourceKind: String, CaseIterable, Identifiable {
    case server
    case custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .server: return "승무소"
        case .custom: return "교대근무자"
        }
    }
}

@MainActor
@Observable
final class ShiftSetupViewModel {
    // MARK: - Inputs
    var source: ShiftSourceKind = .server

    // Server path
    var officeQuery: String = ""
    var selectedOffice: OfficeRecordDTO?
    var availableOffices: [OfficeRecordDTO] = []
    var selectedPosition: ShiftPosition = .engineer
    var selectedReferenceShift: String = ""
    var selectedReferenceShiftIndex: Int?

    // Custom path
    var customShifts: [CustomShiftDTO] = []
    var selectedCustomShift: CustomShiftDTO?

    // Common
    var startDate: Date = ShiftRotationEngine.startOfDay(Date())
    var referenceDate: Date = ShiftRotationEngine.startOfDay(Date())

    // UX
    var isLoading: Bool = false
    var isSaving: Bool = false
    var errorMessage: String?
    var didSaveSuccessfully: Bool = false

    /// Existing config we read on appear (to pre-populate the form).
    private(set) var existingConfig: UserShiftConfigDTO?

    var filteredOffices: [OfficeRecordDTO] {
        guard !officeQuery.isEmpty else { return availableOffices }
        return availableOffices.filter { $0.officeName.localizedCaseInsensitiveContains(officeQuery) }
    }

    /// Pattern derived from the current selection.
    var currentPattern: [String] {
        switch source {
        case .server:
            guard let office = selectedOffice else { return [] }
            return selectedPosition.pattern(in: office)
        case .custom:
            return selectedCustomShift?.shiftPattern ?? []
        }
    }

    /// Shift options the user can pick from for "기준 근무" (Step 4).
    var referenceShiftOptions: [String] {
        switch source {
        case .server:
            if let office = selectedOffice, !office.diaSelects.isEmpty { return office.diaSelects }
            return currentPattern
        case .custom:
            return currentPattern
        }
    }

    var canSave: Bool {
        guard !currentPattern.isEmpty, !selectedReferenceShift.isEmpty else { return false }
        switch source {
        case .server: return selectedOffice != nil
        case .custom: return selectedCustomShift != nil
        }
    }

    func bootstrap(env: AppEnvironment) async {
        isLoading = true
        defer { isLoading = false }

        async let cfg = env.userShiftConfigRepository.load()
        async let localOffices = env.officeRecordRepository.all()
        async let customs = env.customShiftRepository.all()

        let existing = await cfg
        let officesLocal = await localOffices
        self.customShifts = await customs
        self.existingConfig = existing

        if officesLocal.isEmpty {
            do {
                self.availableOffices = try await env.shiftSyncService.refreshOfficeList()
            } catch {
                self.errorMessage = error.localizedDescription
                self.availableOffices = []
            }
        } else {
            self.availableOffices = officesLocal
        }

    }

    func refreshOffices(env: AppEnvironment) async {
        isLoading = true
        defer { isLoading = false }
        do {
            availableOffices = try await env.shiftSyncService.refreshOfficeList()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// On office selection, also fetch dia rows so DayDetail has the data later.
    func selectOffice(_ office: OfficeRecordDTO, env: AppEnvironment) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let (saved, _) = try await env.shiftSyncService.refreshOfficeDetail(name: office.officeName)
            selectedOffice = saved ?? office
        } catch {
            errorMessage = error.localizedDescription
            selectedOffice = office
        }
    }

    /// Persist the config and generate 3 years of schedules.
    func save(env: AppEnvironment) async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        let pattern = currentPattern
        let position = (source == .custom) ? ShiftPosition.custom : selectedPosition
        let officeCode: Int64
        let officeName: String
        switch source {
        case .server:
            guard let o = selectedOffice else { return }
            officeCode = o.officeCode
            officeName = o.officeName
        case .custom:
            guard let cs = selectedCustomShift else { return }
            // Encode customShift via a stable negative code derived from its UUID.
            // Keep it within Int64 safe range; the exact code is opaque — we only use it as an identifier.
            let lower = UInt64(cs.id.uuid.0) | (UInt64(cs.id.uuid.1) << 8)
            officeCode = -(10_000 + Int64(lower & 0x7FFF_FFFF))
            officeName = cs.shiftName
        }

        let dto = UserShiftConfigDTO(
            officeCode: officeCode,
            officeName: officeName,
            position: position,
            shiftPattern: pattern,
            startDate: ShiftRotationEngine.startOfDay(startDate),
            referenceDate: ShiftRotationEngine.startOfDay(referenceDate),
            todayShift: selectedReferenceShift,
            todayShiftIndex: selectedReferenceShiftIndex,
            createdAt: Date()
        )

        await env.userShiftConfigRepository.save(dto)
        do {
            _ = try await env.shiftScheduleRepository.generateAndSave(
                pattern: pattern,
                startDate: dto.startDate,
                referenceDate: dto.referenceDate,
                todayShift: dto.todayShift,
                todayShiftIndex: dto.todayShiftIndex,
                years: 3
            )
            didSaveSuccessfully = true
            NotificationCenter.default.post(name: .shiftScheduleDidUpdate, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
