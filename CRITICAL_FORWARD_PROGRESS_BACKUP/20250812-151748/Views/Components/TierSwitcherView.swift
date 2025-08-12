import SwiftUI

/// Development tier switcher for testing subscription features across all tiers
struct TierSwitcherView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var selectedTier: SubscriptionTier
    @State private var showingTierComparison = false
    @State private var isUpdating = false
    
    init() {
        // Initialize with current tier or default to free
        let currentTier = UserDefaults.standard.string(forKey: "dev_subscription_tier").flatMap(SubscriptionTier.init(rawValue:)) ?? .free
        _selectedTier = State(initialValue: currentTier)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundColor(currentTierColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tier Testing")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Development Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Compare") {
                    showingTierComparison = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            // Current Tier Display
            currentTierDisplay
            
            // Tier Selector
            tierSelector
            
            // Feature Preview
            featurePreview
            
            // Usage Indicators
            usageIndicators
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(currentTierColor.opacity(0.3), lineWidth: 2)
        )
        .sheet(isPresented: $showingTierComparison) {
            TierComparisonView()
        }
        .onChange(of: selectedTier) { _, newTier in
            updateTier(newTier)
        }
    }
    
    @ViewBuilder
    private var currentTierDisplay: some View {
        HStack {
            // Tier Badge
            HStack(spacing: 6) {
                Image(systemName: tierIcon(selectedTier))
                    .font(.title3)
                    .foregroundColor(.white)
                
                Text(selectedTier.displayName.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(currentTierColor.gradient)
            .clipShape(Capsule())
            
            Spacer()
            
            // Pricing
            VStack(alignment: .trailing, spacing: 2) {
                if selectedTier.monthlyPrice > 0 {
                    Text("$\(String(format: "%.0f", selectedTier.monthlyPrice))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(currentTierColor)
                    
                    Text("per month")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("FREE")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(currentTierColor)
                }
            }
        }
    }
    
    @ViewBuilder
    private var tierSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Different Tiers:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Picker("Subscription Tier", selection: $selectedTier) {
                ForEach(SubscriptionTier.modernTiers, id: \.self) { tier in
                    HStack {
                        Image(systemName: tierIcon(tier))
                        Text(tier.displayName)
                        Spacer()
                        if tier.monthlyPrice > 0 {
                            Text("$\(String(format: "%.0f", tier.monthlyPrice))/mo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(tier)
                }
            }
            .pickerStyle(.menu)
            .disabled(isUpdating)
            
            if isUpdating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Updating tier...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var featurePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundColor(currentTierColor)
                
                Text("Available Features")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], alignment: .leading, spacing: 8) {
                ForEach(Array(selectedTier.features.prefix(4)), id: \.self) { feature in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        Text(feature)
                            .font(.caption2)
                            .lineLimit(2)
                    }
                }
            }
            
            if selectedTier.features.count > 4 {
                Button("View All \(selectedTier.features.count) Features") {
                    showingTierComparison = true
                }
                .font(.caption)
                .foregroundColor(currentTierColor)
            }
        }
        .padding()
        .background(currentTierColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var usageIndicators: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                Text("Usage Limits")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack(spacing: 16) {
                usageIndicator("Projects", current: 2, max: selectedTier.maxProjects, color: .blue)
                usageIndicator("Team", current: 3, max: selectedTier.maxTeamMembers, color: .green)
            }
            
            // AI Features Indicator
            if selectedTier != .free {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundColor(.purple)
                    
                    Text("AI Features: Enabled")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    if selectedTier == .enterprise {
                        Text("Unlimited")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    } else {
                        Text("Limited")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func usageIndicator(_ title: String, current: Int, max: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if max == Int.max {
                HStack(spacing: 2) {
                    Text("\(current)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    
                    Text("∞")
                        .font(.caption)
                        .foregroundColor(color)
                }
            } else {
                HStack(spacing: 2) {
                    Text("\(current)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    
                    Text("/ \(max)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: Double(current), total: Double(max))
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .scaleEffect(y: 0.5)
            }
        }
    }
    
    private var currentTierColor: Color {
        tierColor(selectedTier)
    }
    
    private func tierColor(_ tier: SubscriptionTier) -> Color {
        switch tier {
        case .free, .starter: return .gray
        case .professional, .standard: return .blue
        case .enterprise, .premium: return .purple
        }
    }
    
    private func tierIcon(_ tier: SubscriptionTier) -> String {
        switch tier {
        case .free, .starter: return "person.fill"
        case .professional, .standard: return "briefcase.fill"
        case .enterprise, .premium: return "crown.fill"
        }
    }
    
    private func updateTier(_ newTier: SubscriptionTier) {
        guard !isUpdating else { return }
        
        isUpdating = true
        
        // Store in UserDefaults for development
        UserDefaults.standard.set(newTier.rawValue, forKey: "dev_subscription_tier")
        
        // Update the organization's subscription tier
        authVM.updateSubscriptionTier(newTier)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isUpdating = false
        }
    }
}

/// Comprehensive tier comparison modal
struct TierComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var selectedTier: SubscriptionTier?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Choose Your Plan")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Compare features across all subscription tiers")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Tier Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(SubscriptionTier.modernTiers, id: \.self) { tier in
                            tierComparisonCard(tier)
                        }
                    }
                    
                    // Feature Comparison Table
                    featureComparisonTable
                }
                .padding()
            }
            .navigationTitle("Tier Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private func tierComparisonCard(_ tier: SubscriptionTier) -> some View {
        VStack(spacing: 12) {
            // Tier Header
            VStack(spacing: 8) {
                Image(systemName: tierIcon(tier))
                    .font(.title2)
                    .foregroundColor(tierColor(tier))
                
                Text(tier.displayName)
                    .font(.headline)
                    .fontWeight(.bold)
                
                if tier.monthlyPrice > 0 {
                    VStack(spacing: 2) {
                        Text("$\(String(format: "%.0f", tier.monthlyPrice))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(tierColor(tier))
                        
                        Text("per month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("FREE")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(tierColor(tier))
                }
            }
            
            // Key Features
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(tier.features.prefix(3)), id: \.self) { feature in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(feature)
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
                
                if tier.features.count > 3 {
                    Text("+ \(tier.features.count - 3) more features")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Select Button
            Button("Select \(tier.displayName)") {
                selectedTier = tier
                authVM.updateSubscriptionTier(tier)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(tierColor(tier).opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tierColor(tier).opacity(0.3), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private var featureComparisonTable: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Feature Comparison")
                .font(.title2)
                .fontWeight(.bold)
            
            let features = [
                ("Projects", ["Up to 3", "Unlimited", "Unlimited"]),
                ("Team Members", ["Up to 2", "Up to 10", "Unlimited"]),
                ("AI Features", ["Basic", "Advanced", "Premium"]),
                ("Support", ["Community", "Email", "Priority + Phone"]),
                ("Data Retention", ["30 days", "1 year", "Unlimited"]),
                ("API Access", ["❌", "❌", "✅"]),
                ("Custom Integrations", ["❌", "❌", "✅"])
            ]
            
            VStack(spacing: 0) {
                // Header Row
                HStack {
                    Text("Feature")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Free")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                    
                    Text("Professional")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                    
                    Text("Enterprise")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(.systemGray5))
                
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack {
                        Text(feature.0)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ForEach(Array(feature.1.enumerated()), id: \.offset) { tierIndex, value in
                            Text(value)
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(index % 2 == 0 ? Color(.systemGray6) : Color(.systemBackground))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    private func tierColor(_ tier: SubscriptionTier) -> Color {
        switch tier {
        case .free, .starter: return .gray
        case .professional, .standard: return .blue
        case .enterprise, .premium: return .purple
        }
    }
    
    private func tierIcon(_ tier: SubscriptionTier) -> String {
        switch tier {
        case .free, .starter: return "person.fill"
        case .professional, .standard: return "briefcase.fill"
        case .enterprise, .premium: return "crown.fill"
        }
    }
}

#Preview {
    VStack {
        TierSwitcherView()
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
        
        Spacer()
    }
    .padding()
}