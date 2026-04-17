//
//  HideKeyboard.swift
//  Claude
//
//  Created by Niiaz Khasanov on 2/5/26.
//

import SwiftUI
import UIKit

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTapModifier())
    }
}

private struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(KeyboardDismissGestureInstaller())
    }
}

private struct KeyboardDismissGestureInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(using: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.removeGesture()
    }
}

extension KeyboardDismissGestureInstaller {
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private weak var tapGestureRecognizer: UITapGestureRecognizer?

        func installIfNeeded(using view: UIView) {
            guard let window = view.window else { return }

            if self.window === window, tapGestureRecognizer?.view === window {
                return
            }

            removeGesture()

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)

            self.window = window
            tapGestureRecognizer = recognizer
        }

        func removeGesture() {
            if let tapGestureRecognizer, let window {
                window.removeGestureRecognizer(tapGestureRecognizer)
            }

            tapGestureRecognizer = nil
            window = nil
        }

        @objc
        private func handleTap() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            !(touch.view?.isDescendantOfTextInput ?? false)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private extension UIView {
    var isDescendantOfTextInput: Bool {
        sequence(first: self, next: \.superview).contains { view in
            view is UITextField || view is UITextView
        }
    }
}
