//
//  CustomShiftListView.swift
//  DiaCalendar2
//

import SwiftUI

struct CustomShiftListView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var items: [CustomShiftDTO] = []
    @State private var editing: CustomShiftDTO?
    @State private var showEditor = false

    var body: some View {
        List {
            if items.isEmpty {
                Text("등록된 교대근무가 없습니다.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(items) { item in
                    Button {
                        editing = item
                        showEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.shiftName).font(.headline)
                            Text(item.shiftPattern.joined(separator: " → "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    let toDelete = offsets.map { items[$0] }
                    Task {
                        for d in toDelete {
                            await env.customShiftRepository.delete(id: d.id)
                        }
                        await reload()
                    }
                }
            }
        }
        .navigationTitle("교대근무 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editing = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                CustomShiftEditView(initial: editing) { name, pattern in
                    let id = editing?.id
                    Task {
                        _ = await env.customShiftRepository.upsert(id: id, shiftName: name, shiftPattern: pattern)
                        await reload()
                    }
                }
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        items = await env.customShiftRepository.all()
    }
}

struct CustomShiftEditView: View {
    @Environment(\.dismiss) private var dismiss
    let initial: CustomShiftDTO?
    let onSave: (_ name: String, _ pattern: [String]) -> Void

    @State private var name: String = ""
    @State private var patternText: String = ""

    var pattern: [String] {
        patternText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        Form {
            Section("이름") {
                TextField("예: 4조2교대", text: $name)
            }
            Section("패턴 (쉼표로 구분)") {
                TextField("예: 주,야,비,휴", text: $patternText, axis: .vertical)
                    .lineLimit(2...4)
                if !pattern.isEmpty {
                    Text(pattern.joined(separator: " → "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(initial == nil ? "새 교대근무" : "교대근무 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") {
                    onSave(name.trimmingCharacters(in: .whitespaces), pattern)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || pattern.isEmpty)
            }
        }
        .onAppear {
            if let initial {
                name = initial.shiftName
                patternText = initial.shiftPattern.joined(separator: ", ")
            }
        }
    }
}
