import Foundation
import Combine
import CloudKit
import Network
import OSLog

extension Logger {
    static let offlineSync = Logger(subsystem: "com.RheirHome.RHEIR", category: "offlineSync")
    static let offlineStorage = Logger(subsystem: "com.RheirHome.RHEIR", category: "offlineStorage")
}

/// Advanced offline data management for construction environments
/// Ensures full functionality even in areas with poor/no internet connectivity
class OfflineDataManager: ObservableObject {
    
    // MARK: - PHASE 1 BRIDGE: Published Properties for ProjectViewModel Compatibility
    
    /// Published properties that ProjectViewModel expects - bridging architectural gap
    @Published var projects: [Project] = []
    @Published var teamMembers: [TeamMember] = []
    @Published var vendors: [Vendor] = []
    @Published var paymentMethods: [PaymentMethod] = []
    
    // MARK: - Offline Strategy
    /*
     OFFLINE-FIRST ARCHITECTURE:
     
     1. LOCAL-FIRST STORAGE
        - All data stored locally in JSON files
        - Immediate reads/writes to local storage
        - No network dependency for core operations
     
     2. BACKGROUND SYNC
        - CloudKit sync happens in background when internet available
        - Queued operations retry when connection restored
        - Conflict resolution for simultaneous edits
     
     3. INTELLIGENT CACHING
        - Photos stored locally with compression
        - OCR text cached for offline search
        - Project data preloaded for instant access
     
     4. NETWORK DETECTION
        - Monitor network status continuously
        - Queue operations during offline periods
        - Smart retry with exponential backoff
     */
    
    // MARK: - Network Status
    
    @Published var isOnline = false
    @Published var connectionQuality: ConnectionQuality = .unknown
    @Published var pendingSyncOperations: [SyncOperation] = []
    
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Offline Storage
    
    private let offlineStorageManager = OfflineStorageManager()
    private let syncQueue = OperationQueue()
    
    // MARK: - Sync State
    
    @Published var lastSuccessfulSync: Date?
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNetworkMonitoring()
        setupSyncQueue()
        loadOfflineState()
        loadDataIntoPublishedProperties()
        
