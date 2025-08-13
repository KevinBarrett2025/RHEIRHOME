import Foundation

public struct EmployeeRate: Identifiable, Codable, Hashable, Sendable {
  public let id: UUID
  public var taskType: String
  public var rate: Double
  public var isDefault: Bool
  
  public init(id: UUID = .init(), taskType: String, rate: Double, isDefault: Bool = false) {
    self.id = id
    self.taskType = taskType
    self.rate = rate
    self.isDefault = isDefault
  }
}

// MARK: - Helper Extensions
extension EmployeeRate {
    /// Display name with default indicator
    public var displayName: String {
        return isDefault ? "\(taskType) (Default)" : taskType
    }
}