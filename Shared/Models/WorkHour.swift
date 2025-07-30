import Foundation

/// A single block of time logged by an employee.
public struct WorkHour: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public var startTime: Date
    public var endTime: Date?
    public var lunchStart: Date?
    public var lunchEnd: Date?
    public var employee: String
    public var rate: Double

    // New — which budget bucket this belongs to:
    public var category: String

    // Payment fields
    public var isPaid: Bool
    public var paymentMethod: String?
    public var paymentNote: String?
    public var paymentTimestamp: Date?

    // Computed durations
    public var lunchBreakDuration: Double? {
        guard let s = lunchStart, let e = lunchEnd else { return nil }
        return e.timeIntervalSince(s) / 3600
    }
    public var hours: Double {
        guard let out = endTime else { return 0 }
        let total = out.timeIntervalSince(startTime) / 3600
        return total - (lunchBreakDuration ?? 0)
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, startTime, endTime, lunchStart, lunchEnd
        case employee, rate, category
        case isPaid, paymentMethod, paymentNote, paymentTimestamp
    }

    // Manual decode to default `category = "Labor"` when missing
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self,   forKey: .id)
        date             = try c.decode(Date.self,   forKey: .date)
        startTime        = try c.decode(Date.self,   forKey: .startTime)
        endTime          = try c.decodeIfPresent(Date.self, forKey: .endTime)
        lunchStart       = try c.decodeIfPresent(Date.self, forKey: .lunchStart)
        lunchEnd         = try c.decodeIfPresent(Date.self, forKey: .lunchEnd)
        employee         = try c.decode(String.self, forKey: .employee)
        rate             = try c.decode(Double.self, forKey: .rate)
        category         = try c.decodeIfPresent(String.self, forKey: .category) ?? "Labor"
        isPaid           = try c.decode(Bool.self,   forKey: .isPaid)
        paymentMethod    = try c.decodeIfPresent(String.self, forKey: .paymentMethod)
        paymentNote      = try c.decodeIfPresent(String.self, forKey: .paymentNote)
        paymentTimestamp = try c.decodeIfPresent(Date.self,   forKey: .paymentTimestamp)
    }

    // Encoder remains synthesized (will include `category`)

    /// Convenience initializer for new entries
    public init(
        id: UUID = .init(),
        startTime: Date,
        employee: String,
        rate: Double,
        category: String = "Labor"
    ) {
        self.id = id
        self.date = startTime
        self.startTime = startTime
        self.endTime = nil
        self.lunchStart = nil
        self.lunchEnd   = nil
        self.employee = employee
        self.rate     = rate
        self.category = category
        self.isPaid   = false
        self.paymentMethod    = nil
        self.paymentNote      = nil
        self.paymentTimestamp = nil
    }
    
    /// Full initializer for complete work hour entries
    public init(
        id: UUID = .init(),
        date: Date,
        startTime: Date,
        endTime: Date?,
        lunchStart: Date?,
        lunchEnd: Date?,
        employee: String,
        rate: Double,
        category: String,
        isPaid: Bool,
        paymentMethod: String?,
        paymentNote: String?,
        paymentTimestamp: Date?
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.lunchStart = lunchStart
        self.lunchEnd = lunchEnd
        self.employee = employee
        self.rate = rate
        self.category = category
        self.isPaid = isPaid
        self.paymentMethod = paymentMethod
        self.paymentNote = paymentNote
        self.paymentTimestamp = paymentTimestamp
    }
}