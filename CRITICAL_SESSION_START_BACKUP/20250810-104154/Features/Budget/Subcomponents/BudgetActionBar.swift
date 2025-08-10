// BudgetActionBar.swift
import SwiftUI

struct BudgetActionBar: View {
    let onEdit: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onEdit) {
                Text("Edit Project Details")
                    .font(.subheadline.bold())
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue))
            }

            Button(action: onClose) {
                Text("Close-out")
                    .font(.subheadline.bold())
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red))
            }
        }
        .padding()
    }
}
