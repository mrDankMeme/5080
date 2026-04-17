

import SwiftUI
import UIKit

final class TabBarStyler {

    // MARK: - Public

    func configureTabAppearance() {
        let activeColor = UIColor(Tokens.Color.accent)
        let inactiveColor = UIColor(Color.black.opacity(0.3))

        let tabBarProxy = UITabBar.appearance()
        tabBarProxy.isTranslucent = true
        tabBarProxy.backgroundImage = UIImage()
        tabBarProxy.shadowImage = UIImage()
        tabBarProxy.backgroundColor = .clear
        tabBarProxy.tintColor = activeColor
        tabBarProxy.unselectedItemTintColor = inactiveColor

        let titleFont = UIFont(name: "SFProText-Medium", size: 12.scale)
            ?? .systemFont(ofSize: 12.scale, weight: .medium)

        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: inactiveColor
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: activeColor
        ]

        UITabBarItem.appearance().setTitleTextAttributes(normalAttrs, for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(selectedAttrs, for: .selected)

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear

            appearance.stackedLayoutAppearance.normal.iconColor = inactiveColor
            appearance.stackedLayoutAppearance.selected.iconColor = activeColor
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs

            tabBarProxy.standardAppearance = appearance
            tabBarProxy.scrollEdgeAppearance = appearance
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.applyFlatBackgroundToRealTabBar()
        }
        applyFlatBackgroundToRealTabBar()
    }

    func applyFlatBackgroundToRealTabBar(retryCount: Int = 4) {
        let delay: TimeInterval = (retryCount == 4) ? 0 : 0.05

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard
                let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first,
                let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                let root = window.rootViewController,
                let tbc = self.findTabBarController(from: root)
            else {
                if retryCount > 0 {
                    self.applyFlatBackgroundToRealTabBar(retryCount: retryCount - 1)
                }
                return
            }

            let tabBar = tbc.tabBar

            if tabBar.bounds.height == 0, retryCount > 0 {
                self.applyFlatBackgroundToRealTabBar(retryCount: retryCount - 1)
                return
            }

            let bgTag = 777_001
            let lineTag = 777_002

            
            let backgroundView: UIView
            if let existing = tabBar.viewWithTag(bgTag) {
                backgroundView = existing
            } else {
                let view = UIView(frame: tabBar.bounds)
                view.tag = bgTag
                view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                tabBar.insertSubview(view, at: 0)
                backgroundView = view
            }

            backgroundView.frame = tabBar.bounds
            backgroundView.backgroundColor = UIColor(Tokens.Color.componentsBackground)

            let separatorColor = UIColor.black.withAlphaComponent(0.12)

            let lineView: UIView
            if let existing = backgroundView.viewWithTag(lineTag) {
                lineView = existing
            } else {
                let v = UIView(frame: .zero)
                v.tag = lineTag
                v.translatesAutoresizingMaskIntoConstraints = false
                backgroundView.addSubview(v)

                NSLayoutConstraint.activate([
                    v.topAnchor.constraint(equalTo: backgroundView.topAnchor),
                    v.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
                    v.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
                    v.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale)
                ])

                lineView = v
            }

            lineView.backgroundColor = separatorColor

            tabBar.clipsToBounds = false
            tabBar.layer.masksToBounds = false
        }
    }

    // MARK: - Private

    private func findTabBarController(from root: UIViewController?) -> UITabBarController? {
        guard let root = root else { return nil }

        if let tbc = root as? UITabBarController {
            return tbc
        }

        for child in root.children {
            if let tbc = findTabBarController(from: child) {
                return tbc
            }
        }

        if let presented = root.presentedViewController {
            if let tbc = findTabBarController(from: presented) {
                return tbc
            }
        }

        return nil
    }
}
