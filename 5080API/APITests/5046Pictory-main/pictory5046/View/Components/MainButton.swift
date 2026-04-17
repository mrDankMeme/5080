import SwiftUI

struct MainButton: View {
    let title: String
    let isLargeButton: Bool
    let cost: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if let cost = self.cost {
                    Image("rhombus.fill")
                    
                    Text("\(cost)")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, isLargeButton ? 0 : 12)
            .frame(maxWidth: isLargeButton ? .infinity : nil)
            .background(RoundedRectangle(cornerRadius: 40).fill(
                LinearGradient(
                    colors: [Color(hex: "#FD9958"), Color(hex: "#E149A0"), Color(hex: "#AB4BC3"), Color(hex: "#6851EA")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 40).stroke(LinearGradient(
                    colors: [Color.white.opacity(0), Color.white, Color.white.opacity(0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ), lineWidth: 1)
            )
        }
    }
}
