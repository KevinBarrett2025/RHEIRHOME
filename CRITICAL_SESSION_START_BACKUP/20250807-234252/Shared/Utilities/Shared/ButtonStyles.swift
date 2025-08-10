// Views/Shared/ButtonStyles.swift
import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
  var background: Color = .blue
  var isDisabled: Bool = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(maxWidth: .infinity).padding()
      .background(isDisabled ? Color.gray : background)
      .foregroundColor(.white)
      .cornerRadius(8)
      .opacity(configuration.isPressed ? 0.8 : 1)
  }
}

struct DestructiveButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(maxWidth: .infinity).padding()
      .background(Color.red)
      .foregroundColor(.white)
      .cornerRadius(8)
      .opacity(configuration.isPressed ? 0.8 : 1)
  }
}
