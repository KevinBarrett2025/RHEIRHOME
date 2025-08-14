import SwiftUI
import Combine

/// Centralized navigation coordinator for managing complex navigation flows
@MainActor
public final class NavigationCoordinator: ObservableObject {
    // MARK: - Published Navigation States
    @Published public var selectedTab: Tab = .projects
    @Published public var projectDetailPath = NavigationPath()
    @Published public var receiptDetailPath = NavigationPath()
    @Published public var laborDetailPath = NavigationPath()
    @Published public var progressDetailPath = NavigationPath()
    
    // MARK: - Presentation States
    @Published public var showNewProject = false
    @Published public var showSettings = false
    @Published public var showInviteStatus = false
    @Published public var showCloudKitTest = false
    
    public init() {}
    
    // MARK: - Navigation Actions
    
    public func navigateToProjectDetail(project: Project) {
        selectedTab = .projects
        projectDetailPath.append(NavigationDestination.projectDetail(project))
    }
    
    public func navigateToBudgetBreakdown() {
        projectDetailPath.append(NavigationDestination.budgetBreakdown)
    }
    
    public func navigateToReceiptDetail(receipt: Receipt) {
        selectedTab = .receipts
        receiptDetailPath.append(NavigationDestination.receiptDetail(receipt))
    }
    
    public func navigateToLaborDetail(employee: Employee) {
        selectedTab = .labor
        laborDetailPath.append(NavigationDestination.laborDetail(employee))
    }
    
    public func navigateToProgressDetail(log: ProgressLog) {
        selectedTab = .progress
        progressDetailPath.append(NavigationDestination.progressDetail(log))
    }
    
    // MARK: - Modal Presentations
    
    public func presentNewProject() {
        showNewProject = true
    }
    
    public func presentSettings() {
        showSettings = true
    }
    
    public func presentInviteStatus() {
        showInviteStatus = true
    }
    
    public func presentCloudKitTest() {
        showCloudKitTest = true
    }
    
    // MARK: - Navigation Helpers
    
    public func popToRoot(for tab: Tab) {
        switch tab {
        case .projects:
            projectDetailPath = NavigationPath()
        case .receipts:
            receiptDetailPath = NavigationPath()
        case .labor:
            laborDetailPath = NavigationPath()
        case .progress:
            progressDetailPath = NavigationPath()
        default:
            break
        }
    }
    
    public func dismissAllModals() {
        showNewProject = false
        showSettings = false
        showInviteStatus = false
        showCloudKitTest = false
    }
}

// MARK: - Navigation Destinations
public enum NavigationDestination: Hashable {
    case projectDetail(Project)
    case budgetBreakdown
    case receiptDetail(Receipt)
    case laborDetail(Employee)
    case progressDetail(ProgressLog)
    case editProject(Project)
    case addProgress
    case employeeHours(Employee)
}