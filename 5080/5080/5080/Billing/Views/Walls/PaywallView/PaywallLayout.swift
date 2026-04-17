
import Foundation
import SwiftUI

enum PaywallLayout {

    // MARK: - Close button (как в API Paywall)

    static let closeSize: CGFloat = 50.scale
    static let closeEdgeInset: CGFloat = 24.scale

    // MARK: - Top asset (как в API Paywall)

    static let topAssetHorizontalInset: CGFloat = 44.scale
    static let topAssetGapFromClose: CGFloat = 49.scale

    // MARK: - Bottom card (точно как в твоих метриках API)

    static let cardHorizontalInset: CGFloat = 24.scale
    static let bottomCardCorner: CGFloat = 26.scale

    static let optionCorner: CGFloat = 18.scale
    static let productRowHeight: CGFloat = 76.scale
    static let productsSpacing: CGFloat = 12.scale

    static let titleTop: CGFloat = 0.scale
    static let titleToProducts: CGFloat = 24.scale
    static let productsToCancel: CGFloat = 24.scale
    static let cancelToContinue: CGFloat = 14.scale

    static let continueHeight: CGFloat = 54.scale
    static let continueToFooter: CGFloat = 14.scale

    static let bottomSafeExtra: CGFloat = 32.scale

    static let productsScrollMaxHeight: CGFloat =
        (productRowHeight * 3) + (productsSpacing * 2)
}
