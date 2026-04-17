import SwiftUI

struct SettingsButton: View {
    var icn:    String
    var title:  String
    var showChevron: Bool = true
    var onAction: () -> Void
    
    var body: some View {
        Button {
            onAction()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icn)
                    .foregroundStyle(Color.white)
                    .frame(width: 28, height: 22)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 11)
                }
            }
            .frame(height: 44)
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }
}
