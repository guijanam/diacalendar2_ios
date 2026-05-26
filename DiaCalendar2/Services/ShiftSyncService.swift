//
//  ShiftSyncService.swift
//  DiaCalendar2
//

import Foundation

/// Bridges Supabase fetches and local persistence.
/// Keeps `OfficeRecord` / `DiaRecord` tables in sync with the remote `office`/`dia` tables.
actor ShiftSyncService {
    private let officeRepo: OfficeRecordRepository
    private let diaRepo: DiaRecordRepository
    private let syncStateRepo: SyncStateRepository

    init(officeRepo: OfficeRecordRepository, diaRepo: DiaRecordRepository, syncStateRepo: SyncStateRepository) {
        self.officeRepo = officeRepo
        self.diaRepo = diaRepo
        self.syncStateRepo = syncStateRepo
    }

    /// Pull all offices (light list) into local DB. Returns the local rows after sync.
    @discardableResult
    func refreshOfficeList() async throws -> [OfficeRecordDTO] {
        let remote = try await SupabaseAPI.listOffices()
        let dtos: [OfficeRecordDTO] = remote.map { r in
            OfficeRecordDTO(
                officeCode: r.officeCode,
                officeName: r.officeName,
                diaTurns1: r.diaTurns1,
                diaTurns2: r.diaTurns2,
                diaTurns3: r.diaTurns3,
                subTurns: r.subTurns,
                diaSelects: r.diaSelects,
                updatedAt: Date()
            )
        }
        await officeRepo.upsert(dtos)
        await syncStateRepo.setLastSupabaseShiftSyncAt(Date())
        return await officeRepo.all()
    }

    /// Fetch one office detail + its dia rows and persist them.
    @discardableResult
    func refreshOfficeDetail(name: String) async throws -> (office: OfficeRecordDTO?, dias: [DiaRecordDTO]) {
        async let officeFetch = SupabaseAPI.office(named: name)
        async let diaFetch = SupabaseAPI.dias(officeName: name)
        let office = try await officeFetch
        let dias = try await diaFetch

        if let office {
            let dto = OfficeRecordDTO(
                officeCode: office.officeCode,
                officeName: office.officeName,
                diaTurns1: office.diaTurns1,
                diaTurns2: office.diaTurns2,
                diaTurns3: office.diaTurns3,
                subTurns: office.subTurns,
                diaSelects: office.diaSelects,
                updatedAt: Date()
            )
            await officeRepo.upsert([dto])
        }

        let now = Date()
        let officeCode = office?.officeCode ?? 0
        let diaDtos: [DiaRecordDTO] = dias.map { d in
            DiaRecordDTO(
                officeName: d.officeName,
                officeCode: officeCode,
                diaId: d.diaId,
                typeName: d.typeName,
                firstTime: d.firstTime,
                numTr1: d.numTr1,
                numTr2: d.numTr2,
                secondTime: d.secondTime,
                thirdTime: d.thirdTime,
                totalTime: d.totalTime,
                workTime: d.workTime,
                updatedAt: now
            )
        }
        await diaRepo.replaceAll(forOffice: name, with: diaDtos)
        await syncStateRepo.setLastSupabaseShiftSyncAt(Date())

        let savedOffice = await officeRepo.office(name: name)
        let savedDias = await diaRepo.dias(forOffice: name)
        return (savedOffice, savedDias)
    }
}
