
import SwiftUI

struct PaywallBottomCardView: View {

    let titleText: String
    let cancelText: String
    let continueText: String

    let footerTerms: String
    let footerRestore: String
    let footerPrivacy: String

    let products: [BillingProduct]
    let sortedProductsForUI: [BillingProduct]

    let purchaseState: PurchaseManager.PurchaseState
    let isReady: Bool
    let isLoading: Bool

    @Binding var pickedProd: BillingProduct?

    let onPick: (BillingProduct) -> Void
    let onOpenTerms: () -> Void
    let onRestore: () -> Void
    let onOpenPrivacy: () -> Void
    let onContinue: (BillingProduct) -> Void

    let planTitle: (BillingProduct) -> String
    let planSubtitle: (BillingProduct) -> String
    let planPriceText: (BillingProduct) -> String
    let planBadgeText: (BillingProduct) -> String?

    let bottomSafeInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Text(titleText)
                .font(Tokens.Font.paywallTitle20)
                .foregroundStyle(Tokens.Color.paywallPrimaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2.scale)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, PaywallLayout.cardHorizontalInset)

            productsBlock
                .padding(.top, PaywallLayout.titleToProducts)
                .padding(.horizontal, PaywallLayout.cardHorizontalInset)

            HStack(spacing: 6.scale) {
                Image(systemName: "arrow.clockwise")
                    .font(Tokens.Font.regular14)
                Text(cancelText)
                    .font(Tokens.Font.regular14)
            }
            .foregroundStyle(Tokens.Color.paywallTertiaryText)
                .padding(.top, PaywallLayout.productsToCancel)

            PaywallContinueButton(
                title: continueText,
                isEnabled: pickedProd != nil && isReady && !isLoading,
                onTap: {
                    guard let pickedProd else { return }
                    onContinue(pickedProd)
                }
            )
            .padding(.top, PaywallLayout.cancelToContinue)
            .padding(.horizontal, PaywallLayout.cardHorizontalInset)


            PaywallFooterLinksView(
                termsTitle: footerTerms,
                restoreTitle: footerRestore,
                privacyTitle: footerPrivacy,
                onTerms: onOpenTerms,
                onRestore: onRestore,
                onPrivacy: onOpenPrivacy
            )
            .padding(.top, PaywallLayout.continueToFooter)

        }
        .padding(
            .bottom,
            max(PaywallLayout.bottomSafeExtra, bottomSafeInset)
        )
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }

    @ViewBuilder
    private var productsBlock: some View {
        if sortedProductsForUI.count <= 3 {
            PaywallPlanOptionsView(
                purchaseState: purchaseState,
                products: products,
                sortedProductsForUI: sortedProductsForUI,
                pickedProd: $pickedProd,
                isLoading: isLoading,
                onPick: onPick,
                planTitle: planTitle,
                planSubtitle: planSubtitle,
                planPriceText: planPriceText,
                planBadgeText: planBadgeText
            )
        } else {
            ScrollView(showsIndicators: false) {
                PaywallPlanOptionsView(
                    purchaseState: purchaseState,
                    products: products,
                    sortedProductsForUI: sortedProductsForUI,
                    pickedProd: $pickedProd,
                    isLoading: isLoading,
                    onPick: onPick,
                    planTitle: planTitle,
                    planSubtitle: planSubtitle,
                    planPriceText: planPriceText,
                    planBadgeText: planBadgeText
                )
            }
            .frame(maxHeight: PaywallLayout.productsScrollMaxHeight)
        }
    }
}
