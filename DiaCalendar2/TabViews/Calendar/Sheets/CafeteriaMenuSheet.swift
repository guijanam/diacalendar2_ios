//
//  CafeteriaMenuSheet.swift
//  DiaCalendar2
//
//  구내식당 식단 표시. 식단은 별도 Supabase(CafeteriaAPI)에서 직접 가져오므로
//  DayDetailSheet의 viewModel 클로저 주입 없이 자체적으로 동작한다.
//  (참고: 구버전 CafeteriaMenuView)
//

import SwiftUI
import SafariServices

struct CafeteriaMenuSheet: View {
    let date: Date
    let calendar: Calendar
    @Environment(\.dismiss) private var dismiss

    @State private var dayMenu: CafeteriaDayMenu?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var cafeteriaNames: [String] = []
    @State private var selectedCafeteria: String = ""
    @State private var showUploadSheet = false

    @AppStorage("selectedCafeteriaName") private var savedCafeteriaName: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 식당 선택 드롭다운
                HStack {
                    Text("식당")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("식당 선택", selection: $selectedCafeteria) {
                        if cafeteriaNames.isEmpty {
                            Text("불러오는 중...").tag("")
                        } else {
                            ForEach(cafeteriaNames, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedCafeteria) {
                        guard !selectedCafeteria.isEmpty else { return }
                        savedCafeteriaName = selectedCafeteria
                        Task { await loadMenu() }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                content
            }
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showUploadSheet = true
                    } label: {
                        Label("메뉴 업로드", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showUploadSheet) {
                CafeteriaUploadView(url: CafeteriaConfig.uploadURL)
            }
        }
        .task {
            await loadCafeteriaNames()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            Spacer()
            ProgressView("메뉴를 불러오는 중...")
            Spacer()
        } else if let error = errorMessage {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
        } else if let menu = dayMenu {
            ScrollView {
                VStack(spacing: 16) {
                    mealSection(title: "조식", icon: "sunrise.fill", color: .orange, items: menu.breakfast)
                    mealSection(title: "중식", icon: "sun.max.fill", color: .yellow, items: menu.lunch)
                    mealSection(title: "석식", icon: "sunset.fill", color: .indigo, items: menu.dinner)
                }
                .padding()
            }
        } else {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "fork.knife")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("해당 날짜의 식단 정보가 없습니다.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var dateTitle: String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)월 \(day)일 식단"
    }

    @ViewBuilder
    private func mealSection(title: String, icon: String, color: Color, items: [String]) -> some View {
        GroupBox {
            if items.isEmpty {
                HStack {
                    Spacer()
                    Text("식단 정보 없음")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(color.opacity(0.6))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(item)
                                .font(.subheadline)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
        }
    }

    private func loadCafeteriaNames() async {
        do {
            let names = try await CafeteriaAPI.cafeteriaNames(date: date)
            await MainActor.run {
                guard !names.isEmpty else {
                    cafeteriaNames = []
                    selectedCafeteria = ""
                    dayMenu = nil
                    return
                }
                cafeteriaNames = names

                let target: String
                if !savedCafeteriaName.isEmpty, names.contains(savedCafeteriaName) {
                    target = savedCafeteriaName
                } else {
                    target = names[0]
                    savedCafeteriaName = names[0]
                }

                if selectedCafeteria == target {
                    // 값이 동일하면 onChange가 발생하지 않으므로 직접 호출.
                    Task { await loadMenu() }
                } else {
                    selectedCafeteria = target // onChange → loadMenu() 자동 호출
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "식당 목록을 불러올 수 없습니다."
            }
        }
    }

    private func loadMenu() async {
        guard !selectedCafeteria.isEmpty else { return }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
            dayMenu = nil
        }

        do {
            let menu = try await CafeteriaAPI.menu(cafeteriaName: selectedCafeteria, date: date)
            await MainActor.run {
                dayMenu = menu
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "메뉴를 불러올 수 없습니다."
            }
        }
    }
}

/// 메뉴 업로드(분석) 외부 페이지를 SFSafariViewController로 표시.
struct CafeteriaUploadView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
