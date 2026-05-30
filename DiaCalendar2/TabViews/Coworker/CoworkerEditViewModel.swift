//
//  CoworkerEditViewModel.swift
//  DiaCalendar2
//

import Foundation
import Observation

/// 패턴 입력 방식. (안드로이드 CoworkerPatternSource — iOS엔 로컬승무소 데이터가 없어 3종)
enum CoworkerPatternSource: String, CaseIterable, Identifiable {
    case manual       // 직접 입력
    case office       // 서버 승무소에서 가져오기
    case customShift  // 교대근무에서 가져오기

    var id: String { rawValue }
    var title: String {
        switch self {
        case .manual: return "직접 입력"
        case .office: return "승무소"
        case .customShift: return "교대근무"
        }
    }
}

@Observable
@MainActor
final class CoworkerEditViewModel {
    // 식별
    var coworkerId: UUID?
    var name: String = ""

    // 패턴 소스
    var patternSource: CoworkerPatternSource = .manual

    // 직접입력
    var shiftPatternInput: String = ""   // UI용 CSV 문자열

    // 승무소 선택
    var offices: [OfficeRecordDTO] = []
    var officeSearchQuery: String = ""
    var selectedOffice: OfficeRecordDTO?
    var selectedPosition: ShiftPosition?

    // 교대근무 선택
    var customShifts: [CustomShiftDTO] = []
    var selectedCustomShift: CustomShiftDTO?

    // 공통
    var referenceDate: Date = ShiftRotationEngine.startOfDay(Date())
    var referenceShift: String = ""
    var referenceShiftIndex: Int?           // parsedPattern 내 인덱스 (저장용)
    var referenceShiftAvailableIndex: Int?  // availableShifts 내 인덱스 (선택 강조용)

    var selectedGroupIds: Set<UUID> = []
    var allGroups: [CoworkerGroupDTO] = []

    var isLoading = false
    var errorMessage: String?

    private let repo: CoworkerRepository
    private let officeRepo: OfficeRecordRepository
    private let customShiftRepo: CustomShiftRepository

    init(repo: CoworkerRepository, officeRepo: OfficeRecordRepository, customShiftRepo: CustomShiftRepository) {
        self.repo = repo
        self.officeRepo = officeRepo
        self.customShiftRepo = customShiftRepo
    }

    // MARK: - Derived patterns

