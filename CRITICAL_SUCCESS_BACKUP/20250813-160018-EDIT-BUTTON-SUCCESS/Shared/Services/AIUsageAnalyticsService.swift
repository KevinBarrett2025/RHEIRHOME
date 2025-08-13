import Foundation

/// Service for tracking AI usage and calculating costs for subscription analytics
actor AIUsageAnalyticsService {
    static let shared = AIUsageAnalyticsService()
    
    private init() {}
    
    // MARK: - Usage Tracking
    
    /// Record AI usage for analytics
    func recordUsage(
        organizationID: String,
        subscriptionTier: SubscriptionTier,
        feature: AIFeature,
        tokensUsed: Int,
        cost: Double
    ) async {
        let usage = AIUsageRecord(
            organizationID: organizationID,
            subscriptionTier: subscriptionTier,
            feature: feature,
            tokensUsed: tokensUsed,
            cost: cost,
            timestamp: Date()
        )
        
        await saveUsageRecord(usage)
        await updateDailyStats(usage)
        await checkUsageLimits(organizationID: organizationID, subscriptionTier: subscriptionTier)
    }
    
    /// Get usage statistics for an organization
    func getUsageStats(for organizationID: String, period: UsagePeriod = .currentMonth) async -> OrganizationUsageStats {
        let records = await getUsageRecords(for: organizationID, period: period)
        
        let totalCost = records.reduce(0) { $0 + $1.cost }
        let totalTokens = records.reduce(0) { $0 + $1.tokensUsed }
        let totalRequests = records.count
        
        let receiptAnalyses = records.filter { $0.feature == .receiptAnalysis }.count
        let avgTokensPerRequest = totalRequests > 0 ? Double(totalTokens) / Double(totalRequests) : 0
        
        return OrganizationUsageStats(
            organizationID: organizationID,
            period: period,
            totalRequests: totalRequests,
            totalTokens: totalTokens,
            totalCost: totalCost,
            receiptAnalyses: receiptAnalyses,
            averageTokensPerRequest: avgTokensPerRequest,
            dailyBreakdown: await getDailyBreakdown(records: records)
        )
    }
    
    /// Check if organization has exceeded usage limits
    func checkUsageLimits(organizationID: String, subscriptionTier: SubscriptionTier) async -> UsageLimitStatus {
        let monthlyStats = await getUsageStats(for: organizationID, period: .currentMonth)
        let limits = subscriptionTier.aiUsageLimits
        
        let requestsPercentage = Double(monthlyStats.totalRequests) / Double(limits.maxRequestsPerMonth)
        let tokensPercentage = Double(monthlyStats.totalTokens) / Double(limits.maxTokensPerMonth)
        
        let status: UsageLimitStatus
        if requestsPercentage >= 1.0 || tokensPercentage >= 1.0 {
            status = .exceeded
        } else if requestsPercentage >= 0.9 || tokensPercentage >= 0.9 {
            status = .nearLimit
        } else if requestsPercentage >= 0.75 || tokensPercentage >= 0.75 {
            status = .warning
        } else {
            status = .normal
        }
        
        return status
    }
    
    // MARK: - Cost Calculations
    
    /// Calculate estimated monthly cost for an organization
    func calculateEstimatedMonthlyCost(for organizationID: String) async -> Double {
        // Get usage from last 30 days to estimate
        let stats = await getUsageStats(for: organizationID, period: .last30Days)
        
        // Project monthly cost based on recent usage
        let daysInStats = 30.0
        let daysInMonth = 30.0
        let projectionMultiplier = daysInMonth / daysInStats
        
        return stats.totalCost * projectionMultiplier
    }
    
    /// Get cost breakdown by feature
    func getCostBreakdown(for organizationID: String, period: UsagePeriod = .currentMonth) async -> [AIFeature: Double] {
        let records = await getUsageRecords(for: organizationID, period: period)
        
        var breakdown: [AIFeature: Double] = [:]
        for record in records {
            breakdown[record.feature, default: 0.0] += record.cost
        }
        
        return breakdown
    }
    
    // MARK: - Private Methods
    
    private func saveUsageRecord(_ record: AIUsageRecord) async {
        // In production, save to CloudKit or local database
        let key = "ai_usage_\(record.id.uuidString)"
        let data = try? JSONEncoder().encode(record)
        UserDefaults.standard.set(data, forKey: key)
        
        // Also add to daily list for easier querying
        let dateKey = "ai_usage_day_\(record.dayKey)"
        var dailyRecordIDs = UserDefaults.standard.stringArray(forKey: dateKey) ?? []
        dailyRecordIDs.append(record.id.uuidString)
        UserDefaults.standard.set(dailyRecordIDs, forKey: dateKey)
    }
    
    private func updateDailyStats(_ record: AIUsageRecord) async {
        let statsKey = "ai_daily_stats_\(record.organizationID)_\(record.dayKey)"
        
        var stats: DailyUsageStats
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let existingStats = try? JSONDecoder().decode(DailyUsageStats.self, from: data) {
            stats = existingStats
        } else {
            stats = DailyUsageStats(
                organizationID: record.organizationID,
                date: record.dayKey,
                requests: 0,
                tokens: 0,
                cost: 0.0
            )
        }
        
        stats.requests += 1
        stats.tokens += record.tokensUsed
        stats.cost += record.cost
        
        let updatedData = try? JSONEncoder().encode(stats)
        UserDefaults.standard.set(updatedData, forKey: statsKey)
    }
    
    private func getUsageRecords(for organizationID: String, period: UsagePeriod) async -> [AIUsageRecord] {
        let dateRange = period.dateRange
        var records: [AIUsageRecord] = []
        
        // Get all days in the period
        var currentDate = dateRange.start
        while currentDate <= dateRange.end {
            let dayKey = AIUsageRecord.dayKeyFormatter.string(from: currentDate)
            let dailyRecordIDsKey = "ai_usage_day_\(dayKey)"
            
            if let recordIDs = UserDefaults.standard.stringArray(forKey: dailyRecordIDsKey) {
                for recordID in recordIDs {
                    let recordKey = "ai_usage_\(recordID)"
                    if let data = UserDefaults.standard.data(forKey: recordKey),
                       let record = try? JSONDecoder().decode(AIUsageRecord.self, from: data),
                       record.organizationID == organizationID {
                        records.append(record)
                    }
                }
            }
            
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? dateRange.end
        }
        
        return records.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func getDailyBreakdown(records: [AIUsageRecord]) async -> [String: DailyUsageStats] {
        var breakdown: [String: DailyUsageStats] = [:]
        
        for record in records {
            let dayKey = record.dayKey
            
            if var stats = breakdown[dayKey] {
                stats.requests += 1
                stats.tokens += record.tokensUsed
                stats.cost += record.cost
                breakdown[dayKey] = stats
            } else {
                breakdown[dayKey] = DailyUsageStats(
                    organizationID: record.organizationID,
                    date: dayKey,
                    requests: 1,
                    tokens: record.tokensUsed,
                    cost: record.cost
                )
            }
        }
        
        return breakdown
    }
}