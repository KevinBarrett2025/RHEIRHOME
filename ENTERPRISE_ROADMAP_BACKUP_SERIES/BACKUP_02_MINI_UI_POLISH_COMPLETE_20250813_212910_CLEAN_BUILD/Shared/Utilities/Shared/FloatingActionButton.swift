// FloatingActionButton.swift
import SwiftUI

struct FloatingActionButton<Content: View>: View {
    let action: () -> Void
    let content: Content

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .padding()
                .background(Circle().fill(Color.accentColor))
                .shadow(radius: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
