import SwiftUI

struct PromptView: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            VStack {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.white.opacity(0.4))
                        .font(.body)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                }
                        
                Spacer()
            }
                    
            VStack {
                TextEditor(text: $text)
                    .foregroundColor(.white)
                    .font(.body)
                    .tint(.white)
                    .scrollContentBackground(.hidden)
                        
                Spacer()
            }
        }
    }
}
