//
//  CustomPaywallView.swift
//  DiaCalendar2
//

import RevenueCat
import SwiftUI

@MainActor
struct CustomPaywallView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var package: Package? = nil
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String? = nil

    private let benefits: [(icon: String, text: String)] = [
        //("checkmark.circle.fill", "근태 편집 무제한"),
        ("checkmark.circle.fill", "추후 추가될 모든 프리미엄 기능"),
        //("checkmark.circle.fill", "광고 없는 깔끔한 환경"),
        ("cup.and.saucer.fill",   "개발자에게 커피 한 잔 ☕"),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 56)
                        .padding(.horizontal, 28)

                    quoteSection
                        .padding(.top, 24)
                        .padding(.horizontal, 28)

                    benefitsSection
                        .padding(.top, 32)
                        .padding(.horizontal, 28)

                    ctaSection
                        .padding(.top, 36)
                        .padding(.horizontal, 24)

                    footerSection
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                        .padding(.horizontal, 24)
                }
            }

            dismissButton
        }
        .task { await loadOffering() }
    }

    // MARK: - Subviews

    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
        .padding(.trailing, 20)
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            Text("☕")
                .font(.system(size: 56))

            Text("커피 한 잔 값으로\n더 편리한 근무 관리를")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    private var quoteSection: some View {
        Text("\"꾸준한 업데이트와 유지보수를 위해\n개발자에게 커피한잔을 선물해보세요.\n작은 응원이 큰 힘이 됩니다.\"")
            .font(.subheadline.italic())
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.secondary.opacity(0.08))
            )
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(benefits, id: \.text) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .foregroundStyle(Color.accentColor)
                        .font(.body.weight(.semibold))
                        .frame(width: 22)
                    Text(item.text)
                        .font(.body)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ctaSection: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await purchase() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(ctaLabel)
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
            }
            .disabled(isPurchasing || package == nil)
        }
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await restore() }
            } label: {
                if isRestoring {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("구매 복원하기")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(isRestoring)

            Text("구독은 언제든지 취소할 수 있습니다.\n결제는 Apple을 통해 처리됩니다.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            HStack(spacing: 16) {
                Link("이용약관", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("개인정보처리방침", destination: URL(string: "https://sonbum.blogspot.com/2025/09/diacalendar.html")!)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var ctaLabel: String {
        guard let pkg = package else { return "불러오는 중..." }
        let price = pkg.storeProduct.localizedPriceString
        return "월 \(price) 으로 시작하기"
    }

    // MARK: - Actions

    private func loadOffering() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            package = offerings.current?.monthly
        } catch {
            errorMessage = "상품 정보를 불러오지 못했습니다."
        }
    }

    private func purchase() async {
        guard let pkg = package else { return }
        isPurchasing = true
        errorMessage = nil
        appEnvironment.revenueCatService.isPurchaseInProgress = true
        defer {
            isPurchasing = false
            appEnvironment.revenueCatService.isPurchaseInProgress = false
        }
        do {
            let result = try await Purchases.shared.purchase(package: pkg)
            if !result.userCancelled {
                appEnvironment.revenueCatService.updateSubscription(from: result.customerInfo)
                dismiss()
            }
        } catch {
            errorMessage = "결제 중 오류가 발생했습니다. 다시 시도해주세요."
        }
    }

    private func restore() async {
        isRestoring = true
        errorMessage = nil
        appEnvironment.revenueCatService.isPurchaseInProgress = true
        defer {
            isRestoring = false
            appEnvironment.revenueCatService.isPurchaseInProgress = false
        }
        await appEnvironment.revenueCatService.restore()
        if appEnvironment.revenueCatService.isSubscribed {
            dismiss()
        } else if let err = appEnvironment.revenueCatService.restoreError {
            errorMessage = err
        } else {
            errorMessage = "복원할 구독 내역이 없습니다."
        }
    }
}
