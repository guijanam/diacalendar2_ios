//
//  ForceUpdateView.swift
//  DiaCalendar2
//

import SwiftUI

struct ForceUpdateView: View {
    let storeURL: String

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)

                VStack(spacing: 8) {
                    Text("업데이트 필요")
                        .font(.title.bold())

                    Text("계속 사용하려면 최신 버전으로\n업데이트해 주세요.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    guard let url = URL(string: storeURL), !storeURL.isEmpty else { return }
                    UIApplication.shared.open(url)
                } label: {
                    Label("App Store로 이동", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
            }
            .padding()
        }
    }
}