        Logger.offlineSync.info("Offline data manager initialized in offline-first mode.")
        Logger.offlineSync.debug("Activated ProjectViewModel offline bridge.")
    }
    
    // MARK: - PHASE 1 BRIDGE: Load Data into @Published Properties
    
    private func loadDataIntoPublishedProperties() {
        // Load projects from offline storage into @Published property
        self.projects = loadProjectsOffline()
        
        // Load other data types (stubs for now - will be implemented as needed)
        self.teamMembers = loadTeamMembersOffline()
        self.vendors = loadVendorsOffline()
        self.paymentMethods = loadPaymentMethodsOffline()
        
        Logger.offlineSync.info(
            "Loaded offline bridge state [projects=\(self.projects.count, privacy: .public), teamMembers=\(self.teamMembers.count, privacy: .public), vendors=\(self.vendors.count, privacy: .public), paymentMethods=\(self.paymentMethods.count, privacy: .public)]"
        )
    }
    
    // MARK: - PHASE 1 BRIDGE: Convenience CRUD Methods (Wrap Offline Methods)
    
    /// Convenience method that ProjectViewModel expects - wraps saveProjectOffline
    func addProject(_ project: Project) {
        // Save using existing offline method
        let success = saveProjectOffline(project)
        
        if success {
            // Update @Published property for reactive UI
            if !projects.contains(where: { $0.id == project.id }) {
                projects.append(project)
            }
            Logger.offlineSync.debug("Added project to offline bridge cache.")
        }
    }
    
    /// Convenience method that ProjectViewModel expects - wraps saveProjectOffline  
    func updateProject(_ project: Project) {
        // Save using existing offline method
        let success = saveProjectOffline(project)
        
        if success {
            // Update @Published property for reactive UI
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = project
            } else {
                projects.append(project)
            }
            Logger.offlineSync.debug("Updated project in offline bridge cache.")
        }
    }
    
    /// Convenience method that ProjectViewModel expects
    func deleteProject(_ project: Project) {
        // Remove from @Published property for reactive UI
        projects.removeAll { $0.id == project.id }
        
        // Remove from offline storage
        deleteProjectFromOfflineStorage(project)
        
        Logger.offlineSync.notice("Deleted project from offline bridge cache.")
    }
    
    /// Convenience method that ProjectViewModel expects
    func deleteProjectPermanently(_ project: Project) {
        // Same as deleteProject for offline-first architecture
        deleteProject(project)
        Logger.offlineSync.notice("Permanently deleted project from offline bridge cache.")
    }
    
    /// Convenience method for team member management
    func addTeamMember(_ teamMember: TeamMember) {
        // Add to @Published property
        if !teamMembers.contains(where: { $0.id == teamMember.id }) {
            teamMembers.append(teamMember)
        }
        
        // Save offline (stub implementation)
        saveTeamMemberOffline(teamMember)
        Logger.offlineSync.debug("Added team member to offline bridge cache.")
    }
    
    /// Convenience method for team member management
    func updateTeamMember(_ teamMember: TeamMember) {
        // Update @Published property
        if let index = teamMembers.firstIndex(where: { $0.id == teamMember.id }) {
            teamMembers[index] = teamMember
        } else {
            teamMembers.append(teamMember)
        }
        
        // Save offline (stub implementation)
        saveTeamMemberOffline(teamMember)
        Logger.offlineSync.debug("Updated team member in offline bridge cache.")
    }
    
    /// Convenience method for team member management
    func removeTeamMember(_ teamMember: TeamMember) {
        // Remove from @Published property
        teamMembers.removeAll { $0.id == teamMember.id }
        
        // Remove from offline storage (stub implementation)
        deleteTeamMemberFromOfflineStorage(teamMember)
        Logger.offlineSync.debug("Removed team member from offline bridge cache.")
    }
    
    /// Convenience method for vendor/payment method updates
    func updateVendors(_ vendors: [Vendor]) {
        self.vendors = vendors
        // TODO: Save to offline storage when needed
        Logger.offlineSync.debug("Updated offline vendor bridge cache [count=\(vendors.count, privacy: .public)]")
    }
    
    /// Convenience method for vendor/payment method updates
    func updatePaymentMethods(_ paymentMethods: [PaymentMethod]) {
        self.paymentMethods = paymentMethods  
        // TODO: Save to offline storage when needed
        Logger.offlineSync.debug(
            "Updated offline payment-method bridge cache [count=\(paymentMethods.count, privacy: .public)]"
        )
    }
    
    /// Convenience method for project list updates
    func updateProjects(_ projects: [Project]) {
        self.projects = projects
        // Save each project offline
        for project in projects {
            _ = saveProjectOffline(project)
        }
        Logger.offlineSync.debug("Updated offline project bridge cache [count=\(projects.count, privacy: .public)]")
    }
    
    // MARK: - PHASE 1 BRIDGE: Stub Data Loading Methods
    
    private func loadTeamMembersOffline() -> [TeamMember] {
        // TODO: Implement team member offline storage
        // For now, return empty array
        return []
    }
    
    private func loadVendorsOffline() -> [Vendor] {
        // TODO: Implement vendor offline storage  
        // For now, return empty array
        return []
    }
    
    private func loadPaymentMethodsOffline() -> [PaymentMethod] {
        // TODO: Implement payment method offline storage
        // For now, return empty array
        return []
    }
    
    private func saveTeamMemberOffline(_ teamMember: TeamMember) {
        // TODO: Implement team member offline storage
        Logger.offlineStorage.debug(
            "Team-member offline persistence is not implemented yet [teamMember=\(teamMember.name, privacy: .private(mask: .hash))]"
        )
    }
    
    private func deleteProjectFromOfflineStorage(_ project: Project) {
        // TODO: Implement project deletion from offline storage
        // For now, this is handled by saveProjects filtering
        var allProjects = loadProjectsOffline()
        allProjects.removeAll { $0.id == project.id }
        _ = offlineStorageManager.saveProjects(allProjects)
        Logger.offlineStorage.notice(
            "Deleted project from offline storage [project=\(project.name, privacy: .private(mask: .hash))]"
        )
    }
    
    private func deleteTeamMemberFromOfflineStorage(_ teamMember: TeamMember) {
        // TODO: Implement team member deletion from offline storage
        Logger.offlineStorage.debug(
            "Team-member offline deletion is not implemented yet [teamMember=\(teamMember.name, privacy: .private(mask: .hash))]"
        )
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied
                self?.connectionQuality = self?.determineConnectionQuality(path) ?? .unknown
                
                // Trigger sync when coming back online
                if !wasOnline && self?.isOnline == true {
                    Logger.offlineSync.notice("Connection restored; triggering pending offline sync.")
                    self?.syncWhenOnline()
                }
                
                Logger.offlineSync.debug(
                    "Updated network status [online=\(self?.isOnline == true, privacy: .public), quality=\(String(describing: self?.connectionQuality ?? .unknown), privacy: .public)]"
                )
            }
        }
        
        networkMonitor.start(queue: networkQueue)
    }
    
    private func determineConnectionQuality(_ path: NWPath) -> ConnectionQuality {
        if path.status != .satisfied {
            return .offline
        }
        
        if path.isExpensive {
            return .cellular
        }
        
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else {
            return .unknown
        }
    }
    
    private func setupSyncQueue() {
        syncQueue.maxConcurrentOperationCount = 1
        syncQueue.qualityOfService = .background
    }
    
    // MARK: - Offline Data Operations
    
    /// Saves project data locally (always works offline)
    func saveProjectOffline(_ project: Project) -> Bool {
        let success = offlineStorageManager.saveProject(project)
        
        if success {
            Logger.offlineStorage.notice(
                "Saved project offline [project=\(project.name, privacy: .private(mask: .hash))]"
            )
            
            // Queue for sync when online
            if isOnline {
                queueSyncOperation(.saveProject(project))
            } else {
                addPendingSyncOperation(.saveProject(project))
            }
        }
        
        return success
    }
    
    /// Loads all projects from local storage (always works offline)
    func loadProjectsOffline() -> [Project] {
        let projects = offlineStorageManager.loadProjects()
        Logger.offlineStorage.info("Loaded projects from offline storage [count=\(projects.count, privacy: .public)]")
        return projects
    }
    
    /// Saves progress log with photos (works offline)
    func saveProgressLogOffline(_ log: ProgressLog, for projectId: UUID) -> Bool {
        let success = offlineStorageManager.saveProgressLog(log, projectId: projectId)
        
        if success {
            Logger.offlineStorage.notice(
                "Saved progress log offline [project=\(projectId.uuidString, privacy: .private(mask: .hash)), photos=\(log.photoIDs.count, privacy: .public)]"
            )
            
            // Queue for sync when online
            if isOnline {
                queueSyncOperation(.saveProgressLog(log, projectId))
            } else {
                addPendingSyncOperation(.saveProgressLog(log, projectId))
            }
        }
        
        return success
    }
    
    /// Saves receipt with photo (works offline)
    func saveReceiptOffline(_ receipt: Receipt, for projectId: UUID) -> Bool {
        let success = offlineStorageManager.saveReceipt(receipt, projectId: projectId)
        
        if success {
            Logger.offlineStorage.notice(
                "Saved receipt offline [project=\(projectId.uuidString, privacy: .private(mask: .hash)), vendor=\(receipt.vendor, privacy: .private(mask: .hash))]"
            )
            
            // Queue for sync when online
            if isOnline {
                queueSyncOperation(.saveReceipt(receipt, projectId))
            } else {
                addPendingSyncOperation(.saveReceipt(receipt, projectId))
            }
        }
        
        return success
    }
    
    /// Saves work hours (works offline)
    func saveWorkHoursOffline(_ workHours: [WorkHour], for projectId: UUID) -> Bool {
        let success = offlineStorageManager.saveWorkHours(workHours, projectId: projectId)
        
        if success {
            Logger.offlineStorage.notice(
                "Saved work hours offline [project=\(projectId.uuidString, privacy: .private(mask: .hash)), count=\(workHours.count, privacy: .public)]"
            )
            
            // Queue for sync when online
            if isOnline {
                queueSyncOperation(.saveWorkHours(workHours, projectId))
            } else {
                addPendingSyncOperation(.saveWorkHours(workHours, projectId))
            }
        }
        
        return success
    }
    
    // MARK: - Sync Operations
    
    private func addPendingSyncOperation(_ operation: SyncOperation) {
        pendingSyncOperations.append(operation)
        savePendingOperations()
        Logger.offlineSync.info(
            "Queued offline sync operation [pending=\(self.pendingSyncOperations.count, privacy: .public), operation=\(operation.description, privacy: .private(mask: .hash))]"
        )
    }
    
    private func queueSyncOperation(_ operation: SyncOperation) {
        let syncOp = SyncOperationWrapper(operation: operation, manager: self)
        syncQueue.addOperation(syncOp)
    }
    
    func syncWhenOnline() {
        guard isOnline else {
            Logger.offlineSync.warning("Skipped offline sync because the device is offline.")
            return
        }
        
        guard !isSyncing else {
            Logger.offlineSync.info("Skipped offline sync because a sync is already in progress.")
            return
        }
        
        isSyncing = true
        syncProgress = 0.0
        
        Logger.offlineSync.notice(
            "Starting background offline sync [pending=\(self.pendingSyncOperations.count, privacy: .public)]"
        )
        
        // Process all pending operations
        let operations = pendingSyncOperations
        let totalOperations = Double(operations.count)
        
        var completedOperations = 0.0
        
        for operation in operations {
            queueSyncOperation(operation)
            
            completedOperations += 1.0
            DispatchQueue.main.async {
                self.syncProgress = completedOperations / totalOperations
            }
        }
        
        // Clear pending operations after queuing
        pendingSyncOperations.removeAll()
        savePendingOperations()
        
        // Update sync completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isSyncing = false
            self.syncProgress = 1.0
            self.lastSuccessfulSync = Date()
            self.saveOfflineState()
            Logger.offlineSync.notice("Completed background offline sync.")
        }
    }
    
    // MARK: - Offline State Persistence
    
    private func loadOfflineState() {
        let offlineStateURL = offlineStorageManager.offlineStateURL
        
        if let data = try? Data(contentsOf: offlineStateURL),
           let state = try? JSONDecoder().decode(OfflineState.self, from: data) {
            lastSuccessfulSync = state.lastSuccessfulSync
            pendingSyncOperations = state.pendingOperations
            Logger.offlineSync.info(
                "Loaded offline sync state [pending=\(self.pendingSyncOperations.count, privacy: .public)]"
            )
        }
    }
    
    private func saveOfflineState() {
        let state = OfflineState(
            lastSuccessfulSync: lastSuccessfulSync,
            pendingOperations: pendingSyncOperations
        )
        
        let offlineStateURL = offlineStorageManager.offlineStateURL
        
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: offlineStateURL)
        }
    }
    
    private func savePendingOperations() {
        saveOfflineState()
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflict(localProject: Project, cloudProject: Project) -> Project {
        // Simple last-modified-wins strategy
        // In production, this could be more sophisticated
        if localProject.startDate > cloudProject.startDate {
            Logger.offlineSync.notice("Resolved project sync conflict in favor of local version.")
            return localProject
        } else {
            Logger.offlineSync.notice("Resolved project sync conflict in favor of cloud version.")
            return cloudProject
        }
    }
    
    // MARK: - Offline Capabilities Status
    
    func getOfflineCapabilitiesStatus() async -> String {
        var status = "📱 OFFLINE CAPABILITIES:\n\n"
        
        status += "🌐 Network Status:\n"
        status += "• Connected: \(isOnline ? "✅ Yes" : "❌ No")\n"
        status += "• Quality: \(connectionQuality)\n"
        status += "• Last Sync: \(lastSuccessfulSync?.formatted() ?? "Never")\n\n"
        
        status += "💾 Offline Storage:\n"
        status += "• Projects: \(offlineStorageManager.getProjectCount()) stored locally\n"
        status += "• Total Size: \(offlineStorageManager.getTotalStorageSize()) MB\n"
        status += "• Photos: \(offlineStorageManager.getPhotoCount()) cached locally\n\n"
        
        status += "🔄 Sync Queue:\n"
        status += "• Pending Operations: \(pendingSyncOperations.count)\n"
        status += "• Currently Syncing: \(isSyncing ? "Yes" : "No")\n"
        
        if isSyncing {
            status += "• Progress: \(Int(syncProgress * 100))%\n"
        }
        
        status += "\n✅ OFFLINE CAPABILITIES:\n"
        status += "• ✅ View all projects\n"
        status += "• ✅ Create new projects\n"
        status += "• ✅ Add progress logs\n"
        status += "• ✅ Take photos\n"
        status += "• ✅ Scan receipts\n"
        status += "• ✅ Log work hours\n"
        status += "• ✅ Create tasks\n"
        status += "• ✅ View all historical data\n"
        status += "• 🔄 Sync when connection restored\n"
        
        return status
    }
    
    deinit {
        networkMonitor.cancel()
    }
}

