//
//  BackupModels.swift
//  DiaCalendar2
//
//  백업/복원용 Codable 아카이브 모델. 기존 DTO는 UI 전반에서 쓰이므로 건드리지 않고
//  별도 Codable 구조체로 변환해 JSON으로 직렬화한다.
//

import Foundation

/// 백업 파일 최상위 구조. version으로 향후 스키마 변경에 대비.
struct BackupArchive: Codable {
    static let currentVersion = 1

    var version: Int
    var createdAt: Date

    var userShiftConfig: BackupUserShiftConfig?
    var customShifts: [BackupCustomShift]
    var attendanceTypes: [BackupAttendanceType]
    var attendanceRecords: [BackupAttendanceRecord]
    var shiftSwaps: [BackupShiftSwap]
    var shiftInputs: [BackupShiftInput]
    var memos: [BackupMemo]
    var lunarAnniversaries: [BackupLunarAnniversary]
}

// MARK: - 근무 설정 (싱글톤)

struct BackupUserShiftConfig: Codable {
    var officeCode: Int64
    var officeName: String
    var position: String          // ShiftPosition.rawValue
    var shiftPattern: [String]
    var startDate: Date
    var referenceDate: Date
    var todayShift: String
    var todayShiftIndex: Int?
    var createdAt: Date

    init(from dto: UserShiftConfigDTO) {
        officeCode = dto.officeCode
        officeName = dto.officeName
        position = dto.position.rawValue
        shiftPattern = dto.shiftPattern
        startDate = dto.startDate
        referenceDate = dto.referenceDate
        todayShift = dto.todayShift
        todayShiftIndex = dto.todayShiftIndex
        createdAt = dto.createdAt
    }

    func toDTO() -> UserShiftConfigDTO {
        UserShiftConfigDTO(
            officeCode: officeCode,
            officeName: officeName,
            position: ShiftPosition(rawValue: position) ?? .custom,
            shiftPattern: shiftPattern,
            startDate: startDate,
            referenceDate: referenceDate,
            todayShift: todayShift,
            todayShiftIndex: todayShiftIndex,
            createdAt: createdAt
        )
    }
}

// MARK: - CustomShift

struct BackupCustomShift: Codable {
    var id: UUID
    var shiftName: String
    var shiftPattern: [String]
    var createdAt: Date

    init(from dto: CustomShiftDTO) {
        id = dto.id
        shiftName = dto.shiftName
        shiftPattern = dto.shiftPattern
        createdAt = dto.createdAt
    }

    func toDTO() -> CustomShiftDTO {
        CustomShiftDTO(id: id, shiftName: shiftName, shiftPattern: shiftPattern, createdAt: createdAt)
    }
}

// MARK: - 근태 유형

struct BackupAttendanceType: Codable {
    var id: UUID
    var name: String
    var shortName: String
    var createdAt: Date
    var limitCount: Int?
    var resetMonth: Int?
    var resetDay: Int?
    var resetYear: Int?
    var resetCycleYears: Int

    init(from dto: AttendanceTypeDTO) {
        id = dto.id
        name = dto.name
        shortName = dto.shortName
        createdAt = dto.createdAt
        limitCount = dto.limitCount
        resetMonth = dto.resetMonth
        resetDay = dto.resetDay
        resetYear = dto.resetYear
        resetCycleYears = dto.resetCycleYears
    }

    func toDTO() -> AttendanceTypeDTO {
        AttendanceTypeDTO(
            id: id,
            name: name,
            shortName: shortName,
            createdAt: createdAt,
            limitCount: limitCount,
            resetMonth: resetMonth,
            resetDay: resetDay,
            resetYear: resetYear,
            resetCycleYears: resetCycleYears
        )
    }
}

// MARK: - 근태 기록

struct BackupAttendanceRecord: Codable {
    var date: Date
    var attendanceTypeId: UUID
    var name: String
    var shortName: String
    var originalShiftName: String
    var groupId: UUID
    var createdAt: Date
    var category: String          // AttendanceCategory.rawValue

    init(from dto: AttendanceRecordDTO) {
        date = dto.date
        attendanceTypeId = dto.attendanceTypeId
        name = dto.name
        shortName = dto.shortName
        originalShiftName = dto.originalShiftName
        groupId = dto.groupId
        createdAt = dto.createdAt
        category = dto.category.rawValue
    }

