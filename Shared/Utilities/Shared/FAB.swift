import SwiftUI

struct FAB: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

struct FAB_Previews: PreviewProvider {
    static var previews: some View {
        FAB(icon: "plus") { }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
