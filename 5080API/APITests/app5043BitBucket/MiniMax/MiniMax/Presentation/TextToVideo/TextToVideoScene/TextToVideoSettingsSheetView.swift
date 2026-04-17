import SwiftUI
import UIKit
import Dispatch

struct TextToVideoSettingsSheetView: View {
    @ObservedObject var viewModel: TextToVideoSceneViewModel
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0.scale
    @State private var isPresented = false

    var body: some View {
        GeometryReader { proxy in
            let sheetHeight = min(560.scale, proxy.size.height)
            let hiddenOffset = sheetHeight + 24.scale

            ZStack(alignment: .bottom) {
                Tokens.Color.modeSheetOverlay
                    .opacity(isPresented ? 1.0 : 0.0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissSheet()
                    }

                VStack(spacing: 0.scale) {
                    Capsule(style: .continuous)
                        .fill(Tokens.Color.modeSheetPill)
                        .frame(width: 40.scale, height: 5.scale)
                        .padding(.top, 8.scale)

                    Text("Video Settings")
                        .font(Tokens.Font.outfitSemibold18)
                        .foregroundStyle(Tokens.Color.inkPrimary)
                        .kerning(-0.18.scale)
                        .padding(.top, 19.scale)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0.scale) {
                            settingsSection(
                                title: "Aspect Ratio",
                                options: TextToVideoSceneViewModel.AspectRatio.allCases,
                                selected: viewModel.selectedAspectRatio,
                                onTap: {
                                    viewModel.selectedAspectRatio = $0
                                }
                            )
                            .padding(.top, 24.scale)

                            settingsSection(
                                title: "Resolution",
                                options: TextToVideoSceneViewModel.Resolution.allCases,
                                selected: viewModel.selectedResolution,
                                onTap: {
                                    viewModel.selectedResolution = $0
                                }
                            )
                            .padding(.top, 24.scale)

                            settingsSection(
                                title: "Duration",
                                options: TextToVideoSceneViewModel.Duration.allCases,
                                selected: viewModel.selectedDuration,
                                onTap: {
                                    viewModel.selectedDuration = $0
                                }
                            )
                            .padding(.top, 24.scale)

                            Spacer(minLength: 16.scale)
                        }
                        .padding(.horizontal, 16.scale)
                    }
                }
                .frame(height: sheetHeight)
                .frame(maxWidth: .infinity)
                .background(Tokens.Color.surfaceWhite)
                .clipShape(
                    TextToVideoTopRoundedCornersShape(radius: 40.scale)
                )
                .offset(y: (isPresented ? 0.scale : hiddenOffset) + dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 1.scale)
                        .onChanged { value in
                            dragOffset = max(0.scale, value.translation.height)
                        }
                        .onEnded { value in
                            if value.translation.height > 120.scale {
                                dismissSheet()
                            } else {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                    dragOffset = 0.scale
                                }
                            }
                        }
                )
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isPresented = true
                }
            }
        }
    }

    private func dismissSheet() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isPresented = false
            dragOffset = 0.scale
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss()
        }
    }

    private func settingsSection<Option: CaseIterable & Hashable & Identifiable>(
        title: String,
        options: Option.AllCases,
        selected: Option,
        onTap: @escaping (Option) -> Void
    ) -> some View where Option.AllCases.Element == Option {
        let optionItems = Array(options)
        return VStack(alignment: .leading, spacing: 12.scale) {
            Text(title)
                .font(Tokens.Font.medium17)
                .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.7))

            let columns = optionItems.count == 1
                ? [GridItem(.flexible(), spacing: 8.scale)]
                : [
                    GridItem(.flexible(), spacing: 8.scale),
                    GridItem(.flexible(), spacing: 8.scale)
                ]

            LazyVGrid(columns: columns, spacing: 8.scale) {
                ForEach(optionItems, id: \.id) { option in
                    Button {
                        onTap(option)
                    } label: {
                        Text(String(describing: option.id))
                            .font(Tokens.Font.semibold16)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 68.scale)
                            .background(Tokens.Color.cardSoftBackground)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                                    .stroke(
                                        selected == option ? Tokens.Color.accent : Color.clear,
                                        lineWidth: selected == option ? 1.5.scale : 0.scale
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct TextToVideoTopRoundedCornersShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