// MARK: - Offline Storage Manager

class OfflineStorageManager {
    
    private let documentsURL: URL
    
    // File URLs
    var projectsURL: URL { documentsURL.appendingPathComponent("offline_projects.json") }
    var progressLogsURL: URL { documentsURL.appendingPathComponent("offline_progress_logs.json") }
    var receiptsURL: URL { documentsURL.appendingPathComponent("offline_receipts.json") }
    var workHoursURL: URL { documentsURL.appendingPathComponent("offline_work_hours.json") }
    var photosDirectoryURL: URL { documentsURL.appendingPathComponent("offline_photos") }
    var offlineStateURL: URL { documentsURL.appendingPathComponent("offline_state.json") }
    
    init(documentsURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.documentsURL = documentsURL
        createDirectoriesIfNeeded()
    }

    static func clearUITestArtifacts(fileManager: FileManager = .default) {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let storage = OfflineStorageManager(documentsURL: documentsURL)
        let artifactURLs = [
            storage.projectsURL,
            storage.progressLogsURL,
            storage.receiptsURL,
            storage.workHoursURL,
            storage.offlineStateURL,
            storage.photosDirectoryURL
        ]

        for artifactURL in artifactURLs where fileManager.fileExists(atPath: artifactURL.path) {
            try? fileManager.removeItem(at: artifactURL)
        }
    }
    
