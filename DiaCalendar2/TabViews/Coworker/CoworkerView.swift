//
//  CoworkerView.swift
//  DiaCalendar2
//

import SwiftUI

/// 동료근무 화면. 안드로이드 CoworkerScreen 이식 — 달력(행렬형)/목록 탭 + 그룹 필터.
struct CoworkerView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var vm: CoworkerViewModel?
    @State private var editTarget: EditTarget?
    @State private var showGroupManage = false

    private enum EditTarget: Identifiable, Hashable {
        case new
        case existing(UUID)
        var id: String {
            switch self {
            case .new: return "new"
            case .existing(let id): return id.uuidString
            }
        }
    }

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("동료 근무")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if vm == nil {
                let newVM = CoworkerViewModel(appEnvironment: appEnvironment)
                await newVM.reloadAll()
                vm = newVM
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: CoworkerViewModel) -> some View {
        @Bindable var vm = vm
        VStack(spacing: 0) {
            // 탭 + 그룹 필터
            HStack(spacing: 12) {
                Picker("탭", selection: $vm.selectedTab) {
                    Text("달력").tag(CoworkerViewModel.Tab.calendar)
                    Text("목록").tag(CoworkerViewModel.Tab.list)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)

                Spacer()

                groupFilterMenu(vm)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            if vm.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch vm.selectedTab {
                case .calendar:
                    calendarTab(vm)
                case .list:
                    listTab(vm)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editTarget = .new
                    } label: {
                        Label("동료 추가", systemImage: "person.badge.plus")
                    }
                    Button {
                        showGroupManage = true
                    } label: {
                        Label("그룹 관리", systemImage: "person.2")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editTarget) { target in
            NavigationStack {
                CoworkerEditView(
                    coworkerId: target == .new ? nil : {
                        if case .existing(let id) = target { return id } else { return nil }
                    }(),
                    onFinished: { Task { await vm.reloadAll() } }
                )
            }
        }
        .sheet(isPresented: $showGroupManage, onDismiss: { Task { await vm.reloadAll() } }) {
            NavigationStack { CoworkerGroupView() }
        }
    }

    // MARK: - 그룹 필터

    @ViewBuilder
    private func groupFilterMenu(_ vm: CoworkerViewModel) -> some View {
        Menu {
            Button {
                Task { await vm.onGroupSelected(nil) }
            } label: {
                if vm.selectedGroupId == nil { Label("전체", systemImage: "checkmark") } else { Text("전체") }
            }
            ForEach(vm.groups) { group in
                Button {
                    Task { await vm.onGroupSelected(group.id) }
                } label: {
                    if vm.selectedGroupId == group.id { Label(group.name, systemImage: "checkmark") } else { Text(group.name) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(vm.groups.first(where: { $0.id == vm.selectedGroupId })?.name ?? "전체")
                    .font(.subheadline)
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.secondarySystemFill))
            .clipShape(Capsule())
        }
    }

    // MARK: - 달력 탭

    @ViewBuilder
    private func calendarTab(_ vm: CoworkerViewModel) -> some View {
        VStack(spacing: 0) {
            // 월 이동 헤더
            HStack {
                Button { Task { await vm.goToPreviousMonth() } } label: {
                    Image(systemName: "chevron.left")
                }
                Text("\(String(vm.currentYear))년 \(vm.currentMonth)월")
                    .font(.headline)
                    .frame(minWidth: 120)
                Button { Task { await vm.goToNextMonth() } } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.vertical, 8)

            if vm.coworkers.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "등록된 동료가 없습니다",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("우측 상단 + 버튼으로 동료를 추가하세요.")
                )
                Spacer()
            } else {
                CoworkerMatrixCalendar(
                    year: vm.currentYear,
                    month: vm.currentMonth,
                    myScheduleMap: vm.myScheduleMap,
                    coworkers: vm.filteredCoworkers,
                    coworkerSchedules: vm.coworkerSchedules,
                    holidayDates: vm.holidayDates
                )
            }
        }
    }

    // MARK: - 목록 탭

    @ViewBuilder
    private func listTab(_ vm: CoworkerViewModel) -> some View {
        if vm.filteredCoworkers.isEmpty {
            ContentUnavailableView(
                "등록된 동료가 없습니다",
                systemImage: "person.crop.circle.badge.plus",
                description: Text("우측 상단 + 버튼으로 동료를 추가하세요.")
            )
        } else {
            List {
                ForEach(vm.filteredCoworkers) { coworker in
                    Button {
                        editTarget = .existing(coworker.id)
                    } label: {
                        CoworkerRow(coworker: coworker, groups: vm.groups)
                    }
                    .buttonStyle(.plain)
                }
                .onMove { source, dest in
                    Task { await vm.moveCoworkers(from: source, to: dest) }
                }
            }
            .environment(\.editMode, .constant(.active))
        }
    }
}

// MARK: - 목록 행

private struct CoworkerRow: View {
    let coworker: CoworkerDTO
    let groups: [CoworkerGroupDTO]

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.18)).frame(width: 38, height: 38)
                Text(String(coworker.name.prefix(1)))
                    .font(.headline)
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(coworker.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                let belonging = groups.filter { coworker.groupIds.contains($0.id) }
                if !belonging.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(belonging) { group in
                            Text(group.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
