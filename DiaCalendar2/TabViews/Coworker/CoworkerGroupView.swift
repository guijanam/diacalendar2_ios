//
//  CoworkerGroupView.swift
//  DiaCalendar2
//

import SwiftUI

/// 그룹 관리 화면. 동료가 소속될 수 있는 그룹을 추가/편집/삭제한다.
struct CoworkerGroupView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var groups: [CoworkerGroupDTO] = []
    @State private var isLoading = true

    @State private var showAddDialog = false
    @State private var editTarget: CoworkerGroupDTO?
    @State private var deleteTarget: CoworkerGroupDTO?
    @State private var nameInput = ""

    private var repo: CoworkerRepository { appEnvironment.coworkerRepository }

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groups.isEmpty {
                ContentUnavailableView(
                    "그룹 없음",
                    systemImage: "person.2",
                    description: Text("우측 상단 + 버튼으로 그룹을 추가하세요.")
                )
            } else {
                List {
                    ForEach(groups) { group in
                        HStack {
                            Text(group.name)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                editTarget = group
                                nameInput = group.name
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .tint(.accentColor)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteTarget = group
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("그룹 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    nameInput = ""
                    showAddDialog = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await reload() }
        // 추가
        .alert("그룹 추가", isPresented: $showAddDialog) {
            TextField("그룹 이름", text: $nameInput)
            Button("저장") { Task { await saveGroup(name: nameInput) } }
            Button("취소", role: .cancel) {}
        }
        // 편집
        .alert("그룹 편집", isPresented: Binding(
            get: { editTarget != nil },
            set: { if !$0 { editTarget = nil } }
        )) {
            TextField("그룹 이름", text: $nameInput)
            Button("저장") {
                let id = editTarget?.id
                Task { await saveGroup(name: nameInput, existingId: id) }
            }
            Button("취소", role: .cancel) { editTarget = nil }
        }
        // 삭제 확인
        .alert("그룹 삭제", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("삭제", role: .destructive) {
                if let id = deleteTarget?.id {
                    Task { await deleteGroup(id: id) }
                }
            }
            Button("취소", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("\"\(deleteTarget?.name ?? "")\" 그룹을 삭제하시겠습니까?\n해당 그룹에 속한 동료들의 그룹 정보도 삭제됩니다.")
        }
    }

    private func reload() async {
        groups = await repo.allGroups()
        isLoading = false
    }

    private func saveGroup(name: String, existingId: UUID? = nil) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        await repo.upsertGroup(id: existingId, name: trimmed)
        editTarget = nil
        await reload()
    }

    private func deleteGroup(id: UUID) async {
        await repo.deleteGroup(id: id)
        deleteTarget = nil
        await reload()
    }
}
