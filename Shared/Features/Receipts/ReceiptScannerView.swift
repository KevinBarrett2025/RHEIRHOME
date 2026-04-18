import SwiftUI
import VisionKit
import Vision
import OSLog

enum ReceiptScannerStep: Equatable {
    case info
    case launcher
    case camera
    case processing
    case complete
}

enum ReceiptScannerDocumentResult {
    case success([UIImage])
    case cancelled
    case failure(Error)
}

struct DeferredScannerResult<Value> {
    private var pendingValue: Value?

    var hasPendingValue: Bool {
        pendingValue != nil
    }

    mutating func queue(_ value: Value) -> Bool {
        guard pendingValue == nil else {
            return false
        }

        pendingValue = value
        return true
    }

    mutating func consume() -> Value? {
        defer { pendingValue = nil }
        return pendingValue
    }
}

final class DocumentScannerCompletionGate {
    private var hasCompleted = false

    func perform(_ action: () -> Void) -> Bool {
        guard !hasCompleted else {
            return false
        }

        hasCompleted = true
        action()
        return true
    }
}

struct ReceiptScannerPresentationState {
    var currentStep: ReceiptScannerStep = .info
    var showingDocumentScanner = false
    private var hasCompletedInitialSetup = false
    private var deferredDocumentScanResult = DeferredScannerResult<ReceiptScannerDocumentResult>()

    mutating func performInitialSetup(hideIntro: Bool, hasAIAccess: Bool) -> Bool {
        guard !hasCompletedInitialSetup else {
            return false
        }

        hasCompletedInitialSetup = true

        if hideIntro && hasAIAccess {
            beginDocumentScan()
        } else {
            returnToEntry(hideIntro: hideIntro)
        }

        return true
    }

    mutating func beginDocumentScan() {
        currentStep = .camera
        showingDocumentScanner = true
        deferredDocumentScanResult = DeferredScannerResult()
    }

    mutating func queueDocumentResult(_ result: ReceiptScannerDocumentResult) -> Bool {
        guard deferredDocumentScanResult.queue(result) else {
            return false
        }

        showingDocumentScanner = false
        return true
    }

    mutating func consumeQueuedDocumentResult() -> ReceiptScannerDocumentResult? {
        deferredDocumentScanResult.consume()
    }

    mutating func returnToEntry(hideIntro: Bool) {
        currentStep = hideIntro ? .launcher : .info
        showingDocumentScanner = false
        deferredDocumentScanResult = DeferredScannerResult()
    }
}

struct ReceiptScannerView: View {
    @Binding var isPresented: Bool
    let project: Project
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @AppStorage("hideReceiptScannerIntro") private var hideIntro = false
    
    @State private var scannerPresentation = ReceiptScannerPresentationState()
    @State private var showingImagePicker = false
    @State private var showingAnalysisView = false
    @State private var showingUpgradePrompt = false
    @State private var scannedImage: UIImage?
    @State private var analysisResult: ReceiptAnalysisResult?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedImageFromPicker: UIImage?
    @State private var processingStep = ""
    @State private var receiptSaveCompleted = false
    
    private var hasAIAccess: Bool {
        authVM.currentOrg?.subscriptionTier != .free
    }
    