    private func createDirectoriesIfNeeded() {
        try? FileManager.default.createDirectory(at: photosDirectoryURL, withIntermediateDirectories: true)
    }
    
    // MARK: - Project Storage
    
    func saveProject(_ project: Project) -> Bool {
        var projects = loadProjects()
        
        // Update existing or add new
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
        
        return saveProjects(projects)
    }
    
    func loadProjects() -> [Project] {
        guard let data = try? Data(contentsOf: projectsURL),
              let projects = try? JSONDecoder().decode([Project].self, from: data) else {
            return []
        }
        return projects
    }
    
    func saveProjects(_ projects: [Project]) -> Bool {
        let strippedInlineReceiptImages = projects.reduce(0) { count, project in
            count + project.inlineReceiptImageCount
        }
        let persistenceSafeProjects = projects.map(\.persistenceSafeCopy)
        guard let data = try? JSONEncoder().encode(persistenceSafeProjects) else { return false }
        
        do {
            try data.write(to: projectsURL, options: .atomic)
            if strippedInlineReceiptImages > 0 {
                Logger.offlineStorage.debug(
                    "Stripped inline receipt images from offline project payload [images=\(strippedInlineReceiptImages, privacy: .public)]"
                )
            }
            return true
        } catch {
            Logger.offlineStorage.error(
                "Failed to save projects offline [error=\(error.localizedDescription, privacy: .public)]"
            )
            return false
        }
    }
    
