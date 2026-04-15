import SwiftUI

/// Beautiful subscription tier badge component matching the app's design
struct SubscriptionBadgeView: View {
    let tier: SubscriptionTier
    let size: BadgeSize
    let showLabel: Bool
    
    enum BadgeSize {
        case small, medium, large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 48
            case .large: return 64
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 32
            }
        }
        
        var fontSize: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .subheadline
            }
        }
    }
    
    public init(tier: SubscriptionTier, size: BadgeSize = .medium, showLabel: Bool = true) {
        self.tier = tier
        self.size = size
        self.showLabel = showLabel
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Badge Circle
            Circle()
                .fill(tier.badgeGradient)
                .frame(width: size.dimension, height: size.dimension)
                .overlay(
                    Image(systemName: tier.badgeIcon)
                        .font(.system(size: size.iconSize, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                )
                .overlay(
                    Circle()
                        .stroke(tier.badgeColor.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: tier.badgeColor.opacity(0.4), radius: 4, x: 0, y: 2)
            
            // Label
            if showLabel {
                Text(tier.displayName.uppercased())
                    .font(size.fontSize)
                    .fontWeight(.bold)
                    .foregroundColor(tier.badgeColor)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// Inline subscription badge for compact displays
struct InlineSubscriptionBadge: View {
    let tier: SubscriptionTier
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tier.badgeColor)
                .frame(width: 16, height: 16)
                .overlay(
                    Image(systemName: tier.badgeIcon)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                )
            
            Text(tier.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(tier.badgeColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tier.badgeColor.opacity(0.1))
        .cornerRadius(12)
    }
}

/// Enhanced subscription card with badge and features
struct SubscriptionTierCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 16) {
                // Badge
                SubscriptionBadgeView(tier: tier, size: .large)
                
                // Price
                VStack(spacing: 4) {
                    if tier.monthlyPrice == 0 {
                        Text("FREE")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    } else {
                        Text("$\(Int(tier.monthlyPrice))")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("per month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Key Features
                VStack(alignment: .leading, spacing: 8) {
                    SubscriptionCardFeatureRow(text: tier.projectLimitDisplay == "∞" ? "Unlimited projects" : "Up to \(tier.maxProjects) projects")
                    SubscriptionCardFeatureRow(text: tier.teamMemberLimitDisplay == "∞" ? "Unlimited team members" : "Up to \(tier.maxTeamMembers) team members")
                    SubscriptionCardFeatureRow(text: tier.features.first { $0.contains("reporting") || $0.contains("analytics") } ?? tier.features.last!)
                    
                    if tier.features.count > 3 {
                        Text("+ \(tier.features.count - 3) more features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Select Button
                Button("Select \(tier.displayName)") {
                    onSelect()
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(tier.badgeColor)
                .cornerRadius(25)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 320)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? tier.badgeColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct SubscriptionCardFeatureRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            SubscriptionBadgeView(tier: .builder)
            SubscriptionBadgeView(tier: .professional)
            SubscriptionBadgeView(tier: .enterprise)
        }
        
        HStack {
            InlineSubscriptionBadge(tier: .professional)
            InlineSubscriptionBadge(tier: .enterprise)
        }
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(SubscriptionTier.modernTiers, id: \.self) { tier in
                    SubscriptionTierCard(tier: tier, isSelected: tier == .professional) { }
                    .frame(width: 200)
                }
            }
            .padding(.horizontal)
        }
    }
    .padding()
}
