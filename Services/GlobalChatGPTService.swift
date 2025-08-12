import Foundation

/// Global ChatGPT service that works across all organizations and projects
actor GlobalChatGPTService {
    static let shared = GlobalChatGPTService()
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-3.5-turbo"
    
    private init() {}
    
    /// Gets the globally stored API key
    private func getAPIKey() -> String? {
        return UserDefaults.standard.string(forKey: "global_chatgpt_api_key")
    }
    
    /// Tests the API connection
    func testConnection() async throws -> String {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            throw GlobalChatGPTError.noAPIKey
        }
        
        let testPrompt = "Say 'Hello from RHEIR app!' if you can see this message."
        let response = try await makeAPIRequest(prompt: testPrompt, apiKey: apiKey)
        return response.choices.first?.message.content ?? "No response"
    }
    
    /// Analyzes receipt text with project context
    func analyzeReceipt(ocrText: String, projectName: String?) async throws -> GlobalReceiptAnalysis {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            throw GlobalChatGPTError.noAPIKey
        }
        
        guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GlobalChatGPTError.emptyText
        }
        
        let prompt = createReceiptAnalysisPrompt(ocrText: ocrText, projectName: projectName)
        let response = try await makeAPIRequest(prompt: prompt, apiKey: apiKey)
        
        guard let content = response.choices.first?.message.content else {
            throw GlobalChatGPTError.noContent
        }
        
        return try parseReceiptAnalysis(content)
    }
    
    // MARK: - Private Methods
    
    private func makeAPIRequest(prompt: String, apiKey: String) async throws -> GlobalChatGPTResponse {
        let requestBody = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 1500,
            "temperature": 0.1
        ] as [String: Any]
        
        guard let url = URL(string: baseURL) else {
            throw GlobalChatGPTError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("RHEIR-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalChatGPTError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GlobalChatGPTError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        return try JSONDecoder().decode(GlobalChatGPTResponse.self, from: data)
    }
    
    private func createReceiptAnalysisPrompt(ocrText: String, projectName: String?) -> String {
        let contextInfo = projectName.map { "Project: \($0)" } ?? "No specific project context"
        
        return """
        Analyze this receipt OCR text and return ONLY a valid JSON object with the following structure:
        {
            "vendor": "string - business name",
            "category": "Materials|General Conditions|Contingency|Other",
            "amount": number - total amount,
            "taxAmount": number - tax amount (0 if not found),
            "discountAmount": number - discount amount (0 if not found),
            "paymentMethod": "Credit Card|Debit Card|Cash|Check|Bank Transfer|Other",
            "receiptNumber": "string - receipt/transaction number",
            "items": [
                {
                    "name": "string - item name",
                    "quantity": number,
                    "unitPrice": number,
                    "totalPrice": number,
                    "category": "Materials|General Conditions|Contingency|Other"
                }
            ],
            "isReturn": boolean,
            "confidence": number - confidence score 0.0 to 1.0
        }

        Context: \(contextInfo)

        Guidelines:
        - Materials: lumber, nails, screws, paint, tools, hardware, building supplies
        - General Conditions: permits, insurance, utilities, office supplies, fuel
        - Contingency: unexpected items, misc supplies
        - Other: food, personal items, non-construction related
        - Extract as many individual items as possible
        - Be conservative with confidence scores

        Receipt text:
        \(ocrText)
        """
    }
    
    private func parseReceiptAnalysis(_ content: String) throws -> GlobalReceiptAnalysis {
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanContent.data(using: .utf8) else {
            throw GlobalChatGPTError.invalidJSON
        }
        
        do {
            return try JSONDecoder().decode(GlobalReceiptAnalysis.self, from: data)
        } catch {
            print("❌ JSON Parsing Error: \(error)")
            print("📄 Raw Content: \(cleanContent)")
            throw GlobalChatGPTError.invalidJSON
        }
    }
}

// MARK: - Data Models

public struct GlobalChatGPTResponse: Codable {
    public let choices: [GlobalChatGPTChoice]
}

public struct GlobalChatGPTChoice: Codable {
    public let message: GlobalChatGPTMessage
}

public struct GlobalChatGPTMessage: Codable {
    public let content: String
}

public struct GlobalReceiptAnalysis: Codable {
    public let vendor: String
    public let category: String
    public let amount: Double
    public let taxAmount: Double
    public let discountAmount: Double
    public let paymentMethod: String
    public let paymentMethodDetails: GlobalPaymentMethodDetails?
    public let receiptNumber: String
    public let receiptDate: String? // Raw date string from AI
    public let items: [GlobalReceiptItem]
    public let isReturn: Bool
    public let confidence: Double
    
    public init(
        vendor: String,
        category: String,
        amount: Double,
        taxAmount: Double,
        discountAmount: Double,
        paymentMethod: String,
        paymentMethodDetails: GlobalPaymentMethodDetails? = nil,
        receiptNumber: String,
        receiptDate: String? = nil,
        items: [GlobalReceiptItem],
        isReturn: Bool,
        confidence: Double
    ) {
        self.vendor = vendor
        self.category = category
        self.amount = amount
        self.taxAmount = taxAmount
        self.discountAmount = discountAmount
        self.paymentMethod = paymentMethod
        self.paymentMethodDetails = paymentMethodDetails
        self.receiptNumber = receiptNumber
        self.receiptDate = receiptDate
        self.items = items
        self.isReturn = isReturn
        self.confidence = confidence
    }
}

public struct GlobalPaymentMethodDetails: Codable {
    public let cardBrand: String?
    public let lastFourDigits: String?
    public let accountInfo: String?
    
    public init(cardBrand: String?, lastFourDigits: String?, accountInfo: String?) {
        self.cardBrand = cardBrand
        self.lastFourDigits = lastFourDigits
        self.accountInfo = accountInfo
    }
}

public struct GlobalReceiptItem: Codable {
    public let name: String
    public let quantity: Double
    public let unitPrice: Double
    public let totalPrice: Double
    public let category: String
    
    public init(
        name: String,
        quantity: Double,
        unitPrice: Double,
        totalPrice: Double,
        category: String
    ) {
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.category = category
    }
}

// MARK: - Errors

enum GlobalChatGPTError: LocalizedError {
    case noAPIKey
    case emptyText
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case noContent
    case invalidJSON
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No ChatGPT API key found. Please add your OpenAI API key in Settings."
        case .emptyText:
            return "Receipt text is empty. Please scan a receipt with readable text."
        case .invalidURL:
            return "Invalid ChatGPT API URL."
        case .invalidResponse:
            return "Invalid response from ChatGPT API."
        case .httpError(let statusCode, let message):
            return "ChatGPT API error (\(statusCode)): \(message)"
        case .noContent:
            return "No content received from ChatGPT API."
        case .invalidJSON:
            return "Invalid JSON response from ChatGPT API."
        }
    }
}