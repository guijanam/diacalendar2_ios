//
//  ShiftSetupView.swift
//  DiaCalendar2
//

import SwiftUI

struct ShiftSetupView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var vm = ShiftSetupViewModel()
    @State private var showOfficePicker = false

    var body: some View {
        Form {
            sourceSection
            switch vm.source {
            case .server:
                officeSection
                if vm.selectedOffice != nil {
                    positionSection
                }
            case .custom:
                customSection
            }

            if !vm.currentPattern.isEmpty {
                startDateSection
                referenceSection
                generateSection
            }
        }
        .navigationTitle("교번근무 설정")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if vm.isLoading || vm.isSaving {
                ProgressView()
                    .controlSize(.large)
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task { await vm.bootstrap(env: env) }
        .alert("오류", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onChange(of: vm.didSaveSuccessfully) { _, ok in
            if ok { dismiss() }
        }
        .sheet(isPresented: $showOfficePicker) {
            OfficePickerSheet(vm: vm, env: env)
        }
    }

    // MARK: - Sections

    private var sourceSection: some View {
        Section {
            Picker("종류", selection: $vm.source) {
                ForEach(ShiftSourceKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.source) { _, _ in
                vm.selectedReferenceShift = ""
                vm.selectedReferenceShiftIndex = nil
            }
        }
    }

    private var officeSection: some View {
        Section {
            Button {
                showOfficePicker = true
            } label: {
                HStack {
                    Text("승무소")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(vm.selectedOffice?.officeName ?? "선택")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
        } header: {
            stepHeader(1, "승무소 선택")
        }
    }

    private var positionSection: some View {
        Section {
            Picker("포지션", selection: $vm.selectedPosition) {
                Text("기관사").tag(ShiftPosition.engineer)
                Text("차장").tag(ShiftPosition.conductor)
                Text("4조2교대").tag(ShiftPosition.fourShift)
            }
            .pickerStyle(.segmented)

            // if vm.currentPattern.isEmpty {
            //     Text("이 포지션은 선택한 승무소에 등록된 교번이 없습니다.")
            //         .font(.caption)
            //         .foregroundStyle(.secondary)
            // } else {
            //     Text("패턴: \(vm.currentPattern.joined(separator: " → "))")
            //         .font(.caption)
            //         .foregroundStyle(.secondary)
            // }
        } header: {
            stepHeader(2, "포지션 선택")
        }
    }

    private var customSection: some View {
        Section {
            if vm.customShifts.isEmpty {
                Text("등록된 교대근무가 없습니다.\n설정 → 교대근무 편집에서 추가해주세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("교대근무", selection: Binding(
                    get: { vm.selectedCustomShift?.id },
                    set: { newId in
                        vm.selectedCustomShift = vm.customShifts.first { $0.id == newId }
                        vm.selectedReferenceShift = ""
                        vm.selectedReferenceShiftIndex = nil
                    }
                )) {
                    Text("선택").tag(UUID?.none)
                    ForEach(vm.customShifts) { cs in
                        Text(cs.shiftName).tag(Optional(cs.id))
                    }
                }
                if !vm.currentPattern.isEmpty {
                    Text("패턴: \(vm.currentPattern.joined(separator: " → "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            stepHeader(1, "교대근무 선택")
        }
    }

    private var startDateSection: some View {
        Section {
            DatePicker(
                "시작일",
                selection: $vm.startDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            Text("이 날짜부터 캘린더에 교번이 표시됩니다. 시작일 이전 기존 스케줄은 유지됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            stepHeader(vm.source == .custom ? 2 : 3, "시작일")
        }
    }

    private var referenceSection: some View {
        Section {
            DatePicker(
                "기준일",
                selection: $vm.referenceDate,
                displayedComponents: .date
            )
            Picker("기준 근무", selection: $vm.selectedReferenceShift) {
                Text("선택").tag("")
                ForEach(Array(vm.referenceShiftOptions.enumerated()), id: \.offset) { _, shift in
                    Text(shift).tag(shift)
                }
            }
            Text("기준일에 어떤 근무를 하시는지 선택하세요. 이를 기준으로 회전 패턴이 정렬됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            stepHeader(vm.source == .custom ? 3 : 4, "기준 근무")
        }
    }

    private var generateSection: some View {
        Section {
            Button {
                Task { await vm.save(env: env) }
            } label: {
                HStack {
                    Spacer()
                    Text("근무 생성 (3년)")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(!vm.canSave || vm.isSaving)

            if vm.existingConfig != nil {
                Text("기존 설정이 있습니다. 저장하면 시작일 이후 스케줄만 새로 생성됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            stepHeader(vm.source == .custom ? 4 : 5, "생성")
        }
    }

    @ViewBuilder
    private func stepHeader(_ n: Int, _ title: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.accentColor)
                Text("\(n)").font(.caption2).foregroundStyle(.white)
            }
            .frame(width: 18, height: 18)
            Text(title)
        }
    }
}

// MARK: - Office picker

private struct OfficePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var vm: ShiftSetupViewModel
    let env: AppEnvironment

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.filteredOffices) { office in
                    Button {
                        Task {
                            await vm.selectOffice(office, env: env)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text(office.officeName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if vm.selectedOffice?.officeCode == office.officeCode {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .searchable(text: $vm.officeQuery, prompt: "승무소 검색")
            .navigationTitle("승무소 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.refreshOffices(env: env) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}
