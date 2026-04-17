


import SwiftUI
import UIKit

enum TabBarIconFactory {

    static func tabIcon(
        _ assetName: String,
        size: CGSize = CGSize(width: 26.scale, height: 26.scale)
    ) -> Image {

        guard let src = UIImage(named: assetName) else {
            return Image(systemName: "square")
        }

        let tinted = src.withTintColor(.black, renderingMode: .alwaysOriginal)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = UIScreen.main.scale

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let img = renderer.image { _ in
            UIColor.clear.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            tinted.draw(in: CGRect(origin: .zero, size: size))
        }
        .withRenderingMode(.alwaysTemplate)

        return Image(uiImage: img)
    }
}
