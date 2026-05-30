//
//  CoworkerEditView.swift
//  DiaCalendar2
//

import SwiftUI

/// 동료 추가/편집 화면. 4가지(직접입력/승무소/교대근무) 패턴 소스를 지원한다.
struct CoworkerEditView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    let coworkerId: UUID?
    var onFinished: () -> Void

    @State private var vm: CoworkerEditViewModel?
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(coworkerId == nil ? "동료 추가" : "동료 편집")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if vm == nil {
                let newVM = CoworkerEditViewModel(
                    repo: appEnvironment.coworkerRepository,
                    officeRepo: appEnvironment.officeRecordRepository,
                    customShiftRepo: appEnvironment.customShiftRepository
                )
                await newVM.loadInitial(coworkerId: coworkerId)
                vm = newVM
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: CoworkerEditViewModel) -> some View {
        @Bindable var vm = vm
        Form {
            // 이름
            Section("이름") {
                TextField("동료 이름", text: $vm.name)
            }

            // 패턴 소스
            Section("근무 패턴") {
                Picker("패턴 소스", selection: Binding(
                    get: { vm.patternSource },
                    set: { vm.onPatternSourceChange($0) }
                )) {
                    ForEach(CoworkerPatternSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.segmented)

                switch vm.patternSource {
                case .manual:
                    manualSection(vm)
                case .office:
                    officeSection(vm)
                case .customShift:
                    customShiftSection(vm)
                }
            }

            // 기준일 + 기준근무
            if !vm.parsedPattern.isEmpty {
                Section("기준 설정") {
                    DatePicker(
                        "기준 날짜",
                        selection: $vm.referenceDate,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))

                    referenceShiftPicker(vm)
                }
            }

            // 그룹
            Section("소속 그룹") {
                if vm.allGroups.isEmpty {
                    Text("등록된 그룹이 없습니다")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(vm.allGroups) { group in
                        Button {
                            vm.toggleGroup(group.id)
                        } label: {
                            HStack {
                                Text(group.name).foregroundStyle(.primary)
                                Spacer()
                                if vm.selectedGroupIds.contains(group.id) {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }

            // 삭제
            if coworkerId != nil {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("동료 삭제")
                            Spacer()
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") {
                    Task {
                        if await vm.save() {
                            onFinished()
                            dismiss()
                        }
                    }
                }
                .disabled(vm.isLoading)
            }
        }
        .alert("동료 삭제", isPresented: $showDeleteConfirm) {
            Button("삭제", role: .destructive) {
                Task {
                    await vm.delete()
                    onFinished()
                    dismiss()
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 동료를 삭제하시겠습니까?")
        }
        .alert("입력 오류", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - 직접입력

    @ViewBuilder
    private func manualSection(_ vm: CoworkerEditViewModel) -> some View {
        @Bindable var vm = vm
        TextField("예: 주,야,비,휴", text: Binding(
            get: { vm.shiftPatternInput },
            set: { vm.onManualPatternChange($0) }
        ))
        Text("쉼표(,)로 근무를 구분해 순환 패턴을 입력하세요.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - 승무소

    @ViewBuilder
    private func officeSection(_ vm: CoworkerEditViewModel) -> some View {
        Menu {
            ForEach(vm.filteredOffices) { office in
                Button(office.officeName) { vm.onOfficeSelected(office) }
            }
        } label: {
            HStack {
                Text(vm.selectedOffice?.officeName ?? "승무소 선택")
                    .foregroundStyle(vm.selectedOffice == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
            }
        }

        if vm.selectedOffice != nil {
            Picker("포지션", selection: Binding(
                get: { vm.selectedPosition },
                set: { if let p = $0 { vm.onPositionSelected(p) } }
            )) {
                Text("선택").tag(ShiftPosition?.none)
                ForEach([ShiftPosition.engineer, .conductor, .fourShift], id: \.self) { position in
                    Text(position.displayName).tag(ShiftPosition?.some(position))
                }
            }
        }
    }

    // MARK: - 교대근무

    @ViewBuilder
    private func customShiftSection(_ vm: CoworkerEditViewModel) -> some View {
        if vm.customShifts.isEmpty {
            Text("등록된 교대근무가 없습니다. 설정 > 교대근무에서 먼저 추가하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Menu {
                ForEach(vm.customShifts) { shift in
                    Button(shift.shiftName) { vm.onCustomShiftSelected(shift) }
                }
            } label: {
                HStack {
                    Text(vm.selectedCustomShift?.shiftName ?? "교대근무 선택")
                        .foregroundStyle(vm.selectedCustomShift == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 기준 근무 선택

    @ViewBuilder
    private func referenceShiftPicker(_ vm: CoworkerEditViewModel) -> some View {
        let shifts = vm.availableShifts
        if shifts.isEmpty {
            Text("패턴/포지션을 먼저 선택하세요")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Menu {
                ForEach(Array(shifts.enumerated()), id: \.offset) { index, shift in
                    Button {
                        vm.onReferenceShiftSelected(shift, availableIndex: index)
                    } label: {
                        if index == vm.referenceShiftAvailableIndex {
                            Label(shift, systemImage: "checkmark")
                        } else {
                            Text(shift)
                        }
                    }
                }
            } label: {
                HStack {
                    Text("기준 날짜의 근무")
                    Spacer()
                    Text(vm.referenceShift.isEmpty ? "선택" : vm.referenceShift)
                        .foregroundStyle(vm.referenceShift.isEmpty ? .secondary : .primary)
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
