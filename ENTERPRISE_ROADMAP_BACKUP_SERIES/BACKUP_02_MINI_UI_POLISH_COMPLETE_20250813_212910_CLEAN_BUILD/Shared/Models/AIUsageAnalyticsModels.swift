import Foundation

// MARK: - AI Usage Analytics Models

/// Record of AI usage for analytics tracking
struct AIUsageRecord: Codable, Identifiable {
    let id: UUID
    let organizationID: String
    let subscriptionTier: SubscriptionTier
    let feature: AIFeature
    let tokensUsed: Int
    let cost: Double
    let timestamp: Date
    
    init(
        organizationID: String,
        subscriptionTier: SubscriptionTier,
        feature: AIFeature,
        tokensUsed: Int,
        cost: Double,
        timestamp: Date
    ) {
        self.id = UUID()
        self.organizationID = organizationID
        self.subscriptionTier = subscriptionTier
        self.feature = feature
        self.tokensUsed = tokensUsed
        self.cost = cost
        self.timestamp = timestamp
    }
    
    /// Day key for grouping records by day (YYYY-MM-DD format)
    var dayKey: String {
        Self.dayKeyFormatter.string(from: timestamp)
    }
    
    /// Shared formatter for day keys
    static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// Usage statistics for an organization
struct OrganizationUsageStats {
    let organizationID: String
    let period: UsagePeriod
    let totalRequests: Int
    let totalTokens: Int
    let totalCost: Double
    let receiptAnalyses: Int
    let averageTokensPerRequest: Double
    let dailyBreakdown: [String: DailyUsageStats]
    
    init(
        organizationID: String,
        period: UsagePeriod,
        totalRequests: Int,
        totalTokens: Int,
        totalCost: Double,
        receiptAnalyses: Int,
        averageTokensPerRequest: Double,
        dailyBreakdown: [String: DailyUsageStats]
    ) {
        self.organizationID = organizationID
        self.period = period
        self.totalRequests = totalRequests
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.receiptAnalyses = receiptAnalyses
        self.averageTokensPerRequest = averageTokensPerRequest
        self.dailyBreakdown = dailyBreakdown
    }
    
    var averageCostPerRequest: Double {
        totalRequests > 0 ? totalCost / Double(totalRequests) : 0.0
    }
    
    var averageCostPerToken: Double {
        totalTokens > 0 ? totalCost / Double(totalTokens) : 0.0
    }
}

/// Daily usage statistics
struct DailyUsageStats: Codable {
    let organizationID: String
    let date: String
    var requests: Int
    var tokens: Int
    var cost: Double
    
    init(
        organizationID: String,
        date: String,
        requests: Int,
        tokens: Int,
        cost: Double
    ) {
        self.organizationID = organizationID
        self.date = date
        self.requests = requests
        self.tokens = tokens
        self.cost = cost
    }
}

/// AI feature types
enum AIFeature: String, Codable, CaseIterable {
    case receiptAnalysis = "receipt_analysis"
    case textGeneration = "text_generation"
    case dataExtraction = "data_extraction"
    case smartCategorization = "smart_categorization"
    
    var displayName: String {
        switch self {
        case .receiptAnalysis:
            return "Receipt Analysis"
        case .textGeneration:
            return "Text Generation"
        case .dataExtraction:
            return "Data Extraction"
        case .smartCategorization:
            return "Smart Categorization"
        }
    }
    
    var estimatedTokensPerRequest: Int {
        switch self {
        case .receiptAnalysis: return 1200 // OCR text + analysis
        case .textGeneration: return 800
        case .dataExtraction: return 600
        case .smartCategorization: return 1500
        }
    }
}

/// Usage limit status for subscription tiers
enum UsageLimitStatus {
    case normal
    case warning     // 75%+ usage
    case nearLimit   // 90%+ usage
    case exceeded    // 100%+ usage
    
    var displayText: String {
        switch self {
        case .normal:
            return "Normal Usage"
        case .warning:
            return "High Usage"
        case .nearLimit:
            return "Near Limit"
        case .exceeded:
            return "Limit Exceeded"
        }
    }
    
    var color: String {
        switch self {
        case .normal:
            return "green"
        case .warning:
            return "yellow"
        case .nearLimit:
            return "orange"
        case .exceeded:
            return "red"
        }
    }
    
    var message: String {
        switch self {
        case .normal:
            return "Usage is within normal limits"
        case .warning:
            return "Approaching usage limits (75%)"
        case .nearLimit:
            return "Near usage limits (90%)"
        case .exceeded:
            return "Usage limits exceeded"
        }
    }
    
    var colorName: String {
        switch self {
        case .normal: return "green"
        case .warning: return "yellow"
        case .nearLimit: return "orange"
        case .exceeded: return "red"
        }
    }
}

/// Usage period for analytics
enum UsagePeriod {
    case currentMonth
    case last30Days
    case last7Days
    case today
    case yesterday
    case lastMonth
    case currentYear
    
    var displayName: String {
        switch self {
        case .currentMonth:
            return "Current Month"
        case .last30Days:
            return "Last 30 Days"
        case .last7Days:
            return "Last 7 Days"
        case .today:
            return "Today"
        case .yesterday:
            return "Yesterday"
        case .lastMonth:
            return "Last Month"
        case .currentYear:
            return "This Year"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .currentMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            return (start: startOfMonth, end: endOfMonth)
            
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (start: start, end: now)
            
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start: start, end: now)
            
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
            return (start: startOfDay, end: endOfDay)
            
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            let start = calendar.startOfDay(for: yesterday)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start: start, end: end)
            
        case .lastMonth:
            let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now)!
            let interval = calendar.dateInterval(of: .month, for: lastMonthDate)!
            return (interval.start, interval.end)
            
        case .currentYear:
            let start = calendar.dateInterval(of: .year, for: now)!.start
            return (start: start, end: now)
        }
    }
}

/// AI usage limits for subscription tiers
struct AIUsageLimits {
    let maxRequestsPerMonth: Int
    let maxTokensPerMonth: Int
    let allowedFeatures: [AIFeature]
    
    init(
        maxRequestsPerMonth: Int,
        maxTokensPerMonth: Int,
        allowedFeatures: [AIFeature]
    ) {
        self.maxRequestsPerMonth = maxRequestsPerMonth
        self.maxTokensPerMonth = maxTokensPerMonth
        self.allowedFeatures = allowedFeatures
    }
    
    /// Check if a feature is allowed for this subscription tier
    func isFeatureAllowed(_ feature: AIFeature) -> Bool {
        return allowedFeatures.contains(feature)
    }
}

// MARK: - SubscriptionTier AI Usage Extension

extension SubscriptionTier {
    var aiUsageLimits: AIUsageLimits {
        switch self {
        case .free, .starter:
            return AIUsageLimits(
                maxRequestsPerMonth: 50,
                maxTokensPerMonth: 60_000,
                allowedFeatures: [.receiptAnalysis]
            )
        case .professional, .standard:
            return AIUsageLimits(
                maxRequestsPerMonth: 1_000,
                maxTokensPerMonth: 1_200_000,
                allowedFeatures: AIFeature.allCases
            )
        case .enterprise, .premium:
            return AIUsageLimits(
                maxRequestsPerMonth: Int.max,
                maxTokensPerMonth: Int.max,
                allowedFeatures: AIFeature.allCases
            )
        }
    }
}