    /// 직접 입력한 패턴 파싱
    var parsedManualPattern: [String] {
        shiftPatternInput.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 승무소/교대근무 패턴 (포지션 선택 후 결정)
    var officeShiftPattern: [String] {
        switch patternSource {
        case .customShift:
            return selectedCustomShift?.shiftPattern ?? []
        case .office:
            guard let office = selectedOffice, let position = selectedPosition else { return [] }
            return position.pattern(in: office)
        case .manual:
            return []
        }
    }

    /// 실제 사용할 패턴
    var parsedPattern: [String] {
        patternSource == .manual ? parsedManualPattern : officeShiftPattern
    }

    /// 기준교번 선택 시 사용할 shifts
    /// (승무소: diaSelects, 교대근무/직접입력: 패턴 자체)
    var availableShifts: [String] {
        switch patternSource {
        case .customShift:
            return officeShiftPattern
        case .office:
            return selectedOffice?.diaSelects ?? []
        case .manual:
            return parsedManualPattern
        }
    }

    var filteredOffices: [OfficeRecordDTO] {
        guard !officeSearchQuery.isEmpty else { return offices }
        return offices.filter { $0.officeName.localizedCaseInsensitiveContains(officeSearchQuery) }
    }

    // MARK: - Loading

    func loadInitial(coworkerId: UUID?) async {
        async let groupsTask = repo.allGroups()
        async let officesTask = officeRepo.all()
        async let customTask = customShiftRepo.all()
        allGroups = await groupsTask
        offices = await officesTask
        customShifts = await customTask

        if let coworkerId, let coworker = await repo.coworker(id: coworkerId) {
            self.coworkerId = coworker.id
            name = coworker.name
            // 편집 시에는 저장된 패턴을 직접입력 형태로 보여준다 (안드로이드와 동일).
            patternSource = .manual
            shiftPatternInput = coworker.shiftPattern.joined(separator: ",")
            referenceDate = coworker.referenceDate
            referenceShift = coworker.referenceShift
            referenceShiftIndex = coworker.referenceShiftIndex
            referenceShiftAvailableIndex = coworker.referenceShiftIndex
            selectedGroupIds = Set(coworker.groupIds)
        }
    }

    // MARK: - Mutations

    func onPatternSourceChange(_ source: CoworkerPatternSource) {
        patternSource = source
        selectedOffice = nil
        selectedCustomShift = nil
        selectedPosition = nil
        officeSearchQuery = ""
        clearReferenceShift()
    }

    func onManualPatternChange(_ value: String) {
        shiftPatternInput = value
        clearReferenceShift()
    }

    func onOfficeSelected(_ office: OfficeRecordDTO) {
        selectedOffice = office
        officeSearchQuery = office.officeName
        selectedPosition = nil
        clearReferenceShift()
    }

    func onPositionSelected(_ position: ShiftPosition) {
        selectedPosition = position
        clearReferenceShift()
    }

    func onCustomShiftSelected(_ shift: CustomShiftDTO) {
        selectedCustomShift = shift
        selectedOffice = nil
        officeSearchQuery = ""
        clearReferenceShift()
    }

    func onReferenceShiftSelected(_ shift: String, availableIndex index: Int) {
        // 승무소: availableShifts(diaSelects)와 parsedPattern(diaTurns)이 다르므로
        //   availableShifts[index]의 occurrence(N번째 등장)를 구해 parsedPattern에서 같은 occurrence 위치로 매칭.
        // 교대근무/직접입력: availableShifts == parsedPattern → index 그대로.
        let patternIndex: Int?
        switch patternSource {
        case .office:
            let available = availableShifts
            let pattern = parsedPattern
            let occurrence = available.prefix(index + 1).filter { $0 == shift }.count
            var found: Int? = nil
            var seen = 0
            for i in pattern.indices where pattern[i] == shift {
                seen += 1
                if seen == occurrence { found = i; break }
            }
            patternIndex = found ?? pattern.firstIndex(of: shift)
        default:
            patternIndex = index
        }
        referenceShift = shift
        referenceShiftIndex = patternIndex
        referenceShiftAvailableIndex = index
    }

    func toggleGroup(_ groupId: UUID) {
        if selectedGroupIds.contains(groupId) {
            selectedGroupIds.remove(groupId)
        } else {
            selectedGroupIds.insert(groupId)
        }
    }

    private func clearReferenceShift() {
        referenceShift = ""
        referenceShiftIndex = nil
        referenceShiftAvailableIndex = nil
    }

    // MARK: - Save / Delete

    /// 저장 성공 시 true 반환.
    func save() async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { errorMessage = "이름을 입력해주세요"; return false }
        guard !parsedPattern.isEmpty else { errorMessage = "근무 패턴을 입력/선택해주세요"; return false }
        guard !referenceShift.isEmpty else { errorMessage = "기준 근무를 선택해주세요"; return false }

        isLoading = true
        defer { isLoading = false }

        // sortOrder: 신규는 맨 뒤. 편집은 기존 값 유지.
        let sortOrder: Int
        if let coworkerId, let existing = await repo.coworker(id: coworkerId) {
            sortOrder = existing.sortOrder
        } else {
            sortOrder = (await repo.allCoworkers()).count
        }

        let dto = CoworkerDTO(
            id: coworkerId ?? UUID(),
            name: trimmedName,
            sortOrder: sortOrder,
            groupIds: Array(selectedGroupIds),
            shiftPattern: parsedPattern,
            referenceDate: ShiftRotationEngine.startOfDay(referenceDate),
            referenceShift: referenceShift,
            referenceShiftIndex: referenceShiftIndex,
            createdAt: Date()
        )
        await repo.upsertCoworker(dto)
        return true
    }

    func delete() async {
        guard let coworkerId else { return }
        await repo.deleteCoworker(id: coworkerId)
    }
}
