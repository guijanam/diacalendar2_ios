//
//  LunarAnniversaryListView.swift
//  DiaCalendar2
//

import SwiftUI

struct LunarAnniversaryListView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var items: [LunarAnniversaryDTO] = []
    @State private var showNewEditor: Bool = false
    @State private var editingItem: LunarAnniversaryDTO?

    private let calendar = Calendar.current

    var body: some View {
        List {
            if items.isEmpty {
                Text("등록된 음력 기념일이 없습니다.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(items) { item in
                    Button {
                        editingItem = item
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: item.colorHex) ?? .gray)
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .foregroundStyle(.primary)
                                Text("음력 \(item.lunarMonth)월 \(item.lunarDay)일\(item.isLeapMonth ? " (윤달)" : "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let solar = solarThisYear(for: item) {
                                Text(solar, format: .dateTime.month().day())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                await appEnvironment.lunarAnniversaryRepository.delete(id: item.id)
                                await reload()
                            }
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("음력 기념일")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewEditor, onDismiss: { Task { await reload() } }) {
            LunarAnniversaryEditorSheet(
                mode: .new(lunarMonth: 1, lunarDay: 1),
                onSave: { dto in
                    Task {
                        await appEnvironment.lunarAnniversaryRepository.upsert(dto)
                        await reload()
                    }
                },
                onDelete: nil
            )
        }
        .sheet(item: $editingItem, onDismiss: { Task { await reload() } }) { item in
            LunarAnniversaryEditorSheet(
                mode: .edit(item),
                onSave: { dto in
                    Task {
                        await appEnvironment.lunarAnniversaryRepository.upsert(dto)
                        await reload()
                    }
                },
                onDelete: { id in
                    Task {
                        await appEnvironment.lunarAnniversaryRepository.delete(id: id)
                        await reload()
                    }
                }
            )
        }
        .task { await reload() }
    }

    private func reload() async {
        items = await appEnvironment.lunarAnniversaryRepository.all()
    }

    private func solarThisYear(for dto: LunarAnniversaryDTO) -> Date? {
        LunarSolarConverter.solarDate(
            lunarYear: calendar.component(.year, from: Date()),
            lunarMonth: dto.lunarMonth,
            lunarDay: dto.lunarDay,
            isLeapMonth: dto.isLeapMonth,
            calendar: calendar
        )
    }
}