    var body: some View {
        ZStack {
            if hasAIAccess {
                // Subscribers get proper flow: Info → Camera → Processing → Manual Entry
                switch scannerPresentation.currentStep {
                case .info, .launcher:
                    entryPageView
                case .camera:
                    Color.clear // Camera shows via explicit state, not .onAppear side effects
                case .processing:
                    processingOverlay
                case .complete:
                    Color.clear // Analysis view will show via sheet
                }
            } else {
                // Free users see upgrade prompt
                upgradePromptView
            }
        }
        .sheet(isPresented: $scannerPresentation.showingDocumentScanner, onDismiss: handleDocumentScannerDismiss) {
            DocumentScannerView { result in
                queueDocumentScanResult(result)
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
                    scannedImage: scannedImage,
                    onReceiptSaved: {
                        // When receipt is successfully saved, mark completion and dismiss scanner
                        receiptSaveCompleted = true
                        isPresented = false
                    }
                )
                .environmentObject(projectVM)
            }
        }
        .alert("Scanning Error", isPresented: $showingError) {
            Button("OK") { 
                returnToEntryState()
            }
            Button("Try Again") {
                beginDocumentScan()
            }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
        .onChange(of: selectedImageFromPicker) { _, newImage in
            if let image = newImage {
                scannerPresentation.currentStep = .processing
                handleImageSelection(image)
                selectedImageFromPicker = nil
            }
        }
        .onChange(of: showingAnalysisView) { _, isShowing in
            // If analysis view was dismissed but no receipt was saved, return to info
            if !isShowing && !receiptSaveCompleted && scannerPresentation.currentStep == .complete {
                returnToEntryState()
            }
        }
        .onAppear {
            let performedInitialSetup = scannerPresentation.performInitialSetup(
                hideIntro: hideIntro,
                hasAIAccess: hasAIAccess
            )

            if performedInitialSetup {
                receiptSaveCompleted = false
                Logger.receiptWorkflow.info(
                    "Receipt scanner initial setup completed [hideIntro=\(hideIntro, privacy: .public) aiAccess=\(hasAIAccess, privacy: .public)]."
                )
            } else {
                Logger.receiptWorkflow.info("Receipt scanner reappeared after initial setup; preserving current scanner state.")
            }
        }
    }

    private func beginDocumentScan() {
        errorMessage = nil
        showingError = false
        scannedImage = nil
        analysisResult = nil
        selectedImageFromPicker = nil
        receiptSaveCompleted = false
        isProcessing = false
        processingStep = ""
        scannerPresentation.beginDocumentScan()
    }

    private func returnToEntryState() {
        scannerPresentation.returnToEntry(hideIntro: hideIntro)
    }
    
    @ViewBuilder
    private var entryPageView: some View {
        let showsIntro = scannerPresentation.currentStep == .info

        NavigationStack {
            ScrollView {
                VStack(spacing: showsIntro ? 32 : 24) {
                    Spacer()

                    if showsIntro {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 120, height: 120)
                                .scaleEffect(1.2)
                                .opacity(0.8)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: scannerPresentation.currentStep == .info)

                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 48))
                                .foregroundColor(.blue)
                        }

                        VStack(spacing: 16) {
                            Text("AI-Powered Receipt Scanner")
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)

