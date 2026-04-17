
import Foundation
import SwiftUI

enum PaywallLayout {

    // MARK: - Close button (как в API Paywall)

    static let closeSize: CGFloat = 50.scale
    static let closeEdgeInset: CGFloat = 24

    // MARK: - Top asset (как в API Paywall)

    static let topAssetHorizontalInset: CGFloat = 44.scale
    static let topAssetGapFromClose: CGFloat = 49.scale

    // MARK: - Bottom card (точно как в твоих метриках API)

    static let cardHorizontalInset: CGFloat = 16.scale
    static let bottomCardCorner: CGFloat = 26.scale

    static let optionCorner: CGFloat = 18.scale
    static let productRowHeight: CGFloat = 65.scale
    static let productsSpacing: CGFloat = 8.scale

    static let titleTop: CGFloat = 18.scale
    static let titleToProducts: CGFloat = 16.scale
    static let productsToCancel: CGFloat = 20.scale
    static let cancelToContinue: CGFloat = 8.scale

    static let continueHeight: CGFloat = 54.scale
    static let continueToFooter: CGFloat = 4.scale

    static let bottomSafeExtra: CGFloat = 10.scale

    static let productsScrollMaxHeight: CGFloat =
        (productRowHeight * 3) + (productsSpacing * 2)
}
