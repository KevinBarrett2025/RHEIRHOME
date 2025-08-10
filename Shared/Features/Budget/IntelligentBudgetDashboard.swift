import SwiftUI
import Charts

// MARK: - Phase 2G Intelligent Budget Dashboard
struct IntelligentBudgetDashboard: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    let project: Project
    
    @State private var showingPredictiveAnalytics = false
    @State private var showingTeamIntelligence = false
    @State private var showingTimelineAnalysis = false
    
    // MARK: - Intelligent Analytics Properties
    
    private var projectHealthScore: Double {
        calculateProjectHealthScore()
    }
    
    private var budgetVariancePrediction: BudgetVariancePrediction {
        predictBudgetVariance()
    }
    
    private var timelineIntelligence: TimelineIntelligence {
        analyzeTimelineIntelligence()
    }
    
    private var teamEfficiencyMetrics: TeamEfficiencyMetrics {
        calculateTeamEfficiencyMetrics()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Intelligence Header
                intelligenceHeaderSection
                
                // Project Health Score
                projectHealthSection
                
                // Predictive Budget Analytics
                predictiveBudgetSection
                
                // Timeline Intelligence
                timelineIntelligenceSection
                
                // Team Performance Analytics
                teamPerformanceSection
                
                // Smart Recommendations
                smartRecommendationsSection
            }
            .padding()
        }
        .navigationTitle("Intelligent Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPredictiveAnalytics) {
            PredictiveBudgetAnalyticsView(project: project)
                .environmentObject(projectVM)
        }
        .sheet(isPresented: $showingTeamIntelligence) {
            TeamIntelligenceAnalyticsView(project: project)
                .environmentObject(projectVM)
        }
        .sheet(isPresented: $showingTimelineAnalysis) {
            TimelineAnalysisView(project: project)
                .environmentObject(projectVM)
        }
    }
    
    // MARK: - UI Sections
    
    @ViewBuilder
    private var intelligenceHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI-Powered Insights")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("for \(project.name)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Real-time indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Live")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            // Quick Intelligence Summary
            HStack {
                IntelligenceMetricCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Health Score",
                    value: "\(Int(projectHealthScore))%",
                    color: healthScoreColor
                )
                
                IntelligenceMetricCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Efficiency",
                    value: "\(Int(teamEfficiencyMetrics.overallEfficiency * 100))%",
                    color: .blue
                )
                
                IntelligenceMetricCard(
                    icon: "clock.arrow.circlepath",
                    title: "Timeline Risk",
                    value: timelineIntelligence.riskLevel.displayName,
                    color: timelineIntelligence.riskLevel.color
                )
            }
        }
    }
    
    @ViewBuilder
    private var projectHealthSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "stethoscope")
                    .foregroundColor(.green)
                Text("Project Health Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Health Score Gauge
                ProjectHealthGauge(score: projectHealthScore)
                
                // Health Factors
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    HealthFactorCard(
                        title: "Budget Health",
                        score: calculateBudgetHealth(),
                        icon: "dollarsign.circle",
                        description: budgetHealthDescription
                    )
                    
                    HealthFactorCard(
                        title: "Timeline Health",
                        score: calculateTimelineHealth(),
                        icon: "calendar.badge.clock",
                        description: timelineHealthDescription
                    )
                    
                    HealthFactorCard(
                        title: "Team Health",
                        score: calculateTeamHealth(),
                        icon: "person.2.fill",
                        description: teamHealthDescription
                    )
                    
                    HealthFactorCard(
                        title: "Quality Health",
                        score: calculateQualityHealth(),
                        icon: "checkmark.seal",
                        description: qualityHealthDescription
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    @ViewBuilder
    private var predictiveBudgetSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "crystal.ball")
                    .foregroundColor(.purple)
                Text("Predictive Budget Analytics")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Button("View Details") {
                    showingPredictiveAnalytics = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                // Budget Prediction Chart
                BudgetPredictionChart(prediction: budgetVariancePrediction)
                
                // Prediction Summary
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Predicted Final Cost")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(budgetVariancePrediction.predictedFinalCost.formatAsCurrency())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(budgetVariancePrediction.isOverBudget ? .red : .green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Variance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(budgetVariancePrediction.varianceDescription)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(budgetVariancePrediction.isOverBudget ? .red : .green)
                    }
                }
                
                // Confidence Indicator
                HStack {
                    Text("Prediction Confidence:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(budgetVariancePrediction.confidence * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    @ViewBuilder
    private var timelineIntelligenceSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.2.circlepath")
                    .foregroundColor(.orange)
                Text("Timeline Intelligence")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Button("Analyze") {
                    showingTimelineAnalysis = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                // Timeline Risk Assessment
                TimelineRiskIndicator(intelligence: timelineIntelligence)
                
                // Critical Path Analysis
                CriticalPathSummary(intelligence: timelineIntelligence)
                
                // Delay Predictions
                if !timelineIntelligence.potentialDelays.isEmpty {
                    DelayPredictionsCard(delays: timelineIntelligence.potentialDelays)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    @ViewBuilder
    private var teamPerformanceSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.2.badge.gearshape")
                    .foregroundColor(.blue)
                Text("Team Performance Analytics")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Button("Deep Dive") {
                    showingTeamIntelligence = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                // Team Efficiency Overview
                TeamEfficiencyOverview(metrics: teamEfficiencyMetrics)
                
                // Top Performers
                TopPerformersCard(metrics: teamEfficiencyMetrics)
                
                // Workload Balance
                WorkloadBalanceIndicator(metrics: teamEfficiencyMetrics)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    @ViewBuilder
    private var smartRecommendationsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Smart Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(generateSmartRecommendations(), id: \.id) { recommendation in
                    SmartRecommendationCard(recommendation: recommendation)
                }
            }
        }
    }
    
    // MARK: - Intelligence Calculations
    
    private func calculateProjectHealthScore() -> Double {
        let budgetHealth = calculateBudgetHealth()
        let timelineHealth = calculateTimelineHealth()
        let teamHealth = calculateTeamHealth()
        let qualityHealth = calculateQualityHealth()
        
        // Weighted average (budget and timeline are most important)
        let weightedScore = (budgetHealth * 0.3) + 
                           (timelineHealth * 0.3) + 
                           (teamHealth * 0.25) + 
                           (qualityHealth * 0.15)
        
        return min(max(weightedScore, 0), 100)
    }
    
    private func calculateBudgetHealth() -> Double {
        let spent = projectVM.calculateTotalSpent(for: project)
        let budget = project.totalBudget
        
        guard budget > 0 else { return 0 }
        
        let percentageUsed = spent / budget
        
        if percentageUsed <= 0.7 {
            return 100 // Excellent
        } else if percentageUsed <= 0.85 {
            return 80 // Good
        } else if percentageUsed <= 1.0 {
            return 60 // Fair
        } else if percentageUsed <= 1.15 {
            return 30 // Poor
        } else {
            return 10 // Critical
        }
    }
    
    private func calculateTimelineHealth() -> Double {
        let now = Date()
        let startDate = project.startDate
        let endDate = project.endDate
        
        let totalDuration = endDate.timeIntervalSince(startDate)
        let elapsed = now.timeIntervalSince(startDate)
        let remaining = endDate.timeIntervalSince(now)
        
        guard totalDuration > 0 else { return 100 }
        
        let progressPercentage = elapsed / totalDuration
        
        if remaining > totalDuration * 0.3 {
            return 100 // Plenty of time
        } else if remaining > totalDuration * 0.15 {
            return 80 // On track
        } else if remaining > 0 {
            return 50 // Tight timeline
        } else {
            return 20 // Overdue
        }
    }
    
    private func calculateTeamHealth() -> Double {
        let teamMembers = projectVM.getProjectTeamMembers(for: project)
        
        guard !teamMembers.isEmpty else { return 0 }
        
        let activeMembers = teamMembers.filter { $0.employmentStatus == .active }
        let memberUtilization = calculateTeamUtilization()
        
        let activeRatio = Double(activeMembers.count) / Double(teamMembers.count)
        
        return (activeRatio * 50) + (memberUtilization * 50)
    }
    
    private func calculateQualityHealth() -> Double {
        // Base quality score on various factors
        let hasRecentProgress = project.progressReports.contains { report in
            report.date > Date().addingTimeInterval(-7 * 24 * 60 * 60) // Last 7 days
        }
        
        let hasRegularReceipts = project.receipts.count > 0
        let hasTeamActivity = !projectVM.getProjectTeamMembers(for: project).isEmpty
        
        var score: Double = 0
        
        if hasRecentProgress { score += 40 }
        if hasRegularReceipts { score += 30 }
        if hasTeamActivity { score += 30 }
        
        return score
    }
    
    private func calculateTeamUtilization() -> Double {
        // Simplified team utilization calculation
        let teamMembers = projectVM.getProjectTeamMembers(for: project)
        
        guard !teamMembers.isEmpty else { return 0 }
        
        let totalHours = project.loggedHours.reduce(0) { $0 + $1.hoursWorked }
        let averageHoursPerMember = totalHours / Double(teamMembers.count)
        
        // Assume optimal is around 40 hours per week, scale accordingly
        let optimalHours = 40.0
        return min(averageHoursPerMember / optimalHours, 1.0) * 100
    }
    
    private func predictBudgetVariance() -> BudgetVariancePrediction {
        let currentSpent = projectVM.calculateTotalSpent(for: project)
        let totalBudget = project.totalBudget
        
        let now = Date()
        let totalDuration = project.endDate.timeIntervalSince(project.startDate)
        let elapsed = now.timeIntervalSince(project.startDate)
        
        guard totalDuration > 0, elapsed > 0 else {
            return BudgetVariancePrediction(
                predictedFinalCost: totalBudget,
                variance: 0,
                confidence: 0.5
            )
        }
        
        let progressRatio = elapsed / totalDuration
        let spendRate = currentSpent / elapsed
        
        // Predict final cost based on current spending rate
        let predictedFinalCost = spendRate * totalDuration
        let variance = predictedFinalCost - totalBudget
        
        // Confidence based on data quality and project progress
        let confidence = min(max(progressRatio, 0.1), 0.9)
        
        return BudgetVariancePrediction(
            predictedFinalCost: predictedFinalCost,
            variance: variance,
            confidence: confidence
        )
    }
    
    private func analyzeTimelineIntelligence() -> TimelineIntelligence {
        let now = Date()
        let endDate = project.endDate
        let remaining = endDate.timeIntervalSince(now)
        
        // Determine risk level
        let riskLevel: TimelineRiskLevel
        if remaining < 0 {
            riskLevel = .critical
        } else if remaining < 7 * 24 * 60 * 60 { // Less than a week
            riskLevel = .high
        } else if remaining < 30 * 24 * 60 * 60 { // Less than a month
            riskLevel = .medium
        } else {
            riskLevel = .low
        }
        
        // Analyze potential delays
        let potentialDelays = analyzePotentialDelays()
        
        return TimelineIntelligence(
            riskLevel: riskLevel,
            daysRemaining: Int(max(remaining / (24 * 60 * 60), 0)),
            potentialDelays: potentialDelays,
            criticalPath: identifyCriticalPath()
        )
    }
    
    private func calculateTeamEfficiencyMetrics() -> TeamEfficiencyMetrics {
        let teamMembers = projectVM.getProjectTeamMembers(for: project)
        
        guard !teamMembers.isEmpty else {
            return TeamEfficiencyMetrics(
                overallEfficiency: 0,
                topPerformers: [],
                workloadBalance: 0
            )
        }
        
        // Calculate individual performance metrics
        let performanceMetrics = teamMembers.map { member in
            IndividualPerformanceMetric(
                member: member,
                productivity: calculateMemberProductivity(member),
                hoursLogged: getMemberHours(member),
                tasksCompleted: getMemberTasksCompleted(member)
            )
        }
        
        let overallEfficiency = performanceMetrics.reduce(0) { $0 + $1.productivity } / Double(performanceMetrics.count)
        let topPerformers = performanceMetrics.sorted { $0.productivity > $1.productivity }.prefix(3)
        
        return TeamEfficiencyMetrics(
            overallEfficiency: overallEfficiency / 100, // Normalize to 0-1
            topPerformers: Array(topPerformers),
            workloadBalance: calculateWorkloadBalance(performanceMetrics)
        )
    }
    
    private func generateSmartRecommendations() -> [SmartRecommendation] {
        var recommendations: [SmartRecommendation] = []
        
        // Budget recommendations
        if budgetVariancePrediction.isOverBudget {
            recommendations.append(SmartRecommendation(
                id: UUID(),
                type: .budget,
                priority: .high,
                title: "Budget Overrun Risk Detected",
                description: "Current spending trends suggest a potential budget overrun of \(abs(budgetVariancePrediction.variance).formatAsCurrency()). Consider reviewing expenses and optimizing costs.",
                actionItems: [
                    "Review recent high-value purchases",
                    "Negotiate better rates with frequent vendors",
                    "Consider alternative materials or methods"
                ]
            ))
        }
        
        // Timeline recommendations
        if timelineIntelligence.riskLevel == .high || timelineIntelligence.riskLevel == .critical {
            recommendations.append(SmartRecommendation(
                id: UUID(),
                type: .timeline,
                priority: .high,
                title: "Timeline Risk Identified",
                description: "Project timeline is at risk. Consider accelerating critical path activities or reallocating resources.",
                actionItems: [
                    "Focus on critical path tasks",
                    "Add additional team members to key activities",
                    "Consider working overtime or weekends"
                ]
            ))
        }
        
        // Team recommendations
        if teamEfficiencyMetrics.overallEfficiency < 0.7 {
            recommendations.append(SmartRecommendation(
                id: UUID(),
                type: .team,
                priority: .medium,
                title: "Team Efficiency Opportunity",
                description: "Team efficiency is below optimal levels. Consider training, better tools, or workload redistribution.",
                actionItems: [
                    "Provide additional training or tools",
                    "Review and balance workload distribution",
                    "Improve communication and coordination"
                ]
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Helper Properties
    
    private var healthScoreColor: Color {
        if projectHealthScore >= 80 {
            return .green
        } else if projectHealthScore >= 60 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var budgetHealthDescription: String {
        let health = calculateBudgetHealth()
        if health >= 80 { return "Excellent budget control" }
        else if health >= 60 { return "Good budget management" }
        else if health >= 40 { return "Budget needs attention" }
        else { return "Critical budget situation" }
    }
    
    private var timelineHealthDescription: String {
        let health = calculateTimelineHealth()
        if health >= 80 { return "On track for completion" }
        else if health >= 60 { return "Manageable timeline" }
        else if health >= 40 { return "Timeline pressure" }
        else { return "Critical timeline risk" }
    }
    
    private var teamHealthDescription: String {
        let health = calculateTeamHealth()
        if health >= 80 { return "High-performing team" }
        else if health >= 60 { return "Good team dynamics" }
        else if health >= 40 { return "Team needs support" }
        else { return "Team restructuring needed" }
    }
    
    private var qualityHealthDescription: String {
        let health = calculateQualityHealth()
        if health >= 80 { return "High quality standards" }
        else if health >= 60 { return "Good quality control" }
        else if health >= 40 { return "Quality improvements needed" }
        else { return "Quality issues present" }
    }
    
    // MARK: - Helper Methods (Stubs for now)
    
    private func analyzePotentialDelays() -> [PotentialDelay] {
        // TODO: Implement advanced delay analysis
        return []
    }
    
    private func identifyCriticalPath() -> [CriticalPathItem] {
        // TODO: Implement critical path analysis
        return []
    }
    
    private func calculateMemberProductivity(_ member: TeamMember) -> Double {
        // TODO: Implement productivity calculation
        return 75.0 // Placeholder
    }
    
    private func getMemberHours(_ member: TeamMember) -> Double {
        return project.loggedHours
            .filter { $0.employeeID == member.id }
            .reduce(0) { $0 + $1.hoursWorked }
    }
    
    private func getMemberTasksCompleted(_ member: TeamMember) -> Int {
        // TODO: Implement task completion tracking
        return 5 // Placeholder
    }
    
    private func calculateWorkloadBalance(_ metrics: [IndividualPerformanceMetric]) -> Double {
        // TODO: Implement workload balance calculation
        return 0.8 // Placeholder
    }
}

// MARK: - Intelligence Data Models

struct BudgetVariancePrediction {
    let predictedFinalCost: Double
    let variance: Double
    let confidence: Double
    
    var isOverBudget: Bool {
        return variance > 0
    }
    
    var varianceDescription: String {
        if isOverBudget {
            return "+\(variance.formatAsCurrency())"
        } else {
            return "\(variance.formatAsCurrency())"
        }
    }
}

struct TimelineIntelligence {
    let riskLevel: TimelineRiskLevel
    let daysRemaining: Int
    let potentialDelays: [PotentialDelay]
    let criticalPath: [CriticalPathItem]
}

enum TimelineRiskLevel {
    case low, medium, high, critical
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct TeamEfficiencyMetrics {
    let overallEfficiency: Double
    let topPerformers: [IndividualPerformanceMetric]
    let workloadBalance: Double
}

struct IndividualPerformanceMetric {
    let member: TeamMember
    let productivity: Double
    let hoursLogged: Double
    let tasksCompleted: Int
}

struct SmartRecommendation {
    let id: UUID
    let type: RecommendationType
    let priority: RecommendationPriority
    let title: String
    let description: String
    let actionItems: [String]
}

enum RecommendationType {
    case budget, timeline, team, quality
    
    var icon: String {
        switch self {
        case .budget: return "dollarsign.circle"
        case .timeline: return "clock"
        case .team: return "person.2"
        case .quality: return "checkmark.seal"
        }
    }
    
    var color: Color {
        switch self {
        case .budget: return .green
        case .timeline: return .orange
        case .team: return .blue
        case .quality: return .purple
        }
    }
}

enum RecommendationPriority {
    case low, medium, high, critical
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct PotentialDelay {
    let id: UUID
    let description: String
    let estimatedDays: Int
    let probability: Double
}

struct CriticalPathItem {
    let id: UUID
    let taskName: String
    let duration: Int
    let dependencies: [UUID]
}

// MARK: - Intelligence UI Components (Stubs)

// These would be implemented as separate components
struct IntelligenceMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProjectHealthGauge: View {
    let score: Double
    
    var body: some View {
        // TODO: Implement circular gauge
        Text("Health: \(Int(score))%")
            .font(.title2)
            .fontWeight(.bold)
    }
}

struct HealthFactorCard: View {
    let title: String
    let score: Double
    let icon: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text("\(Int(score))%")
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct BudgetPredictionChart: View {
    let prediction: BudgetVariancePrediction
    
    var body: some View {
        // TODO: Implement Chart view
        Text("Budget Prediction Chart")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
}

struct TimelineRiskIndicator: View {
    let intelligence: TimelineIntelligence
    
    var body: some View {
        HStack {
            Text("Risk Level:")
                .font(.subheadline)
            Spacer()
            Text(intelligence.riskLevel.displayName)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(intelligence.riskLevel.color)
        }
    }
}

struct CriticalPathSummary: View {
    let intelligence: TimelineIntelligence
    
    var body: some View {
        Text("Critical Path Analysis")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
}

struct DelayPredictionsCard: View {
    let delays: [PotentialDelay]
    
    var body: some View {
        Text("Potential Delays: \(delays.count)")
            .font(.subheadline)
    }
}

struct TeamEfficiencyOverview: View {
    let metrics: TeamEfficiencyMetrics
    
    var body: some View {
        Text("Team Efficiency: \(Int(metrics.overallEfficiency * 100))%")
            .font(.subheadline)
    }
}

struct TopPerformersCard: View {
    let metrics: TeamEfficiencyMetrics
    
    var body: some View {
        Text("Top Performers: \(metrics.topPerformers.count)")
            .font(.subheadline)
    }
}

struct WorkloadBalanceIndicator: View {
    let metrics: TeamEfficiencyMetrics
    
    var body: some View {
        Text("Workload Balance: \(Int(metrics.workloadBalance * 100))%")
            .font(.subheadline)
    }
}

struct SmartRecommendationCard: View {
    let recommendation: SmartRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: recommendation.type.icon)
                    .foregroundColor(recommendation.type.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(recommendation.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Circle()
                    .fill(recommendation.priority.color)
                    .frame(width: 8, height: 8)
            }
            
            if !recommendation.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended Actions:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(recommendation.actionItems.prefix(3), id: \.self) { item in
                        Text("• \(item)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Placeholder Views for Detail Sheets

struct PredictiveBudgetAnalyticsView: View {
    let project: Project
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Detailed Predictive Budget Analytics")
                .navigationTitle("Budget Analytics")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct TeamIntelligenceAnalyticsView: View {
    let project: Project
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Detailed Team Intelligence Analytics")
                .navigationTitle("Team Analytics")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct TimelineAnalysisView: View {
    let project: Project
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Detailed Timeline Analysis")
                .navigationTitle("Timeline Analysis")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}