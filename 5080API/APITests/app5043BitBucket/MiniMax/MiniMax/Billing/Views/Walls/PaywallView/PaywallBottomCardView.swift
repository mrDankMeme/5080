
import SwiftUI

struct PaywallBottomCardView: View {

    let titleText: String
    let cancelText: String
    let continueText: String

    let footerTerms: String
    let footerRestore: String
    let footerPrivacy: String

    let termsURL: URL?
    let privacyURL: URL?
    let openURL: OpenURLAction

    let products: [BillingProduct]
    let sortedProductsForUI: [BillingProduct]

    let purchaseState: PurchaseManager.PurchaseState
    let isReady: Bool
    let isLoading: Bool

    @Binding var pickedProd: BillingProduct?

    let onPick: (BillingProduct) -> Void
    let onRestore: () -> Void
    let onContinue: (BillingProduct) -> Void

    let planTitle: (BillingProduct) -> String
    let planSubtitle: (BillingProduct) -> String
    let planPriceText: (BillingProduct) -> String
    let planSecondaryPriceText: (BillingProduct) -> String?

    let bottomSafeInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {

            Text(titleText)
                .font(Tokens.Font.bold22)
                .foregroundStyle(Color.white)
                .padding(.top, PaywallLayout.titleTop)

            productsBlock
                .padding(.top, PaywallLayout.titleToProducts)

            Text(cancelText)
                .font(.system(size: 16.scale, weight: .regular))
                .foregroundStyle(Color.gray.opacity(0.8))
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


            PaywallFooterLinksView(
                termsTitle: footerTerms,
                restoreTitle: footerRestore,
                privacyTitle: footerPrivacy,
                termsURL: termsURL,
                privacyURL: privacyURL,
                openURL: openURL,
                onRestore: onRestore
            )
            .padding(.top, PaywallLayout.continueToFooter)


            Spacer()
                .frame(
                    height: DeviceLayout.isSmallStatusBarPhone || DeviceLayout.isUnknown
                        ? bottomSafeInset + PaywallLayout.bottomSafeExtra
                        : 40.scale
                )
        }
        .padding(.horizontal, PaywallLayout.cardHorizontalInset)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PaywallLayout.bottomCardCorner, style: .continuous)
                .fill(Color(hex: "#101623")!)
        )
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
                planSecondaryPriceText: planSecondaryPriceText
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
                    planSecondaryPriceText: planSecondaryPriceText
                )
            }
            .frame(maxHeight: PaywallLayout.productsScrollMaxHeight)
        }
    }
}
