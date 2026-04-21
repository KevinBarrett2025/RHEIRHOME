import SwiftUI

struct ProjectSelectionRequiredView: View {
    let title: String
    let message: String
    var icon: String = "folder.badge.questionmark"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityIdentifier("project-selection-required-title")

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .accessibilityIdentifier("project-selection-required-message")

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("project-selection-required-action")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct WorkflowEmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    var primaryActionTitle: String?
    var primaryAction: (() -> Void)?
    var primaryActionIdentifier: String?
    var secondaryActionTitle: String?
    var secondaryAction: (() -> Void)?
    var secondaryActionIdentifier: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if primaryActionTitle != nil || secondaryActionTitle != nil {
                VStack(spacing: 10) {
                    if let primaryActionTitle, let primaryAction {
                        Button(primaryActionTitle, action: primaryAction)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier(primaryActionIdentifier ?? "workflow-empty-primary-action")
                    }

                    if let secondaryActionTitle, let secondaryAction {
                        Button(secondaryActionTitle, action: secondaryAction)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier(secondaryActionIdentifier ?? "workflow-empty-secondary-action")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

#Preview {
    ProjectSelectionRequiredView(
        title: "Select a Project",
        message: "Choose a project before working in this area."
    )
}
