import SwiftUI

struct ChatGPTSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isTestingAndSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                    
                    Button("Test & Save API Key") {
                        testAndSaveAPIKey()
                    }
                    .disabled(apiKey.isEmpty || isTestingAndSaving)
                    
                    if isTestingAndSaving {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Testing connection...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("App-Wide Configuration")
                } footer: {
                    Text("This API key is stored globally and used across all organizations and projects. Set it once and it works everywhere.")
                }
                
                Section("🤖 AI-Powered Receipt Processing") {
                    Label("Automatic categorization", systemImage: "tag.fill")
                    Label("Vendor recognition", systemImage: "building.2.fill")
                    Label("Payment method detection", systemImage: "creditcard.fill")
                    Label("Itemized breakdown with smart categorization", systemImage: "list.bullet.rectangle.portrait.fill")
                    Label("Tax and discount tracking", systemImage: "percent")
                    Label("Return detection", systemImage: "return.left")
                }
                
                Section("🏢 Global Intelligence") {
                    Label("Works across all organizations", systemImage: "building.2.fill")
                        .badge("Global")
                    Label("Project context awareness", systemImage: "location.fill")
                        .badge("Automatic")
                    Label("Smart vendor matching", systemImage: "brain.head.profile")
                        .badge("AI-powered")
                    Label("Universal receipt processing", systemImage: "doc.text.magnifyingglass")
                        .badge("App-wide")
                }
                
                Section("How to get an API Key") {
                    Text("1. Visit openai.com and create an account")
                    Text("2. Go to your API dashboard")
                    Text("3. Create a new API key")
                    Text("4. Copy and paste it above")
                    
                    Link("Get API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        .foregroundColor(.blue)
                }
                
                Section("Usage & Pricing") {
                    Text("💡 ChatGPT API charges per token used")
                    Text("📊 Receipt analysis: ~$0.01-0.05 per receipt")
                    Text("🔄 Only processes receipts when you scan them")
                    Text("💾 Your API usage is controlled by you")
                    Text("🌍 One API key serves the entire app")
                }
                
                Section("Status") {
                    if apiKey.isEmpty {
                        Label("No API key configured", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Add your OpenAI API key to enable AI-powered receipt processing across all organizations and projects.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Label("AI processing active globally", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("ChatGPT is ready to analyze receipts for all organizations and projects.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("ChatGPT Integration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadAPIKey()
            }
            .alert("ChatGPT Settings", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func testAndSaveAPIKey() {
        isTestingAndSaving = true
        
        Task {
            do {
                let response = try await testChatGPTConnection()
                
                await MainActor.run {
                    // Test successful, now save the API key
                    UserDefaults.standard.set(apiKey, forKey: "global_chatgpt_api_key")
                    
                    isTestingAndSaving = false
                    alertMessage = "✅ Connection successful and API key saved!\n\n🤖 Response: \(response)\n\n🌍 Your global AI-powered receipt processing is now active across all organizations and projects!"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    isTestingAndSaving = false
                    alertMessage = "❌ Connection failed!\n\nError: \(error.localizedDescription)\n\nAPI key was NOT saved. Please check your API key and internet connection."
                    showingAlert = true
                }
            }
        }
    }
    
    private func loadAPIKey() {
        apiKey = UserDefaults.standard.string(forKey: "global_chatgpt_api_key") ?? ""
    }
    
    private func testChatGPTConnection() async throws -> String {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "ChatGPT", code: 1, userInfo: [NSLocalizedDescriptionKey: "No API key provided"])
        }
        
        let testPrompt = "Say 'Hello from RHEIR app!' if you can see this message."
        let requestBody = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "user",
                    "content": testPrompt
                ]
            ],
            "max_tokens": 50,
            "temperature": 0.1
        ] as [String: Any]
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "ChatGPT", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("RHEIR-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatGPT", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ChatGPT", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API request failed (Status: \(httpResponse.statusCode)): \(errorBody)"])
        }
        
        let chatResponse = try JSONDecoder().decode(TestChatGPTResponse.self, from: data)
        return chatResponse.choices.first?.message.content ?? "No response"
    }
}

// MARK: - Test Response Models
private struct TestChatGPTResponse: Codable {
    let choices: [TestChatGPTChoice]
}

private struct TestChatGPTChoice: Codable {
    let message: TestChatGPTMessage
}

private struct TestChatGPTMessage: Codable {
    let content: String
}

#if DEBUG
struct ChatGPTSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatGPTSettingsView()
    }
}
#endif
