import SwiftUI

struct CommunicationLogsView: View {
    let communications: [Communication]
    let onSend: (String) -> Void
    @State private var newMessage: String = ""

    var body: some View {
        VStack {
            List(communications) { entry in
                VStack(alignment: .leading) {
                    Text(entry.subject)
                        .font(.headline)
                    Text(entry.content)
                        .font(.body)
                    Text(entry.date, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            HStack {
                TextField("New message", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button {
                    onSend(newMessage)
                    newMessage = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle("Communications")
    }
}

#if DEBUG
struct CommunicationLogsView_Previews: PreviewProvider {
    static var sampleCommunications: [Communication] {
        [
            Communication(
                type: .email,
                subject: "Update Request",
                content: "Hi, please update the specs."
            ),
            Communication(
                type: .email,
                subject: "Re: Update Request", 
                content: "Sure, will do by EOD."
            )
        ]
    }
    static var previews: some View {
        NavigationStack {
            CommunicationLogsView(
                communications: sampleCommunications,
                onSend: { print("Sent:", $0) }
            )
        }
        .previewDevice("iPhone 14")
        .previewDisplayName("Communications Log")
    }
}
#endif