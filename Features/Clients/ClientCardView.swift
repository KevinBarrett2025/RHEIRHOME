import SwiftUI
import MessageUI

struct ClientCardView: View {
    let project: Project
    @AppStorage("preferredMapProvider") private var preferredMapProvider: MapProvider = .apple
    @State private var showingMessageCompose = false
    @State private var showingMailCompose = false
    @State private var showingActionSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.client)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if !project.phone.isEmpty {
                        Button(project.phone) {
                            callPhoneNumber(project.phone)
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    if !project.email.isEmpty {
                        Button(project.email) {
                            sendEmail()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(project.status.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(project.status.color))
                    
                    Text("Due: \(project.endDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !project.street.isEmpty {
                Button {
                    openInMaps()
                } label: {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.street)
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            if !project.city.isEmpty || !project.state.isEmpty {
                                Text("\(project.city)\(!project.city.isEmpty && !project.state.isEmpty ? ", " : "")\(project.state) \(project.zip)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if !project.phone.isEmpty || !project.email.isEmpty {
                HStack(spacing: 12) {
                    if !project.phone.isEmpty {
                        Button {
                            showingActionSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "phone.fill")
                                Text("Contact")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(6)
                        }
                    }
                    
                    if !project.email.isEmpty {
                        Button {
                            sendEmail()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "envelope.fill")
                                Text("Email")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(6)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
            
            if !project.description.isEmpty {
                Text(project.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .confirmationDialog("Contact Client", isPresented: $showingActionSheet) {
            Button("Call \(project.client)") {
                callPhoneNumber(project.phone)
            }
            
            if MFMessageComposeViewController.canSendText() {
                Button("Send Message") {
                    sendMessage()
                }
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingMessageCompose) {
            MessageComposeView(recipients: [project.phone], body: "Hi \(project.client), this is regarding your project: \(project.name)")
        }
        .sheet(isPresented: $showingMailCompose) {
            MailComposeView(
                recipients: [project.email],
                subject: "Regarding your project: \(project.name)",
                body: "Hi \(project.client),\n\nI wanted to reach out about your project: \(project.name).\n\nBest regards"
            )
        }
    }
    
    private func openInMaps() {
        let address = "\(project.street), \(project.city), \(project.state) \(project.zip)"
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        switch preferredMapProvider {
        case .apple:
            if let url = URL(string: "http://maps.apple.com/?q=\(encodedAddress)") {
                UIApplication.shared.open(url)
            }
        case .google:
            if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedAddress)") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func callPhoneNumber(_ phoneNumber: String) {
        let cleanPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel://\(cleanPhone)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendMessage() {
        showingMessageCompose = true
    }
    
    private func sendEmail() {
        showingMailCompose = true
    }
}

// MARK: - Map Provider Enum
enum MapProvider: String, CaseIterable, Codable {
    case apple = "Apple Maps"
    case google = "Google Maps"
}

struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: MessageComposeView
        
        init(_ parent: MessageComposeView) {
            self.parent = parent
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            parent.dismiss()
        }
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.setToRecipients(recipients)
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        controller.mailComposeDelegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

struct ClientCardView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProject = Project(
            name: "Sample House",
            client: "John Doe",
            clientEmail: "john.doe@email.com",
            clientPhone: "(555) 123-4567",
            clientAddress: "123 Main St, Anytown, CA 12345",
            description: "This is a sample project with notes",
            totalBudget: 50000,
            materialCost: 25000,
            laborCost: 15000,
            generalConditions: 5000,
            contingency: 5000,
            startDate: Date(),
            endDate: Date(),
            organizationID: "sample-org-id"
        )
        
        ClientCardView(project: sampleProject)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}