                            Text("Get automatic categorization and data extraction from your receipt photos")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        VStack(spacing: 12) {
                            Text("What This Scanner Does:")
                                .font(.headline)
                                .foregroundColor(.blue)

                            VStack(spacing: 8) {
                                aiFeatureRow("Vendor recognition", "building.2.fill")
                                aiFeatureRow("Smart categorization", "tag.fill")
                                aiFeatureRow("Payment detection", "creditcard.fill")
                                aiFeatureRow("Item breakdown", "list.bullet.rectangle.fill")
                                aiFeatureRow("Tax & discount extraction", "percent")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        VStack(spacing: 12) {
                            Text("How to Get Best Results:")
                                .font(.headline)
                                .foregroundColor(.orange)

                            VStack(alignment: .leading, spacing: 8) {
                                instructionRow("1.", "Make sure receipt is well-lit")
                                instructionRow("2.", "Keep receipt flat and in frame")
                                instructionRow("3.", "Include all text and numbers")
                                instructionRow("4.", "Avoid shadows and reflections")
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 42))
                                .foregroundColor(.blue)

                            Text("Receipt Scanner")
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)

                            Text("Scan another receipt or import a photo without reopening the full onboarding guide.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Receipt Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Action buttons at bottom
                VStack(spacing: 12) {
                    Button("Start Camera Scan") {
                        beginDocumentScan()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    
                    HStack(spacing: 20) {
                        if !hideIntro {
                            Button("Don't show info again") {
                                hideIntro = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Choose from Photos") {
                            showingImagePicker = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
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
                .foregroundColor(.primary)
            Spacer()
        }
    }
    
    @ViewBuilder
    private func instructionRow(_ number: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
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
                        Logger.receiptWorkflow.notice(
                            "Receipt scanner upgrade prompt accepted; subscription navigation is not yet implemented."
                        )
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
                
                Button("Cancel") {
                    returnToEntryState()
                    isProcessing = false
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 20)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Scanner Result Handling

    private func queueDocumentScanResult(_ result: ReceiptScannerDocumentResult) {
        guard scannerPresentation.queueDocumentResult(result) else {
            Logger.receiptWorkflow.warning(
                "Ignored duplicate receipt scanner result while document scanner dismissal was pending."
            )
            return
        }

        Logger.receiptWorkflow.info("Queued receipt scanner result and requested document scanner dismissal.")
    }

    private func handleDocumentScannerDismiss() {
        guard let result = scannerPresentation.consumeQueuedDocumentResult() else {
            if scannerPresentation.currentStep == .camera && !isProcessing {
                Logger.receiptWorkflow.info(
                    "Receipt scanner document sheet dismissed without a queued result; returning to intro."
                )
                returnToEntryState()
            }
            return
        }

        Logger.receiptWorkflow.info("Receipt scanner document sheet dismissed; starting queued receipt processing.")
        handleScanResult(result)
    }
    
    private func handleScanResult(_ result: ReceiptScannerDocumentResult) {
        switch result {
        case .success(let images):
            scannerPresentation.currentStep = .processing
            if let firstImage = images.first {
                handleImageSelection(firstImage)
            } else {
                returnToEntryState()
                errorMessage = "No image captured"
                showingError = true
            }
        case .cancelled:
            returnToEntryState()
        case .failure(let error):
            returnToEntryState()
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
                    processingStep = "Extractinging text from image..."
                }
                
                let ocrText = try await extractTextFromImage(image)
                Logger.receiptWorkflow.info(
                    "Extracted OCR text in receipt scanner [characters=\(ocrText.count, privacy: .public)]"
                )
                
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
                        Logger.receiptWorkflow.notice("Receipt scanner AI analysis completed successfully.")
                    } catch {
                        Logger.receiptWorkflow.warning(
                            "Receipt scanner AI analysis failed; falling back to basic OCR [error=\(error.localizedDescription, privacy: .public)]"
                        )
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
                    Logger.receiptWorkflow.info("Receipt scanner using basic OCR processing for free tier.")
                    analysisResult = createBasicAnalysisFromOCR(ocrText)
                }
                
                Logger.receiptWorkflow.notice(
                    "Receipt processing completed [vendor=\(analysisResult.vendor, privacy: .private(mask: .hash)) amount=\(analysisResult.amount, privacy: .public) category=\(analysisResult.category, privacy: .public) items=\(analysisResult.items.count, privacy: .public) confidence=\(analysisResult.confidence, privacy: .public)]"
                )
                
                await MainActor.run {
                    isProcessing = false
                    scannerPresentation.currentStep = .complete
                    self.analysisResult = analysisResult
                    showingAnalysisView = true
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    returnToEntryState()
                    
                    if let receiptError = error as? ReceiptAnalysisError {
                        errorMessage = receiptError.localizedDescription
                    } else {
                        errorMessage = "Failed to process receipt: \(error.localizedDescription)"
                    }
                    
                    showingError = true
                }
                
                Logger.receiptWorkflow.error(
                    "Receipt processing failed [error=\(error.localizedDescription, privacy: .public)]"
                )
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
        
        // Smart category classification based on vendor name and OCR text
        let category = classifyReceiptCategory(vendor: vendor, ocrText: ocrText)
        
        // Basic amount extraction using regex
        let amount = extractAmountFromText(ocrText)
        
        // Basic payment method detection
        let paymentMethod = detectPaymentMethod(ocrText)
        
        // Basic date extraction
        let receiptDate = extractDateFromText(ocrText)
        
        // Enhanced payment method details extraction
        let paymentMethodDetails = extractPaymentMethodDetails(ocrText)
        
        // Create basic item if amount found
        var items: [ReceiptItemResult] = []
        if amount > 0 {
            items.append(ReceiptItemResult(
                name: "Receipt Total",
                quantity: 1.0,
                unitPrice: amount,
                totalPrice: amount,
                category: category
            ))
        }
        
        return ReceiptAnalysisResult(
            vendor: vendor,
            category: category,
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
    
    private func classifyReceiptCategory(vendor: String, ocrText: String) -> String {
        let vendorLower = vendor.lowercased()
        let textLower = ocrText.lowercased()
        
        // Food & Beverage establishments → General Conditions
        let foodBeverageKeywords = [
            // Restaurant types
            "restaurant", "cafe", "coffee", "diner", "bistro", "grill", "bar", "pub", 
            "tavern", "brewery", "brew", "kitchen", "eatery", "food", "pizza", "burger",
            "sandwich", "taco", "mexican", "chinese", "italian", "thai", "sushi",
            "steakhouse", "bbq", "barbecue", "wings", "chicken", "seafood",
            
            // Food service chains
            "mcdonalds", "burger king", "subway", "kfc", "taco bell", "pizza hut",
            "dominos", "starbucks", "dunkin", "panera", "chipotle", "wendys",
            
            // Beverage keywords
            "beer", "wine", "cocktail", "drink", "beverage", "juice", "smoothie",
            
            // Food items
            "meal", "lunch", "dinner", "breakfast", "snack", "appetizer", "dessert"
        ]
        
        for keyword in foodBeverageKeywords {
            if vendorLower.contains(keyword) || textLower.contains(keyword) {
                return "General Conditions"
            }
        }
        
        // Building materials & hardware → Materials
        let materialsKeywords = [
            "home depot", "lowes", "menards", "ace hardware", "true value", "hardware",
            "lumber", "building supply", "supply", "materials", "hardware store",
            "plumbing", "electrical", "roofing", "concrete", "steel", "metal",
            "paint", "tools", "nails", "screws", "wood", "drywall", "insulation"
        ]
        
        for keyword in materialsKeywords {
            if vendorLower.contains(keyword) || textLower.contains(keyword) {
                return "Materials"
            }
        }
        
        // Fuel & utilities → General Conditions
        let generalConditionsKeywords = [
            "gas station", "shell", "exxon", "bp", "chevron", "mobil", "texaco",
            "citgo", "wawa", "sheetz", "fuel", "gasoline", "diesel",
            "office", "supplies", "staples", "office depot", "fedex", "ups",
            "permits", "license", "inspection", "utility", "electric", "water"
        ]
        
        for keyword in generalConditionsKeywords {
            if vendorLower.contains(keyword) || textLower.contains(keyword) {
                return "General Conditions"
            }
        }
        
        // Default fallback based on common patterns
        if vendorLower.contains("store") && (textLower.contains("food") || textLower.contains("grocery")) {
            return "General Conditions"
        }
        
        // Default to Materials for unknown vendors
        return "Materials"
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
        // Enhanced last 4 digits patterns with more comprehensive coverage
        let digitPatterns = [
            "\\*\\*\\*\\*\\s*-?\\s*(\\d{4})",           // ****-1234 or **** 1234
            "xxxx\\s*-?\\s*(\\d{4})",                   // xxxx-1234 or xxxx 1234
            "ending\\s+in\\s+(\\d{4})",                 // ending in 1234
            "ends\\s+in\\s+(\\d{4})",                   // ends in 1234
            "card\\s+ending\\s+(\\d{4})",               // card ending 1234
            "acct\\s+ending\\s+(\\d{4})",               // acct ending 1234
            "account\\s+ending\\s+(\\d{4})",            // account ending 1234
            "card\\s*:\\s*\\*+\\s*(\\d{4})",            // card: ***1234
            "credit\\s+card\\s+ending\\s+(\\d{4})",     // credit card ending 1234
            "debit\\s+card\\s+ending\\s+(\\d{4})",      // debit card ending 1234
            "\\d{4}\\s+\\d{4}\\s+\\d{4}\\s+(\\d{4})",  // Full card number pattern (capture last 4)
            "card\\s*:\\s*\\*+(\\d{4})",                // card: ***1234
            "account\\s*:\\s*\\*+(\\d{4})",             // account: ***1234
            "pan\\s*:\\s*\\*+(\\d{4})",                 // PAN: ***1234 (Personal Account Number)
            "ref\\s*#\\s*\\*+(\\d{4})",                 // ref # ***1234
            "auth\\s*:\\s*\\d+\\s*/\\s*\\*+(\\d{4})",   // auth: 123456/*1234
            "masked\\s+card\\s+(\\d{4})",               // masked card 1234
            "card\\s+\\d{4}\\s*\\*+(\\d{4})"            // card 1234****5678 -> get 5678
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
        
        // Enhanced card brand detection with more patterns
        var cardBrand: String?
        let cardBrandPatterns: [(String, [String])] = [
            ("Visa", ["visa", "vi\\b", "visa\\s+credit", "visa\\s+debit", "v\\s+credit", "v\\s+debit"]),
            ("Mastercard", ["mastercard", "master card", "mc\\b", "m/c", "mstr", "master"]),
            ("American Express", ["amex", "american express", "americanexpress", "amx", "ax\\b"]),
            ("Discover", ["discover", "disc\\b", "dsc\\b", "discover card"]),
            ("Chase", ["chase", "jpmorgan chase", "jp morgan"]),
            ("Capital One", ["capital one", "capitalone", "cap one"]),
            ("Wells Fargo", ["wells fargo", "wellsfargo", "wf\\b"]),
            ("Bank of America", ["bank of america", "bankofamerica", "boa\\b", "b of a"]),
            ("Citi", ["citi", "citibank", "citicorp"]),
            ("US Bank", ["us bank", "usbank", "u.s. bank"]),
            ("PNC", ["pnc", "pnc bank"]),
            ("TD Bank", ["td bank", "tdbank"]),
            ("Regions", ["regions", "regions bank"]),
            ("Fifth Third", ["fifth third", "53\\s+bank", "5/3\\s+bank"]),
            ("Truist", ["truist", "bb&t", "suntrust"])
        ]
        
        for (brand, patterns) in cardBrandPatterns {
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(text.startIndex..., in: text)
                    if regex.firstMatch(in: text, options: [], range: range) != nil {
                        cardBrand = brand
                        break
                    }
                }
            }
            if cardBrand != nil { break }
        }
        
        // Enhanced account info extraction
        var accountInfo: String?
        let accountPatterns = [
            "approval\\s*[:#]?\\s*(\\w+)",              // approval: ABC123
            "auth\\s*[:#]?\\s*(\\d+)",                  // auth: 123456
            "reference\\s*[:#]?\\s*(\\w+)",             // reference: REF123
            "transaction\\s*[:#]?\\s*(\\w+)",           // transaction: TXN123
            "terminal\\s*[:#]?\\s*(\\w+)"               // terminal: T123
        ]
        
        for pattern in accountPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   match.numberOfRanges > 1 {
                    let infoRange = Range(match.range(at: 1), in: text)!
                    accountInfo = String(text[infoRange])
                    break
                }
            }
        }
        
        if cardBrand != nil || lastFourDigits != nil || accountInfo != nil {
            return PaymentMethodDetails(
                cardBrand: cardBrand,
                lastFourDigits: lastFourDigits,
                accountInfo: accountInfo
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
            "paymentMethodDetails": {
                "cardBrand": "string - Visa, Mastercard, American Express, Discover, etc. (null if not found)",
                "lastFourDigits": "string - last 4 digits of card (null if not found)",
                "accountInfo": "string - approval code, auth number, or reference (null if not found)"
            },
            "receiptNumber": "string - receipt/transaction number",
            "receiptDate": "string - date in YYYY-MM-DD format (null if not found)",
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
        - General Conditions: permits, insurance, utilities, office supplies, fuel, food/meals
        - Contingency: unexpected items, misc supplies
        - Other: personal items, non-construction related
        
        PAYMENT METHOD DETAILS EXTRACTION PRIORITY:
        - Look for card last 4 digits in formats: ****1234, xxxx 1234, ending in 1234, etc.
        - Identify card brands: Visa, Mastercard, American Express, Discover, Chase, etc.
        - Extract approval codes, auth numbers, or transaction references
        - If cash payment, set paymentMethodDetails to null
        
        BUSINESS TYPE CATEGORIZATION:
        - Restaurants, cafes, food trucks, bars, breweries → General Conditions
        - Building supply stores, hardware stores → Materials
        - Gas stations → General Conditions (fuel)
        - Office supply stores → General Conditions
        
        Extract as many individual items as possible and be conservative with confidence scores.

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
            
            // Enhanced payment method details parsing
            var paymentMethodDetails: PaymentMethodDetails?
            if let paymentDetailsDict = json["paymentMethodDetails"] as? [String: Any] {
                let cardBrand = paymentDetailsDict["cardBrand"] as? String
                let lastFourDigits = paymentDetailsDict["lastFourDigits"] as? String
                let accountInfo = paymentDetailsDict["accountInfo"] as? String
                
                if cardBrand != nil || lastFourDigits != nil || accountInfo != nil {
                    paymentMethodDetails = PaymentMethodDetails(
                        cardBrand: cardBrand,
                        lastFourDigits: lastFourDigits,
                        accountInfo: accountInfo
                    )
                }
            }
            
            // Enhanced date parsing
            var receiptDate: Date?
            if let dateString = json["receiptDate"] as? String, !dateString.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                receiptDate = formatter.date(from: dateString)
            }
            
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
                paymentMethodDetails: paymentMethodDetails,
                receiptNumber: receiptNumber,
                receiptDate: receiptDate,
                items: items,
                isReturn: isReturn,
                confidence: confidence
            )
            
        } catch {
            Logger.receiptWorkflow.error(
                "Failed to parse receipt scanner AI response [error=\(error.localizedDescription, privacy: .public) characters=\(cleanContent.count, privacy: .public)]"
            )
            throw NSError(domain: "AI", code: -6, userInfo: [NSLocalizedDescriptionKey: "Failed to parse AI response: \(error.localizedDescription)"])
        }
    }
}

// MARK: - Document Scanner

struct DocumentScannerView: UIViewControllerRepresentable {
    let completion: (ReceiptScannerDocumentResult) -> Void
    
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
        let completion: (ReceiptScannerDocumentResult) -> Void
        private let completionGate = DocumentScannerCompletionGate()

        init(completion: @escaping (ReceiptScannerDocumentResult) -> Void) {
            self.completion = completion
        }

        private func emit(_ result: ReceiptScannerDocumentResult, callback: StaticString) {
            let didEmit = completionGate.perform {
                DispatchQueue.main.async {
                    self.completion(result)
                }
            }

            if !didEmit {
                Logger.receiptWorkflow.warning(
                    "Ignored duplicate document scanner callback [callback=\(String(describing: callback), privacy: .public)]."
                )
            }
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                images.append(image)
            }
            
            Logger.receiptWorkflow.info(
                "Document scanner finished capture [pages=\(images.count, privacy: .public)]."
            )
            emit(.success(images), callback: "didFinishWithScan")
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            Logger.receiptWorkflow.error(
                "Document scanner failed before receipt processing [error=\(error.localizedDescription, privacy: .public)]."
            )
            emit(.failure(error), callback: "didFailWithError")
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            Logger.receiptWorkflow.info("Document scanner cancelled before receipt processing.")
            emit(.cancelled, callback: "didCancel")
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
            
            startDate: Date(),
            endDate: Date(),
            organizationID: "sample-org-id"
        )
        
        ReceiptScannerView(isPresented: .constant(true), project: sampleProject)
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
    }
}
#endif
