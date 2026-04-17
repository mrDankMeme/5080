import SwiftUI
import UIKit

struct RootHomeModeSheetOverlayView: View {
    @ObservedObject var viewModel: RootHomeSceneViewModel
    let isVisible: Bool
    let dragOffset: CGFloat
    let onDismiss: () -> Void
    let onSelectMode: (RootHomeModeOption) -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void

    var body: some View {
        RootModePickerOverlayView(
            sheetTitle: "Select Mode",
            modeSections: viewModel.modeSections,
            selectedModeID: nil,
            isVisible: isVisible,
            dragOffset: dragOffset,
            onDismiss: onDismiss,
            onSelectMode: onSelectMode,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        )
    }
}

struct RootModePickerOverlayView: View {
    let sheetTitle: String
    let modeSections: [RootHomeModeSection]
    let selectedModeID: String?
    let isVisible: Bool
    let dragOffset: CGFloat
    let onDismiss: () -> Void
    let onSelectMode: (RootHomeModeOption) -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void

    var body: some View {
        GeometryReader { proxy in
            let sheetHeight = min(637.scale, proxy.size.height)
            let hiddenOffset = sheetHeight + 24.scale

            ZStack(alignment: .bottom) {
                Tokens.Color.modeSheetOverlay
                    .opacity(isVisible ? 1.0 : 0.0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)

                RootModePickerSheetView(
                    sheetTitle: sheetTitle,
                    modeSections: modeSections,
                    selectedModeID: selectedModeID,
                    onSelectMode: onSelectMode,
                    onDragChanged: onDragChanged,
                    onDragEnded: onDragEnded
                )
                .frame(height: sheetHeight)
                .offset(y: (isVisible ? 0.scale : hiddenOffset) + dragOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

private struct RootModePickerSheetView: View {
    let sheetTitle: String
    let modeSections: [RootHomeModeSection]
    let selectedModeID: String?
    let onSelectMode: (RootHomeModeOption) -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void

    var body: some View {
        VStack(spacing: 0.scale) {
            Capsule(style: .continuous)
                .fill(Tokens.Color.modeSheetPill)
                .frame(width: 40.scale, height: 5.scale)
                .padding(.top, 8.scale)

            Text(sheetTitle)
                .font(Tokens.Font.outfitSemibold18)
                .foregroundStyle(Tokens.Color.inkPrimary)
                .kerning(-0.18.scale)
                .padding(.top, 19.scale)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0.scale) {
                    ForEach(Array(modeSections.enumerated()), id: \.element.id) { index, section in
                        Text(section.title)
                            .font(Tokens.Font.medium14)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .kerning(-0.14.scale)
                            .padding(.top, index == 0 ? 24.scale : 24.scale)

                        if let primaryOption = section.primaryOption {
                            RootModePickerOptionCardView(
                                option: primaryOption,
                                isSelected: primaryOption.id == selectedModeID,
                                onTap: {
                                    onSelectMode(primaryOption)
                                }
                            )
                            .padding(.top, 12.scale)
                        }

                        let optionRows = secondaryOptionRows(for: section.secondaryOptions)
                        ForEach(Array(optionRows.enumerated()), id: \.offset) { rowIndex, row in
                            HStack(spacing: 8.scale) {
                                ForEach(row) { option in
                                    RootModePickerOptionCardView(
                                        option: option,
                                        isSelected: option.id == selectedModeID,
                                        onTap: {
                                            onSelectMode(option)
                                        }
                                    )
                                    .frame(maxWidth: .infinity)
                                }

                                if row.count == 1 {
                                    Spacer(minLength: 0.scale)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(
                                .top,
                                rowTopPadding(
                                    rowIndex: rowIndex,
                                    hasPrimaryOption: section.primaryOption != nil
                                )
                            )
                        }
                    }

                    Spacer(minLength: 16.scale)
                }
                .padding(.horizontal, 16.scale)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Tokens.Color.surfaceWhite)
        .clipShape(
            RootTopRoundedCornersShape(radius: 40.scale)
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1.scale, coordinateSpace: .global)
                .onChanged { value in
                    onDragChanged(max(0.scale, value.translation.height))
                }
                .onEnded { value in
                    onDragEnded(value.translation.height)
                }
        )
    }

    private func secondaryOptionRows(for options: [RootHomeModeOption]) -> [[RootHomeModeOption]] {
        var rows: [[RootHomeModeOption]] = []
        var currentIndex = 0

        while currentIndex < options.count {
            let endIndex = min(currentIndex + 2, options.count)
            rows.append(Array(options[currentIndex..<endIndex]))
            currentIndex += 2
        }

        return rows
    }

    private func rowTopPadding(rowIndex: Int, hasPrimaryOption: Bool) -> CGFloat {
        if rowIndex > 0 {
            return 8.scale
        }
        return hasPrimaryOption ? 8.scale : 12.scale
    }
}

private struct RootModePickerOptionCardView: View {
    let option: RootHomeModeOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12.scale) {
                RootModePickerOptionIconView(assetName: option.iconAssetName)
                    .frame(width: 32.scale, height: 32.scale)

                Text(option.title)
                    .font(Tokens.Font.semibold16)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .kerning(-0.16.scale)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 96.scale)
            .background(
                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                    .fill(Tokens.Color.modeSheetCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                    .stroke(
                        isSelected ? Tokens.Color.accent : Color.clear,
                        lineWidth: isSelected ? 1.5.scale : 0.scale
                    )
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(option.title)
        .accessibilityHint("Select mode")
    }
}

private struct RootModePickerOptionIconView: View {
    let assetName: String

    var body: some View {
        Group {
            if let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "sparkles")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22.scale, height: 22.scale)
            }
        }
        .foregroundStyle(Tokens.Color.accent)
    }
}

private struct RootTopRoundedCornersShape: Shape {
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
