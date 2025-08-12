// ProjectViewModel+Import.swift

import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
extension ProjectViewModel {
    /// Import either a bare Project JSON or a legacy ImportPackage bundle.
    func importProject(from url: URL) throws {
        // 1️⃣ Security-scope
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // 2️⃣ Load & configure decoder
        let raw = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 3️⃣ Try bare-project first
        if let project = try? decoder.decode(Project.self, from: raw) {
            // Add the imported project to our organization projects array
            if !organizationProjects.contains(where: { $0.id == project.id }) {
                organizationProjects.append(project)
            }
            // Save to local backup
            saveLocalBackup()
            return
        }

        // 4️⃣ Fallback to legacy bundle format
        struct ImportPackage: Codable {
            let project: Project
            let employees: [TeamMember]
            
            // Custom coding keys if needed
            enum CodingKeys: String, CodingKey {
                case project
                case employees
            }
            
            // Custom decoder to handle TeamMember decoding
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                project = try container.decode(Project.self, forKey: .project)
                employees = try container.decode([TeamMember].self, forKey: .employees)
            }
            
            // Custom encoder for TeamMember encoding
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(project, forKey: .project)
                try container.encode(employees, forKey: .employees)
            }
        }

        let pkg = try decoder.decode(ImportPackage.self, from: raw)

        // 5️⃣ Merge in any new team members
        for member in pkg.employees {
            if !teamMembers.contains(where: { $0.id == member.id }) {
                // Add team member directly to the array
                teamMembers.append(member)
            }
        }

        // 6️⃣ Add the imported project to organization projects
        if !organizationProjects.contains(where: { $0.id == pkg.project.id }) {
            organizationProjects.append(pkg.project)
        }

        // 7️⃣ Save everything to local storage
        saveLocalBackup()
        saveTeamMembersLocal()
    }
    
    /// Save team members to local storage
    private func saveTeamMembersLocal() {
        do {
            let data = try JSONEncoder().encode(teamMembers)
            UserDefaults.standard.set(data, forKey: "teamMembers")
            print("💾 [ProjectViewModel] Saved \(teamMembers.count) team members to local backup")
        } catch {
            print("❌ [ProjectViewModel] Failed to save team members locally: \(error)")
        }
    }
    
    /// Save local backup of projects
    private func saveLocalBackup() {
        do {
            let data = try JSONEncoder().encode(organizationProjects)
            UserDefaults.standard.set(data, forKey: "projects_backup")
            print("💾 [ProjectViewModel] Saved local project backup (\(organizationProjects.count) projects)")
        } catch {
            print("❌ [ProjectViewModel] Failed to save local project backup: \(error)")
        }
    }
}