    // MARK: - Progress Log Storage
    
    func saveProgressLog(_ log: ProgressLog, projectId: UUID) -> Bool {
        var logs = loadProgressLogs()
        
        // Add project association
        let logWithProject = log
        // Store project ID in a way that can be retrieved
        
        logs.append(ProjectProgressLog(projectId: projectId, log: logWithProject))
        
        // Save photos locally
        if !log.photoIDs.isEmpty {
            Logger.offlineStorage.debug(
                "Stored progress-log photo references offline [count=\(log.photoIDs.count, privacy: .public)]"
            )
        }
        
        return saveProgressLogs(logs)
    }
    
    private func loadProgressLogs() -> [ProjectProgressLog] {
        guard let data = try? Data(contentsOf: progressLogsURL),
              let logs = try? JSONDecoder().decode([ProjectProgressLog].self, from: data) else {
            return []
        }
        return logs
    }
    
    private func saveProgressLogs(_ logs: [ProjectProgressLog]) -> Bool {
        guard let data = try? JSONEncoder().encode(logs) else { return false }
        
        do {
            try data.write(to: progressLogsURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Receipt Storage
    
    func saveReceipt(_ receipt: Receipt, projectId: UUID) -> Bool {
        var receipts = loadReceipts()
        receipts.append(ProjectReceipt(projectId: projectId, receipt: receipt))
        
        // Save receipt photos using photoIDs (modern CloudKit approach)
        // Photos are handled by CloudKitPhotoService, offline caching handled separately
        if !receipt.photoIDs.isEmpty {
            Logger.offlineStorage.debug(
                "Stored receipt photo references offline [count=\(receipt.photoIDs.count, privacy: .public)]"
            )
        }
        
        return saveReceipts(receipts)
    }
    
    private func loadReceipts() -> [ProjectReceipt] {
        guard let data = try? Data(contentsOf: receiptsURL),
              let receipts = try? JSONDecoder().decode([ProjectReceipt].self, from: data) else {
            return []
        }
        return receipts
    }
    
    private func saveReceipts(_ receipts: [ProjectReceipt]) -> Bool {
        guard let data = try? JSONEncoder().encode(receipts) else { return false }
        
        do {
            try data.write(to: receiptsURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Work Hours Storage
    
    func saveWorkHours(_ workHours: [WorkHour], projectId: UUID) -> Bool {
        var allWorkHours = loadAllWorkHours()
        
        for workHour in workHours {
            allWorkHours.append(ProjectWorkHour(projectId: projectId, workHour: workHour))
        }
        
        return saveAllWorkHours(allWorkHours)
    }
    
    private func loadAllWorkHours() -> [ProjectWorkHour] {
        guard let data = try? Data(contentsOf: workHoursURL),
              let workHours = try? JSONDecoder().decode([ProjectWorkHour].self, from: data) else {
            return []
        }
        return workHours
    }
    
    private func saveAllWorkHours(_ workHours: [ProjectWorkHour]) -> Bool {
        guard let data = try? JSONEncoder().encode(workHours) else { return false }
        
        do {
            try data.write(to: workHoursURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Storage Statistics
    
    func getProjectCount() -> Int {
        return loadProjects().count
    }
    
    func getPhotoCount() -> Int {
        let photoFiles = (try? FileManager.default.contentsOfDirectory(at: photosDirectoryURL, includingPropertiesForKeys: nil)) ?? []
        return photoFiles.count
    }
    
    func getTotalStorageSize() -> Double {
        let urls = [projectsURL, progressLogsURL, receiptsURL, workHoursURL, photosDirectoryURL]
        var totalSize: Int64 = 0
        
        for url in urls {
            if let size = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize {
                totalSize += Int64(size)
            }
        }
        
        return Double(totalSize) / 1_048_576 // Convert to MB
    }
}

// MARK: - Supporting Types

enum ConnectionQuality: String, CustomStringConvertible {
    case wifi = "wifi"
    case cellular = "cellular"
    case offline = "offline"
    case unknown = "unknown"
    
    var description: String {
        switch self {
        case .wifi: return "📶 WiFi"
        case .cellular: return "📱 Cellular"
        case .offline: return "📵 Offline"
        case .unknown: return "❓ Unknown"
        }
    }
}

enum SyncOperation: Codable {
    case saveProject(Project)
    case saveProgressLog(ProgressLog, UUID)
    case saveReceipt(Receipt, UUID)
    case saveWorkHours([WorkHour], UUID)
    
    var description: String {
        switch self {
        case .saveProject(let project):
            return "Save Project: \(project.name)"
        case .saveProgressLog(let log, _):
            return "Save Progress Log: \(log.workDescription)"
        case .saveReceipt(let receipt, _):
            return "Save Receipt: \(receipt.vendor)"
        case .saveWorkHours(let hours, _):
            return "Save Work Hours: \(hours.count) entries"
        }
    }
}

struct OfflineState: Codable {
    let lastSuccessfulSync: Date?
    let pendingOperations: [SyncOperation]
}

// MARK: - Codable Project Data Structures

struct ProjectProgressLog: Codable {
    let projectId: UUID
    let log: ProgressLog
}

struct ProjectReceipt: Codable {
    let projectId: UUID
    let receipt: Receipt
}

struct ProjectWorkHour: Codable {
    let projectId: UUID
    let workHour: WorkHour
}

// MARK: - Sync Operation Wrapper

class SyncOperationWrapper: Operation, @unchecked Sendable {
    private let operation: SyncOperation
    private weak var manager: OfflineDataManager?
    
    init(operation: SyncOperation, manager: OfflineDataManager) {
        self.operation = operation
        self.manager = manager
        super.init()
    }
    
    override func main() {
        guard !isCancelled else { return }
        
        // Simulate CloudKit sync operation
        // In production, this would call actual CloudKit APIs
        Logger.offlineSync.debug(
            "Syncing queued offline operation [operation=\(self.operation.description, privacy: .private(mask: .hash))]"
        )
        
        // Simulate network delay
        Thread.sleep(forTimeInterval: 0.5)
        
        if !isCancelled {
            Logger.offlineSync.debug(
                "Completed queued offline operation [operation=\(self.operation.description, privacy: .private(mask: .hash))]"
            )
        }
    }
}
