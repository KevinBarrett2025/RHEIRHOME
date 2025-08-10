import SwiftUI
import VisionKit
import Vision

struct ReceiptScannerView: View {
    @Binding var isPresented: Bool
    let project: Project
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @AppStorage("hideReceiptScannerIntro") private var hideIntro = false
    
    @State private var showingDocumentScanner = false
    @State private var showingImagePicker = false
    @State private var showingAnalysisView = false
    @State private var showingUpgradePrompt = false
    @State private var showingIntroOverlay = false
    @State private var scannedImage: UIImage?
    @State private var analysisResult: ReceiptAnalysisResult?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedImageFromPicker: UIImage?
    @State private var processingStep = ""
    
    private var hasAIAccess: Bool {
        authVM.currentOrg?.subscriptionTier != .free
    }
    
    var body: some View {
        ZStack {
            if hasAIAccess {
                // Subscribers get direct access to camera or optional intro
                if showingIntroOverlay && !hideIntro {
                    subscriberIntroOverlay
                } else {
                    // Direct camera access for subscribers
                    Color.clear
                        .onAppear {
                            if !isProcessing && scannedImage == nil {
                                showingDocumentScanner = true
                            }
                        }
                }
            } else {
                // Free users see upgrade prompt
                upgradePromptView
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
        .onAppear {
            setupInitialView()
        }
    }
    
    private func setupInitialView() {
        if hasAIAccess {
            // Show intro overlay first time, then direct camera access
            if !hideIntro {
                showingIntroOverlay = true
                // Auto-hide intro after 3 seconds and go to camera
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showingIntroOverlay = false
                    showingDocumentScanner = true
                }
            } else {
                // Direct camera access for returning users
                showingDocumentScanner = true
            }
        }
        // Free users see upgrade prompt (no auto-actions)
    }
    
    @ViewBuilder
    private var subscriberIntroOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // AI Scanner Icon with pulse animation
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(1.2)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showingIntroOverlay)
                    
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 12) {
                    Text("AI-Powered Receipt Scanner")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Automatic categorization and data extraction ready")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                // AI Features with icons
                VStack(spacing: 8) {
                    aiFeatureRow("Vendor recognition", "building.2.fill")
                    aiFeatureRow("Smart categorization", "tag.fill")
                    aiFeatureRow("Payment detection", "creditcard.fill")
                    aiFeatureRow("Item breakdown", "list.bullet.rectangle.fill")
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    Button("Start Scanning") {
                        showingIntroOverlay = false
                        showingDocumentScanner = true
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    
                    HStack(spacing: 16) {
                        Button("Don't show again") {
                            hideIntro = true
                            showingIntroOverlay = false
                            showingDocumentScanner = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Button("Choose from Photos") {
                            showingIntroOverlay = false
                            showingImagePicker = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button("Close") {
                        isPresented = false
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(20)
                }
                Spacer()
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func aiFeatureRow(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            Spacer()
        }
    }
    
    @ViewBuilder
    private var upgradePromptView: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Locked scanner icon
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }
                }
                
                VStack(spacing: 16) {
                    Text("AI-Powered Receipt Scanner")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Upgrade to unlock automatic receipt scanning with AI-powered data extraction")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Premium features showcase
                VStack(alignment: .leading, spacing: 12) {
                    Text("Premium Features:")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 8) {
                        premiumFeatureRow("Instant camera scanning", "Skip manual entry")
                        premiumFeatureRow("AI vendor recognition", "Automatic vendor detection")
                        premiumFeatureRow("Smart categorization", "Intelligent expense sorting")
                        premiumFeatureRow("Payment method detection", "Auto-fill card information")
                        premiumFeatureRow("Itemized breakdown", "Line-by-line receipt analysis")
                        premiumFeatureRow("Tax & discount tracking", "Comprehensive financial data")
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button("Upgrade to Premium") {
                        // TODO: Navigate to subscription flow
                        print("Navigate to subscription upgrade")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.orange, .red]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    
                    Button("Use Manual Entry Instead") {
                        isPresented = false
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                }
            }
            .padding()
            .navigationTitle("Receipt Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func premiumFeatureRow(_ title: String, _ description: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    // MARK: - Processing Overlay
    
    @ViewBuilder
    private var processingOverlay: some View {
        if isProcessing {
            ZStack {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.blue)
                    
                    VStack(spacing: 8) {
                        Text("Processing Receipt...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(processingStep)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .padding(.horizontal, 40)
            }
        }
    }
    
    // MARK: - Scanner Result Handling
    
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
        processingStep = "Extracting text with OCR..."
        
        Task {
            do {
                guard let currentOrg = authVM.currentOrg else {
                    throw ReceiptAnalysisError.noOrganization
                }
                
                // Step 1: Extract text using OCR
                await MainActor.run {
                    processingStep = "Extracting text from image..."
                }
                
                let ocrText = try await extractTextFromImage(image)
                print("OCR Extracted Text:")
                print(ocrText)
                print("---")
                
                // Step 2: Try AI analysis with subscription checking
                await MainActor.run {
                    processingStep = "Analyzing with AI..."
                }
                
                var analysisResult: ReceiptAnalysisResult
                
                // Check if organization can use AI features
                if currentOrg.subscriptionTier != .free {
                    // Try production AI analysis
                    do {
                        analysisResult = try await performAIAnalysis(ocrText: ocrText, projectName: project.name)
                        print("AI analysis completed successfully!")
                    } catch {
                        print("AI analysis failed, falling back to basic OCR: \(error)")
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
                    print("Free tier - using basic OCR processing")
                    analysisResult = createBasicAnalysisFromOCR(ocrText)
                }
                
                print("Receipt processing completed!")
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
                
                print("Receipt processing failed: \(error)")
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
            print("AI Response Parsing Error: \(error)")
            print("Raw AI Response: \(cleanContent)")
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