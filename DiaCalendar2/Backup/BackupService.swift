//
//  BackupService.swift
//  DiaCalendar2
//
//  사용자 데이터(근무 설정·교체·충당·근태·메모·기념일)를 JSON으로 내보내고
//  다시 가져와 전체 교체 복원한다. 근무표(ShiftSchedule)는 백업하지 않고
//  UserShiftConfig로부터 ShiftRotationEngine으로 재생성한다.
//

import Foundation

enum BackupError: LocalizedError {
    case emptyArchive
    case unsupportedVersion(Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .emptyArchive: return "복원할 데이터가 없습니다."
        case .unsupportedVersion(let v): return "지원하지 않는 백업 버전입니다 (v\(v))."
        case .decodeFailed: return "백업 파일을 읽을 수 없습니다. 올바른 파일인지 확인해주세요."
        }
    }
}

@MainActor
enum BackupService {

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Export

    /// 현재 사용자 데이터를 백업 JSON으로 직렬화한다.
    static func export(using env: AppEnvironment) async throws -> Data {
        async let configTask = env.userShiftConfigRepository.load()
        async let customsTask = env.customShiftRepository.all()
        async let attendanceTypesTask = env.attendanceTypeRepository.all()
        async let attendanceRecordsTask = env.attendanceRecordRepository.all()
        async let swapsTask = env.shiftSwapRecordRepository.all()
        async let inputsTask = env.shiftInputRecordRepository.all()
        async let memosTask = env.dateMemoRepository.all()
        async let lunarsTask = env.lunarAnniversaryRepository.all()

        let archive = BackupArchive(
            version: BackupArchive.currentVersion,
            createdAt: Date(),
            userShiftConfig: (await configTask).map(BackupUserShiftConfig.init(from:)),
            customShifts: (await customsTask).map(BackupCustomShift.init(from:)),
            attendanceTypes: (await attendanceTypesTask).map(BackupAttendanceType.init(from:)),
            attendanceRecords: (await attendanceRecordsTask).map(BackupAttendanceRecord.init(from:)),
            shiftSwaps: (await swapsTask).map(BackupShiftSwap.init(from:)),
            shiftInputs: (await inputsTask).map(BackupShiftInput.init(from:)),
            memos: (await memosTask).map(BackupMemo.init(from:)),
            lunarAnniversaries: (await lunarsTask).map(BackupLunarAnniversary.init(from:))
        )
        return try encoder().encode(archive)
    }

    // MARK: - Restore

    /// 백업 JSON을 디코드해 전체 교체 복원한다. 복원 항목 수를 반환.
    @discardableResult
    static func restore(from data: Data, using env: AppEnvironment) async throws -> Int {
        let archive: BackupArchive
        do {
            archive = try decoder().decode(BackupArchive.self, from: data)
        } catch {
            throw BackupError.decodeFailed
        }
        guard archive.version <= BackupArchive.currentVersion else {
            throw BackupError.unsupportedVersion(archive.version)
        }

        // 1. 근무 유형/커스텀 근무를 먼저 복원(레코드들이 typeId로 참조).
        await env.attendanceTypeRepository.deleteAll()
        for t in archive.attendanceTypes {
            let dto = t.toDTO()
            _ = await env.attendanceTypeRepository.upsert(
                id: dto.id,
                name: dto.name,
                shortName: dto.shortName,
                limitCount: dto.limitCount,
                resetMonth: dto.resetMonth,
                resetDay: dto.resetDay,
                resetYear: dto.resetYear,
                resetCycleYears: dto.resetCycleYears
            )
        }

        await env.customShiftRepository.deleteAll()
        for c in archive.customShifts {
            let dto = c.toDTO()
            _ = await env.customShiftRepository.upsert(id: dto.id, shiftName: dto.shiftName, shiftPattern: dto.shiftPattern)
        }

        // 2. 오버레이 레코드들(필드 그대로 보존 복원).
        await env.shiftSwapRecordRepository.restoreAll(archive.shiftSwaps.map { $0.toDTO() })
        await env.shiftInputRecordRepository.restoreAll(archive.shiftInputs.map { $0.toDTO() })
        await env.attendanceRecordRepository.restoreAll(archive.attendanceRecords.map { $0.toDTO() })

        // 3. 메모/기념일.
        await env.dateMemoRepository.deleteAll()
        for m in archive.memos {
            _ = await env.dateMemoRepository.upsert(m.toDTO())
        }
        await env.lunarAnniversaryRepository.deleteAll()
        for a in archive.lunarAnniversaries {
            _ = await env.lunarAnniversaryRepository.upsert(a.toDTO())
        }

        // 4. 근무 설정 복원 + 근무표 재생성(ShiftSetupViewModel.save 흐름 동일).
        if let cfg = archive.userShiftConfig?.toDTO() {
            await env.userShiftConfigRepository.save(cfg)
            _ = try? await env.shiftScheduleRepository.generateAndSave(
                pattern: cfg.shiftPattern,
                startDate: cfg.startDate,
                referenceDate: cfg.referenceDate,
                todayShift: cfg.todayShift,
                todayShiftIndex: cfg.todayShiftIndex,
                years: 3
            )
        } else {
            // 설정이 없으면 기존 근무 설정/근무표를 비운다(전체 교체 원칙).
            await env.userShiftConfigRepository.clear()
            await env.shiftScheduleRepository.deleteAll()
        }

        // 5. UI/위젯 갱신.
        NotificationCenter.default.post(name: .shiftScheduleDidUpdate, object: nil)
        NotificationCenter.default.post(name: .holidaysDidUpdate, object: nil)
        await WidgetDataGenerator.generateAndSave(using: env)

        return archive.customShifts.count
            + archive.attendanceTypes.count
            + archive.attendanceRecords.count
            + archive.shiftSwaps.count
            + archive.shiftInputs.count
            + archive.memos.count
            + archive.lunarAnniversaries.count
            + (archive.userShiftConfig == nil ? 0 : 1)
    }
}
