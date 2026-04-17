
import SwiftUI

struct PaywallPlanOptionsView: View {

    let purchaseState: PurchaseManager.PurchaseState
    let products: [BillingProduct]
    let sortedProductsForUI: [BillingProduct]

    @Binding var pickedProd: BillingProduct?

    let isLoading: Bool
    let onPick: (BillingProduct) -> Void

    let planTitle: (BillingProduct) -> String
    let planSubtitle: (BillingProduct) -> String
    let planPriceText: (BillingProduct) -> String
    let planSecondaryPriceText: (BillingProduct) -> String?

    var body: some View {
        VStack(spacing: PaywallLayout.productsSpacing) {
            if purchaseState == .loading || products.isEmpty {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.gray)
                    .scaleEffect(1.2)
                    .padding(.vertical, 24.scale)
            } else {
                ForEach(sortedProductsForUI, id: \.id) { product in
                    Button {
                        onPick(product)
                    } label: {
                        PaywallPlanRowView(
                            product: product,
                            isPicked: pickedProd?.id == product.id,
                            planTitle: planTitle(product),
                            planSubtitle: planSubtitle(product),
                            planPriceText: planPriceText(product),
                            planSecondaryPriceText: planSecondaryPriceText(product)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
