import SwiftUI

struct ProjectBudgetTabView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @Binding var selectedTab: Tab
    private let releaseProfile = AppReleaseProfile.current
    @State private var selectedBudgetTab: BudgetTab = .breakdown
    
    private enum BudgetTab: String, CaseIterable {
        case breakdown = "Breakdown"
        case vendors = "Vendors"
        case payments = "Payments"
        
        var icon: String {
            switch self {
            case .breakdown: return "chart.pie.fill"
            case .vendors: return "building.2.fill"
            case .payments: return "creditcard.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            customTabBar
            
            // Tab content
            TabView(selection: $selectedBudgetTab) {
                BudgetBreakdownView(selectedTab: $selectedTab)
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
                    .tag(BudgetTab.breakdown)

                if !releaseProfile.shouldHideAdvancedBudgetSurfaces {
                    SpendingByVendorView()
                        .environmentObject(projectVM)
                        .environmentObject(authVM)
                        .tag(BudgetTab.vendors)

                    SpendingByPaymentMethodView()
                        .environmentObject(projectVM)
                        .environmentObject(authVM)
                        .tag(BudgetTab.payments)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationBarHidden(true)
        .onAppear {
            if !availableTabs.contains(selectedBudgetTab) {
                selectedBudgetTab = .breakdown
            }
        }
    }
    
    @ViewBuilder
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(availableTabs, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedBudgetTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                            .foregroundColor(selectedBudgetTab == tab ? .blue : .secondary)
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedBudgetTab == tab ? .blue : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedBudgetTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }

    private var availableTabs: [BudgetTab] {
        releaseProfile.shouldHideAdvancedBudgetSurfaces ? [.breakdown] : BudgetTab.allCases
    }
}

#Preview {
    ProjectBudgetTabView(selectedTab: .constant(.projects))
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
        .environmentObject(AuthViewModel(service: CloudKitAuthService()))
}
