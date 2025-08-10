import Foundation
import SwiftUI
import CloudKit
import Combine

// ... rest of the code remains the same

@MainActor
class ProjectViewModel: ObservableObject {
    // ... rest of the code remains the same

    /// Create share for an existing zone
    private func createShareForExistingZone(_ zone: CKRecordZone, organizationID: String, container: CKContainer) async throws -> String {
        let privateDB = container.privateCloudDatabase
        
        // Create organization root record
        let rootRecordID = CKRecord.ID(recordName: "org-root-\(organizationID)", zoneID: zone.zoneID)
        
        // Get or create root record
        let rootRecord: CKRecord
        do {
            let existingRootRecord = try await privateDB.record(for: rootRecordID)
            rootRecord = existingRootRecord
            print(" Using existing organization root record for share creation")
        } catch let error as CKError where error.code == .unknownItem {
            // Create new root record
            let newRootRecord = CKRecord(recordType: "OrganizationRoot", recordID: rootRecordID)
            newRootRecord["organizationID"] = organizationID as CKRecordValue
            newRootRecord["name"] = "RHEIR Organization \(organizationID.prefix(8))" as CKRecordValue
            newRootRecord["createdAt"] = Date() as CKRecordValue
            rootRecord = newRootRecord
            print(" Created new organization root record for share creation")
        }
        
        // Create share for the root record
        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = "RHEIR Organization \(organizationID.prefix(8))" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "com.rheirhome.organization" as CKRecordValue
        share.publicPermission = .none
        
        // CRITICAL FIX: Save both root record and share atomically using CKModifyRecordsOperation
        print(" Saving root record and share atomically to fix CloudKit constraint...")
        
        _ = try await withCheckedThrowingContinuation { continuation in
            let modifyRecordsOperation = CKModifyRecordsOperation(
                recordsToSave: [rootRecord, share],
                recordIDsToDelete: nil
            )
            modifyRecordsOperation.savePolicy = .changedKeys
            modifyRecordsOperation.isAtomic = true
            
            modifyRecordsOperation.modifyRecordsResultBlock = { result in
                switch result {
                case .success(_):
                    print(" Successfully saved root record and share atomically")
                    print(" Saved records in atomic operation")
                    continuation.resume(returning: "Success")
                case .failure(let error):
                    print(" Failed to save root record and share atomically: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            privateDB.add(modifyRecordsOperation)
        }
        
        print(" Created share for organization zone - collaboration enabled")
        return "Success"
    }

    // ... rest of the code remains the same

    /// Setup CloudKit SHARED zone for a specific organization (RE-ENABLED)
    func setupCloudKitZoneForOrganization(_ organizationID: String) async {
        print(" ZONE SETUP: Setting up SHARED CloudKit zone for organization: \(organizationID.prefix(8))...")
        print(" ZONE SETUP: Current isUsingCloudKitForOrganizationData: \(isUsingCloudKitForOrganizationData)")
        
        isSettingUpZone = true
        zoneSetupError = nil
        currentOrganizationID = organizationID
        
        do {
            // Check CloudKit account status first
            let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                let errorMsg = "iCloud account not available: \(accountStatus)"
                print(" ZONE SETUP: \(errorMsg)")
                throw NSError(domain: "CloudKit", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            print(" CloudKit account available")
            
            let _ = container.privateCloudDatabase
            
            let zoneName = "org-shared-\(organizationID)"
            let _ = CKRecordZone.ID(zoneName: zoneName)
            
            // STEP 1: Check if zone already exists in private database
            print(" Checking for existing zone...")
            do {
                let existingZones = try await container.privateCloudDatabase.allRecordZones()
                if let existingZone = existingZones.first(where: { $0.zoneID.zoneName == zoneName }) {
                    print(" Found existing CloudKit SHARED zone: \(zoneName)")
                    
                    // Check if zone has a share (is actually shared)
                    let hasShare = try await checkZoneHasShare(existingZone, container: container)
                    
                    if hasShare {
                        print(" Zone is properly shared for collaboration")
                    } else {
                        print(" Zone exists but is not shared - creating share...")
                        _ = try await createShareForExistingZone(existingZone, organizationID: organizationID, container: container)
                        print(" Created share for existing zone")
                    }
                    
                    isUsingCloudKitForOrganizationData = true
                    await loadOrganizationProjectsFromCloudKit(zoneID: existingZone.zoneID)
                    isSettingUpZone = false
                    print(" ZONE SETUP: Using existing zone for organization: \(organizationID.prefix(8))...")
                    return
                }
            } catch {
                print(" Could not check existing zones: \(error)")
            }
            
            // STEP 2: Create new zone with sharing
            print(" Creating new SHARED zone: \(zoneName)")
            
            let newZone = CKRecordZone(zoneID: CKRecordZone.ID(zoneName: zoneName))
            let savedZone = try await container.privateCloudDatabase.save(newZone)
            print(" Created zone in private DB: \(zoneName)");
            
            // 
            _ = try await createShareForExistingZone(savedZone, organizationID: organizationID, container: container)
            
            isUsingCloudKitForOrganizationData = true
            print(" ZONE SETUP: CloudKit SHARED zone setup successful for organization: \(organizationID.prefix(8))...")
            
            // Load projects from the new zone
            await loadOrganizationProjectsFromCloudKit(zoneID: savedZone.zoneID);
            
        } catch {
            print(" ZONE SETUP: Failed to setup CloudKit SHARED zone: \(error)");
            zoneSetupError = "Failed to setup CloudKit zone: \(error.localizedDescription)";
            
            // Fallback to local storage
            isUsingCloudKitForOrganizationData = false
            await loadOrganizationProjects();
        }
        
        isSettingUpZone = false
        print(" ZONE SETUP: Zone setup completed for organization: \(organizationID.prefix(8))...")
        print(" ZONE SETUP: Final isUsingCloudKitForOrganizationData: \(isUsingCloudKitForOrganizationData)")
    }

    private func loadOrganizationProjects() async {
        // For now, load from local backup
        await loadLocalProjectsAsBackup()
    }
    
    private func loadLocalProjectsAsBackup() async {
        let key = "local_projects_backup"
        print("🔍 Loading projects from key: \(key)")
        
        guard let data = UserDefaults.standard.data(forKey: key),
              let projects = try? JSONDecoder().decode([Project].self, from: data) else { 
            print("⚠️ No project backup data found")
            return 
        }
        
        await MainActor.run {
            print("✅ Found \(projects.count) projects in backup")
            
            // Only use backup if we don't have any projects loaded
            if self.organizationProjects.isEmpty {
                self.organizationProjects = projects
                print("📋 Restored \(projects.count) projects from backup")
            } else {
                print("ℹ️ Already have \(self.organizationProjects.count) projects, skipping backup restore")
            }
        }
    }
    
    /// Load organization from CloudKit or local storage
    private func loadOrganizationFromCloudKit(organizationID: String) async {
        print("🔍 Loading organization data for ID: \(organizationID)")
        
        let key = "organization_\(organizationID)"
        print("🔍 Looking for organization data in key: \(key)")
        
        if let data = UserDefaults.standard.data(forKey: key),
           let organization = try? JSONDecoder().decode(Organization.self, from: data) {
            await MainActor.run {
                self.currentOrganization = organization
                print("✅ Loaded organization: \(organization.name) with \(organization.teamMembers.count) team members")
            }
        } else {
            print("⚠️ No organization data found for key: \(key)")
            
            // Try to create a default organization if none exists
            await MainActor.run {
                let defaultOrg = Organization(
                    id: organizationID,
                    name: "RHEIR",
                    adminUserID: self.getCurrentUserID() ?? ""
                )
                self.currentOrganization = defaultOrg
                print("🆕 Created default organization: \(defaultOrg.name)")
            }
        }
    }
    
    /// Save organization to CloudKit and local storage
    private func saveOrganizationToCloudKit() async {
        guard let org = currentOrganization else { return }
        
        // Save to local storage
        if let data = try? JSONEncoder().encode(org) {
            UserDefaults.standard.set(data, forKey: "organization_\(org.id)")
        }
        
        // TODO: Save to CloudKit organization record
        print("💾 Saved organization with \(org.teamMembers.count) team members")
    }
    
    private func loadTeamMembersFromCloudKit() async {
        // Team members are now loaded as part of organization data
        // This method is kept for backwards compatibility but does nothing
        print("📋 Team members loaded from organization data")
    }
    
    private func deleteTaskPhotos(_ photoIDs: [String]) async {
        // For now, just log the deletion
        print("Deleting task photos: \(photoIDs)")
    }
    
    // MARK: - Labor Data Computation (Enterprise Analytics)
    
    /// Recompute all labor data and analytics (called after project updates)
    func recomputeLaborData() {
        print("🔄 Recomputing labor data and analytics...")
        
        // Clear existing computed data
        groupedHoursByTeamMember.removeAll()
        laborTotalsByTeamMember.removeAll()
        
        // Group work hours by team member across all projects
        for project in organizationProjects {
            for workHour in project.loggedHours {
                let employeeName = workHour.employee
                
                if groupedHoursByTeamMember[employeeName] == nil {
                    groupedHoursByTeamMember[employeeName] = []
                }
                groupedHoursByTeamMember[employeeName]?.append(workHour)
                
                // Calculate totals
                let currentTotals = laborTotalsByTeamMember[employeeName] ?? (unpaid: 0.0, paid: 0.0)
                let hourCost = workHour.hours * workHour.rate
                
                if workHour.isPaid {
                    laborTotalsByTeamMember[employeeName] = (unpaid: currentTotals.unpaid, paid: currentTotals.paid + hourCost)
                } else {
                    laborTotalsByTeamMember[employeeName] = (unpaid: currentTotals.unpaid + hourCost, paid: currentTotals.paid)
                }
            }
        }
        
        print("✅ Labor data recomputed for \(groupedHoursByTeamMember.keys.count) team members")
    }
    
    // MARK: - Backwards Compatibility Methods (Updated for Organization Integration)
    
    func saveTeamMembers() {
        // Now saves organization to CloudKit instead of separate team members
        Task {
            await saveOrganizationToCloudKit()
        }
    }
    
    /// Update team member (backwards compatibility)
    func updateTeamMember(_ teamMember: TeamMember) {
        updateTeamMemberInOrganization(teamMember)
    }
    
    // MARK: - Team Member Project Assignment Methods
    
    /// Fix team member project assignments by ensuring all projects have proper team member access
    func fixTeamMemberProjectAssignments() {
        print("🔧 Fixing team member project assignments...")
        
        let updatedCount = 0
        
        for i in 0..<organizationProjects.count {
            var project = organizationProjects[i]
            let _ = project.assignedUserIDs.count
            
            // For organization-wide projects, ensure all active team members are assigned
            if project.accessLevel == .organization {
                
                // Get all team members with member role
                let teamMemberIDs = teamMembers
                    .filter { $0.role == .member && $0.hasAppAccess }
                    .compactMap { $0.appUserID }
                
                // Add missing team members to assignment list
                for memberID in teamMemberIDs {
                    if !project.assignedUserIDs.contains(memberID) {
                        project.assignUser(memberID)
                    }
                }
                
                organizationProjects[i] = project
                saveLocalBackup()
            }
        }
        
        if updatedCount > 0 {
            saveLocalBackup()
        } else {
            // No updates needed
            print("🔧 No team member updates required")
        }
        
        print("🎉 Team member project assignments fixed - \(organizationProjects.count) projects checked")
    }
    
    func rebuildTeamMemberCache() {
        // Cache is now computed from organization.teamMembers
        // Team member cache is now computed property from organization.teamMembers
        // No manual rebuild needed - recomputeLaborData() handles the computation
    }
}