    func toDTO() -> AttendanceRecordDTO {
        AttendanceRecordDTO(
            date: date,
            attendanceTypeId: attendanceTypeId,
            name: name,
            shortName: shortName,
            originalShiftName: originalShiftName,
            groupId: groupId,
            createdAt: createdAt,
            category: AttendanceCategory(rawValue: category) ?? .normal
        )
    }
}

// MARK: - 교체

struct BackupShiftSwap: Codable {
    var date: Date
    var originalShiftName: String
    var swappedShiftName: String
    var groupId: UUID
    var createdAt: Date

    init(from dto: ShiftSwapRecordDTO) {
        date = dto.date
        originalShiftName = dto.originalShiftName
        swappedShiftName = dto.swappedShiftName
        groupId = dto.groupId
        createdAt = dto.createdAt
    }

    func toDTO() -> ShiftSwapRecordDTO {
        ShiftSwapRecordDTO(
            date: date,
            originalShiftName: originalShiftName,
            swappedShiftName: swappedShiftName,
            groupId: groupId,
            createdAt: createdAt
        )
    }
}

// MARK: - 충당

struct BackupShiftInput: Codable {
    var date: Date
    var shiftInputTypeId: UUID
    var shortName: String
    var colorHex: String
    var targetShiftName: String
    var originalShiftName: String
    var groupId: UUID
    var createdAt: Date

    init(from dto: ShiftInputRecordDTO) {
        date = dto.date
        shiftInputTypeId = dto.shiftInputTypeId
        shortName = dto.shortName
        colorHex = dto.colorHex
        targetShiftName = dto.targetShiftName
        originalShiftName = dto.originalShiftName
        groupId = dto.groupId
        createdAt = dto.createdAt
    }

    func toDTO() -> ShiftInputRecordDTO {
        ShiftInputRecordDTO(
            date: date,
            shiftInputTypeId: shiftInputTypeId,
            shortName: shortName,
            colorHex: colorHex,
            targetShiftName: targetShiftName,
            originalShiftName: originalShiftName,
            groupId: groupId,
            createdAt: createdAt
        )
    }
}

// MARK: - 메모

struct BackupMemo: Codable {
    var id: UUID
    var title: String
    var body: String
    var colorHex: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date?
    var updatedAt: Date
    var isDone: Bool
    var recurrence: EventRecurrence?    // 이미 Codable

    init(from dto: DateMemoDTO) {
        id = dto.id
        title = dto.title
        body = dto.body
        colorHex = dto.colorHex
        startDate = dto.startDate
        endDate = dto.endDate
        createdAt = dto.createdAt
        updatedAt = dto.updatedAt
        isDone = dto.isDone
        recurrence = dto.recurrence
    }

    func toDTO() -> DateMemoDTO {
        DateMemoDTO(
            id: id,
            title: title,
            body: body,
            colorHex: colorHex,
            startDate: startDate,
            endDate: endDate,
            // 구버전 백업에는 createdAt이 없으므로 updatedAt으로 대체.
            createdAt: createdAt ?? updatedAt,
            updatedAt: updatedAt,
            isDone: isDone,
            recurrence: recurrence
        )
    }
}

// MARK: - 음력 기념일

struct BackupLunarAnniversary: Codable {
    var id: UUID
    var title: String
    var lunarMonth: Int
    var lunarDay: Int
    var isLeapMonth: Bool
    var colorHex: String
    var createdAt: Date

    init(from dto: LunarAnniversaryDTO) {
        id = dto.id
        title = dto.title
        lunarMonth = dto.lunarMonth
        lunarDay = dto.lunarDay
        isLeapMonth = dto.isLeapMonth
        colorHex = dto.colorHex
        createdAt = dto.createdAt
    }

    func toDTO() -> LunarAnniversaryDTO {
        LunarAnniversaryDTO(
            id: id,
            title: title,
            lunarMonth: lunarMonth,
            lunarDay: lunarDay,
            isLeapMonth: isLeapMonth,
            colorHex: colorHex,
            createdAt: createdAt
        )
    }
}
