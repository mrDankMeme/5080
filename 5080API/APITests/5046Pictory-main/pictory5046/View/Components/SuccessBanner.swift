import SwiftUI

struct SuccessBanner: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image("success")
            
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(Color.white)
        }
        .padding()
        .background(Color(hex: "#201A1A").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
    }
}
