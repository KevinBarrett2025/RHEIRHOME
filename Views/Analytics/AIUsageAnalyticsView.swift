import SwiftUI

struct AIUsageAnalyticsView: View {
    let organization: Organization
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Placeholder for now - will implement full analytics once services are working
                    VStack {
                        Text("AI Usage Analytics")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Coming Soon")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Advanced AI usage tracking and cost analytics for your \(organization.subscriptionTier.displayName) subscription.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("AI Usage Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    AIUsageAnalyticsView(organization: Organization(
        name: "Sample Organization"
    ))
}