import SwiftUI

struct SubscriptionTierSelectionView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: SubscriptionTier = .professional
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                    
                    // Tier Cards
                    tierCardsSection
                    
                    // Feature Comparison
                    featureComparisonSection
                }
                .padding()
            }
            .navigationTitle("Tier Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Choose Your Plan")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Compare features across all subscription tiers")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var tierCardsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(SubscriptionTier.modernTiers, id: \.self) { tier in
                    SubscriptionTierCard(
                        tier: tier,
                        isSelected: selectedTier == tier
                    ) {
                        selectedTier = tier
                        updateSubscriptionTier(tier)
                    }
                    .frame(width: 260)
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Feature Comparison")
                .font(.title2)
                .fontWeight(.bold)
            
            // Comparison Table
            VStack(spacing: 0) {
                // Header Row
                HStack(spacing: 12) {
                    Text("Feature")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(SubscriptionTier.modernTiers, id: \.self) { tier in
                        VStack(spacing: 4) {
                            SubscriptionBadgeView(tier: tier, size: .small, showLabel: false)
                            Text(tier.displayName.prefix(8))
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .frame(width: 70)
                    }
                }
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                Divider()
                
                // Feature Rows
                FeatureComparisonRow(
                    feature: "Projects",
                    values: SubscriptionTier.modernTiers.map { 
                        $0.maxProjects == Int.max ? "Unlimited" : "Up to \($0.maxProjects)" 
                    }
                )
                
                FeatureComparisonRow(
                    feature: "Team Members",
                    values: SubscriptionTier.modernTiers.map { 
                        $0.maxTeamMembers == Int.max ? "Unlimited" : "Up to \($0.maxTeamMembers)" 
                    }
                )
                
                FeatureComparisonRow(
                    feature: "Storage",
                    values: ["500MB", "5GB", "50GB"]
                )
                
                FeatureComparisonRow(
                    feature: "Data Retention",
                    values: ["30 days", "1 year", "Unlimited"]
                )
                
                FeatureComparisonRow(
                    feature: "Support",
                    values: ["Community", "Priority Email", "Dedicated"]
                )
                
                FeatureComparisonRow(
                    feature: "API Access",
                    values: ["❌", "Limited", "Full"]
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    private func updateSubscriptionTier(_ tier: SubscriptionTier) {
        authVM.updateSubscriptionTier(tier)
        
        // Show success feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

private struct FeatureComparisonRow: View {
    let feature: String
    let values: [String]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(feature)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    Text(value)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .frame(width: 70)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
            if feature != "API Access" { // Don't add divider after last row
                Divider()
            }
        }
    }
}

#Preview {
    SubscriptionTierSelectionView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
}