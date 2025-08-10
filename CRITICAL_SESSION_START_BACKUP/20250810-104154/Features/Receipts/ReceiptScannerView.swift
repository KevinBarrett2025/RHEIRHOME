import SwiftUI
import VisionKit
import Vision

struct ReceiptScannerView: View {
    @Binding var isPresented: Bool
    let project: Project
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var showingDocumentScanner = false
    @State private var showingImagePicker = false
    @State private var showingAnalysisView = false
    @State private var scannedImage: UIImage?
    @State private var analysisResult: ReceiptAnalysisResult?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedImageFromPicker: UIImage?
    @State private var processingStep = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                headerSection
                
                if isProcessing {
                    processingSection
                } else {
                    scanningOptionsSection
                }
                
                Spacer()
                
                manualEntryButton
            }
            .padding()
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingDocumentScanner) {
                DocumentScannerView { result in
                    handleScanResult(result)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: .photoLibrary, image: $selectedImageFromPicker)
            }
            .sheet(isPresented: $showingAnalysisView) {
                if let analysisResult = analysisResult, let scannedImage = scannedImage {
                    ScannedReceiptEntryView(
                        isPresented: $showingAnalysisView,
                        project: project,
                        analysisResult: analysisResult,
                        scannedImage: scannedImage
                    )
                    .environmentObject(projectVM)
                }
            }
            .alert("Scanning Error", isPresented: $showingError) {
                Button("OK") { }
                Button("Try Again") {
                    showingDocumentScanner = true
                }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .onChange(of: selectedImageFromPicker) { _, newImage in
                if let image = newImage {
                    handleImageSelection(image)
                    selectedImageFromPicker = nil
                }
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("AI-Powered Receipt Scanner")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Scan receipts with automatic categorization and data extraction")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    @ViewBuilder
    private var processingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            VStack(spacing: 8) {
                Text("Processing Receipt...")
                    .font(.headline)
                
                Text(processingStep)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var scanningOptionsSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingDocumentScanner = true
            }) {
                HStack {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan with Camera")
                            .font(.headline)
                        Text("Best for clear, automatic capture")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                showingImagePicker = true
            }) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose from Photos")
                            .font(.headline)
                        Text("Select existing receipt photo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            // AI Features showcase
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("AI-Powered Features")
                        .font(.headline)
                        .foregroundColor(.purple)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    featureRow("Automatic vendor recognition", "building.2.fill")
                    featureRow("Smart categorization", "tag.fill")
                    featureRow("Payment method detection", "creditcard.fill")
                    featureRow("Itemized breakdown", "list.bullet.rectangle.portrait.fill")
                    featureRow("Tax and discount tracking", "percent")
                }
            }
            .padding()
            .background(Color.purple.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var manualEntryButton: some View {
        Button("Use Manual Entry Instead") {
            isPresented = false
        }
        .buttonStyle(.bordered)
    }
    
    @ViewBuilder
    private func featureRow(_ text: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func handleScanResult(_ result: Result<[UIImage], Error>) {
        switch result {
        case .success(let images):
            if let firstImage = images.first {
                handleImageSelection(firstImage)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func handleImageSelection(_ image: UIImage) {
        scannedImage = image
        processReceipt(image)
    }
    
    private func processReceipt(_ image: UIImage) {
        isProcessing = true
        processingStep = "🔍 Extracting text with OCR..."
        
        Task {
            do {
                guard let currentOrg = authVM.currentOrg else {
                    throw ReceiptAnalysisError.noOrganization
                }
                
                // Step 1: Extract text using OCR
                await MainActor.run {
                    processingStep = "📄 Extracting text from image..."
                }
                
                let ocrText = try await extractTextFromImage(image)
                print("📄 OCR Extracted Text:")
                print(ocrText)
                print("---")
                
                // Step 2: Try AI analysis with subscription checking
                await MainActor.run {
                    processingStep = "🤖 Analyzing with AI..."
                }
                
                var analysisResult: ReceiptAnalysisResult
                
                // Check if organization can use AI features
                if currentOrg.subscriptionTier != .free {
                    // Try production AI analysis
                    do {
                        analysisResult = try await performAIAnalysis(ocrText: ocrText, projectName: project.name)
                        print("🎉 AI analysis completed successfully!")
                    } catch {
                        print("⚠️ AI analysis failed, falling back to basic OCR: \(error)")
                        analysisResult = createBasicAnalysisFromOCR(ocrText)
                        analysisResult = ReceiptAnalysisResult(
                            vendor: analysisResult.vendor,
                            category: analysisResult.category,
                            amount: analysisResult.amount,
                            taxAmount: analysisResult.taxAmount,
                            discountAmount: analysisResult.discountAmount,
                            paymentMethod: analysisResult.paymentMethod,
                            receiptNumber: analysisResult.receiptNumber,
                            items: analysisResult.items,
                            isReturn: analysisResult.isReturn,
                            confidence: 0.5 // Lower confidence for OCR-only
                        )
                    }
                } else {
                    print("ℹ️ Free tier - using basic OCR processing")
                    analysisResult = createBasicAnalysisFromOCR(ocrText)
                }
                
                print("✅ Receipt processing completed!")
                print("Vendor: \(analysisResult.vendor)")
                print("Amount: $\(analysisResult.amount)")
                print("Category: \(analysisResult.category)")
                print("Items: \(analysisResult.items.count)")
                print("Confidence: \(analysisResult.confidence)")
                print("---")
                
                await MainActor.run {
                    isProcessing = false
                    self.analysisResult = analysisResult
                    showingAnalysisView = true
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    
                    if let receiptError = error as? ReceiptAnalysisError {
                        errorMessage = receiptError.localizedDescription
                    } else {
                        errorMessage = "Failed to process receipt: \(error.localizedDescription)"
                    }
                    
                    showingError = true
                }
                
                print("❌ Receipt processing failed: \(error)")
            }
        }
    }
    
    // MARK: - OCR Helper Methods
    
    private func extractTextFromImage(_ image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: NSError(domain: "OCR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image format"]))
                return
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: NSError(domain: "OCR", code: -2, userInfo: [NSLocalizedDescriptionKey: "No text found"]))
                    return
                }
                
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: NSError(domain: "OCR", code: -3, userInfo: [NSLocalizedDescriptionKey: "No readable text found"]))
                } else {
                    continuation.resume(returning: text)
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func createBasicAnalysisFromOCR(_ ocrText: String) -> ReceiptAnalysisResult {
        let lines = ocrText.split(separator: "\n").map(String.init)
        
        // Basic vendor extraction (first non-empty line)
        let vendor = lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? "Unknown Vendor"
        
        // Basic amount extraction using regex
        let amount = extractAmountFromText(ocrText)
        
        // Basic payment method detection
        let paymentMethod = detectPaymentMethod(ocrText)
        
        // Basic date extraction
        let receiptDate = extractDateFromText(ocrText)
        
        // Basic payment method details extraction
        let paymentMethodDetails = extractPaymentMethodDetails(ocrText)
        
        // Create basic item if amount found
        var items: [ReceiptItemResult] = []
        if amount > 0 {
            items.append(ReceiptItemResult(
                name: "Receipt Total",
                quantity: 1.0,
                unitPrice: amount,
                totalPrice: amount,
                category: "Materials"
            ))
        }
        
        return ReceiptAnalysisResult(
            vendor: vendor,
            category: "Materials", // Default category
            amount: amount,
            taxAmount: 0.0,
            discountAmount: 0.0,
            paymentMethod: paymentMethod,
            paymentMethodDetails: paymentMethodDetails,
            receiptNumber: "",
            receiptDate: receiptDate,
            items: items,
            isReturn: false,
            confidence: 0.6 // Lower confidence for basic OCR
        )
    }
    
    private func extractAmountFromText(_ text: String) -> Double {
        let patterns = [
            "\\$\\d+\\.\\d{2}",  // $12.34
            "\\d+\\.\\d{2}",     // 12.34
            "TOTAL:?\\s*\\$?(\\d+\\.\\d{2})", // TOTAL: $12.34
            "Amount:?\\s*\\$?(\\d+\\.\\d{2})" // Amount: $12.34
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    let matchRange = Range(match.range, in: text)!
                    let matchedText = String(text[matchRange])
                    let cleanedText = matchedText.replacingOccurrences(of: "$", with: "")
                                                 .replacingOccurrences(of: "TOTAL:", with: "")
                                                 .replacingOccurrences(of: "Amount:", with: "")
                                                 .trimmingCharacters(in: .whitespaces)
                    
                    if let amount = Double(cleanedText) {
                        return amount
                    }
                }
            }
        }
        
        return 0.0
    }
    
    private func detectPaymentMethod(_ text: String) -> String {
        let lowercaseText = text.lowercased()
        
        if lowercaseText.contains("cash") {
            return "Cash"
        } else if lowercaseText.contains("visa") {
            return "Credit Card"
        } else if lowercaseText.contains("mastercard") || lowercaseText.contains("master card") {
            return "Credit Card"
        } else if lowercaseText.contains("amex") || lowercaseText.contains("american express") {
            return "Credit Card"
        } else if lowercaseText.contains("discover") {
            return "Credit Card"
        } else if lowercaseText.contains("debit") {
            return "Debit Card"
        } else if lowercaseText.contains("check") {
            return "Check"
        } else {
            return "Credit Card" // Default assumption
        }
    }
    
    private func extractDateFromText(_ text: String) -> Date? {
        let datePatterns = [
            "\\d{1,2}/\\d{1,2}/\\d{2,4}",    // MM/DD/YY or MM/DD/YYYY
            "\\d{1,2}-\\d{1,2}-\\d{2,4}",    // MM-DD-YY or MM-DD-YYYY
            "\\d{4}-\\d{1,2}-\\d{1,2}",      // YYYY-MM-DD
            "\\d{1,2}\\.\\d{1,2}\\.\\d{2,4}" // MM.DD.YY or MM.DD.YYYY
        ]
        
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    let matchRange = Range(match.range, in: text)!
                    let dateString = String(text[matchRange])
                    
                    if let date = parseBasicDate(dateString) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    private func parseBasicDate(_ dateString: String) -> Date? {
        let formatters = [
            "MM/dd/yyyy", "MM/dd/yy", "M/d/yyyy", "M/d/yy",
            "MM-dd-yyyy", "MM-dd-yy", "M-d-yyyy", "M-d-yy",
            "yyyy-MM-dd", "yyyy-M-d",
            "MM.dd.yyyy", "MM.dd.yy", "M.d.yyyy", "M.d.yy"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    private func extractPaymentMethodDetails(_ text: String) -> PaymentMethodDetails? {
        let lowercaseText = text.lowercased()
        
        // Extract last 4 digits patterns
        let digitPatterns = [
            "\\*\\*\\*\\*(\\d{4})",           // ****1234
            "xxxx\\s*(\\d{4})",               // xxxx 1234
            "ending\\s+in\\s+(\\d{4})",       // ending in 1234
            "card\\s+ending\\s+(\\d{4})",     // card ending 1234
            "acct\\s+ending\\s+(\\d{4})"      // acct ending 1234
        ]
        
        var lastFourDigits: String?
        for pattern in digitPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   match.numberOfRanges > 1 {
                    let digitRange = Range(match.range(at: 1), in: text)!
                    lastFourDigits = String(text[digitRange])
                    break
                }
            }
        }
        
        // Extract card brand
        var cardBrand: String?
        if lowercaseText.contains("visa") {
            cardBrand = "Visa"
        } else if lowercaseText.contains("mastercard") || lowercaseText.contains("master card") {
            cardBrand = "Mastercard"
        } else if lowercaseText.contains("amex") || lowercaseText.contains("american express") {
            cardBrand = "American Express"
        } else if lowercaseText.contains("discover") {
            cardBrand = "Discover"
        } else if lowercaseText.contains("chase") {
            cardBrand = "Chase"
        }
        
        if cardBrand != nil || lastFourDigits != nil {
            return PaymentMethodDetails(
                cardBrand: cardBrand,
                lastFourDigits: lastFourDigits,
                accountInfo: nil
            )
        }
        
        return nil
    }
    
    // MARK: - AI Analysis
    
    private func performAIAnalysis(ocrText: String, projectName: String) async throws -> ReceiptAnalysisResult {
        // Direct AI integration without service dependencies
        let prompt = createReceiptAnalysisPrompt(ocrText: ocrText, projectName: projectName)
        
        // Use the hard-coded production API key for enterprise functionality
        let response = try await makeOpenAIRequest(prompt: prompt)
        
        return try parseAIResponse(response)
    }
    
    private func createReceiptAnalysisPrompt(ocrText: String, projectName: String) -> String {
        let contextInfo = "Project: \(projectName)"
        
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
    
    private func makeOpenAIRequest(prompt: String) async throws -> String {
        let apiKey = "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"
        let baseURL = "https://api.openai.com/v1/chat/completions"
        
        let requestBody = [
            "model": "gpt-3.5-turbo",
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
            throw NSError(domain: "AI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("RHEIR-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error (\(httpResponse.statusCode)): \(errorMessage)"])
        }
        
        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonResponse["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "AI", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        return content
    }
    
    private func parseAIResponse(_ content: String) throws -> ReceiptAnalysisResult {
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanContent.data(using: .utf8) else {
            throw NSError(domain: "AI", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid text encoding"])
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "AI", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
            }
            
            let vendor = json["vendor"] as? String ?? "Unknown Vendor"
            let category = json["category"] as? String ?? "Materials"
            let amount = json["amount"] as? Double ?? 0.0
            let taxAmount = json["taxAmount"] as? Double ?? 0.0
            let discountAmount = json["discountAmount"] as? Double ?? 0.0
            let paymentMethod = json["paymentMethod"] as? String ?? "Credit Card"
            let receiptNumber = json["receiptNumber"] as? String ?? ""
            let isReturn = json["isReturn"] as? Bool ?? false
            let confidence = json["confidence"] as? Double ?? 0.8
            
            var items: [ReceiptItemResult] = []
            if let itemsArray = json["items"] as? [[String: Any]] {
                for itemDict in itemsArray {
                    let item = ReceiptItemResult(
                        name: itemDict["name"] as? String ?? "Unknown Item",
                        quantity: itemDict["quantity"] as? Double ?? 1.0,
                        unitPrice: itemDict["unitPrice"] as? Double ?? 0.0,
                        totalPrice: itemDict["totalPrice"] as? Double ?? 0.0,
                        category: itemDict["category"] as? String ?? "Materials"
                    )
                    items.append(item)
                }
            }
            
            return ReceiptAnalysisResult(
                vendor: vendor,
                category: category,
                amount: amount,
                taxAmount: taxAmount,
                discountAmount: discountAmount,
                paymentMethod: paymentMethod,
                receiptNumber: receiptNumber,
                items: items,
                isReturn: isReturn,
                confidence: confidence
            )
            
        } catch {
            print("❌ AI Response Parsing Error: \(error)")
            print("📄 Raw AI Response: \(cleanContent)")
            throw NSError(domain: "AI", code: -6, userInfo: [NSLocalizedDescriptionKey: "Failed to parse AI response: \(error.localizedDescription)"])
        }
    }
}

// MARK: - Document Scanner

struct DocumentScannerView: UIViewControllerRepresentable {
    let completion: (Result<[UIImage], Error>) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: (Result<[UIImage], Error>) -> Void
        
        init(completion: @escaping (Result<[UIImage], Error>) -> Void) {
            self.completion = completion
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                images.append(image)
            }
            
            completion(.success(images))
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            completion(.failure(error))
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            completion(.failure(NSError(domain: "Scanner", code: -1, userInfo: [NSLocalizedDescriptionKey: "Scanning cancelled"])))
            controller.dismiss(animated: true)
        }
    }
}

#if DEBUG
struct ReceiptScannerView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProject = Project(
            name: "Sample House",
            client: "John Doe",
            totalBudget: 50000,
            materialCost: 25000,
            laborCost: 15000,
            generalConditions: 5000,
            contingency: 5000,
            profit: 0,
            startDate: Date(),
            endDate: Date()
        )
        
        ReceiptScannerView(isPresented: .constant(true), project: sampleProject)
            .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
    }
}
#endif