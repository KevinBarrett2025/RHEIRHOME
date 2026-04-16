import Foundation
import CoreLocation

/// A single block of time logged by an employee.
public struct WorkHour: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public var startTime: Date
    public var endTime: Date?
    public var lunchStart: Date?
    public var lunchEnd: Date?
    
    // Employee identification - transitioning from name to ID
    public var employee: String // Keep for backward compatibility
    public var employeeID: UUID? // New field for proper team member linking
    public var rate: Double

    // Category for budget allocation
    public var category: String

    // Payment tracking
    public var isPaid: Bool
    public var paymentMethod: String?
    public var paymentNote: String?
    public var paymentTimestamp: Date?
    
    // Location tracking for verification (stored as simple coordinates)
    private var clockInLatitude: Double?
    private var clockInLongitude: Double?
    private var clockInTimestamp: Date?
    private var clockOutLatitude: Double?
    private var clockOutLongitude: Double?
    private var clockOutTimestamp: Date?
    
    // Computed CLLocation properties
    public var clockInLocation: CLLocation? {
        get {
            guard let lat = clockInLatitude,
                  let lon = clockInLongitude,
                  let timestamp = clockInTimestamp else { return nil }
            return CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                altitude: 0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 5.0,
                timestamp: timestamp
            )
        }
        set {
            if let location = newValue {
                clockInLatitude = location.coordinate.latitude
                clockInLongitude = location.coordinate.longitude
                clockInTimestamp = location.timestamp
            } else {
                clockInLatitude = nil
                clockInLongitude = nil
                clockInTimestamp = nil
            }
        }
    }
    
    public var clockOutLocation: CLLocation? {
        get {
            guard let lat = clockOutLatitude,
                  let lon = clockOutLongitude,
                  let timestamp = clockOutTimestamp else { return nil }
            return CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                altitude: 0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 5.0,
                timestamp: timestamp
            )
        }
        set {
            if let location = newValue {
                clockOutLatitude = location.coordinate.latitude
                clockOutLongitude = location.coordinate.longitude
                clockOutTimestamp = location.timestamp
            } else {
                clockOutLatitude = nil
                clockOutLongitude = nil
                clockOutTimestamp = nil
            }
        }
    }
    
    // Time validation and approval
    public var isApproved: Bool = false
    public var approvedBy: UUID? // Manager who approved
    public var approvedAt: Date?
    public var validationNotes: String?

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
    
    // Overtime calculation
    public var regularHours: Double {
        return min(hours, 8.0) // Standard 8-hour day
    }
    
    public var overtimeHours: Double {
        return max(0, hours - 8.0)
    }
    
    public var regularPay: Double {
        return regularHours * rate
    }
    
    public var overtimePay: Double {
        return overtimeHours * rate * 1.5 // Time and a half
    }
    
    public var totalPay: Double {
        return regularPay + overtimePay
    }

    // Manual decode to handle backward compatibility and optional fields
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self,   forKey: .id)
        date             = try c.decode(Date.self,   forKey: .date)
        startTime        = try c.decode(Date.self,   forKey: .startTime)
        endTime          = try c.decodeIfPresent(Date.self, forKey: .endTime)
        lunchStart       = try c.decodeIfPresent(Date.self, forKey: .lunchStart)
        lunchEnd         = try c.decodeIfPresent(Date.self, forKey: .lunchEnd)
        employee         = try c.decode(String.self, forKey: .employee)
        employeeID       = try c.decodeIfPresent(UUID.self, forKey: .employeeID)
        rate             = try c.decode(Double.self, forKey: .rate)
        category         = try c.decodeIfPresent(String.self, forKey: .category) ?? "Labor"
        isPaid           = try c.decode(Bool.self,   forKey: .isPaid)
        paymentMethod    = try c.decodeIfPresent(String.self, forKey: .paymentMethod)
        paymentNote      = try c.decodeIfPresent(String.self, forKey: .paymentNote)
        paymentTimestamp = try c.decodeIfPresent(Date.self,   forKey: .paymentTimestamp)
        
        // Location data as simple coordinates
        clockInLatitude = try c.decodeIfPresent(Double.self, forKey: .clockInLatitude)
        clockInLongitude = try c.decodeIfPresent(Double.self, forKey: .clockInLongitude)
        clockInTimestamp = try c.decodeIfPresent(Date.self, forKey: .clockInTimestamp)
        clockOutLatitude = try c.decodeIfPresent(Double.self, forKey: .clockOutLatitude)
        clockOutLongitude = try c.decodeIfPresent(Double.self, forKey: .clockOutLongitude)
        clockOutTimestamp = try c.decodeIfPresent(Date.self, forKey: .clockOutTimestamp)
        
        // New fields with defaults
        isApproved       = try c.decodeIfPresent(Bool.self, forKey: .isApproved) ?? false
        approvedBy       = try c.decodeIfPresent(UUID.self, forKey: .approvedBy)
        approvedAt       = try c.decodeIfPresent(Date.self, forKey: .approvedAt)
        validationNotes  = try c.decodeIfPresent(String.self, forKey: .validationNotes)
    }

    /// Enhanced initializer with team member integration
    public init(
        id: UUID = .init(),
        date: Date,
        startTime: Date,
        endTime: Date?,
        lunchStart: Date?,
        lunchEnd: Date?,
        employee: String,
        employeeID: UUID?,
        rate: Double,
        category: String,
        isPaid: Bool,
        paymentMethod: String?,
        paymentNote: String?,
        paymentTimestamp: Date?,
        clockInLocation: CLLocation? = nil,
        clockOutLocation: CLLocation? = nil
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.lunchStart = lunchStart
        self.lunchEnd = lunchEnd
        self.employee = employee
        self.employeeID = employeeID
        self.rate = rate
        self.category = category
        self.isPaid = isPaid
        self.paymentMethod = paymentMethod
        self.paymentNote = paymentNote
        self.paymentTimestamp = paymentTimestamp
        self.isApproved = false
        self.approvedBy = nil
        self.approvedAt = nil
        self.validationNotes = nil
        
        // Set location data
        if let clockIn = clockInLocation {
            self.clockInLatitude = clockIn.coordinate.latitude
            self.clockInLongitude = clockIn.coordinate.longitude
            self.clockInTimestamp = clockIn.timestamp
        } else {
            self.clockInLatitude = nil
            self.clockInLongitude = nil
            self.clockInTimestamp = nil
        }
        
        if let clockOut = clockOutLocation {
            self.clockOutLatitude = clockOut.coordinate.latitude
            self.clockOutLongitude = clockOut.coordinate.longitude
            self.clockOutTimestamp = clockOut.timestamp
        } else {
            self.clockOutLatitude = nil
            self.clockOutLongitude = nil
            self.clockOutTimestamp = nil
        }
    }
    
    /// Convenience initializer for new live tracking entries
    public init(
        teamMember: TeamMember,
        rate: Double,
        category: String = "Labor",
        startTime: Date = Date(),
        location: CLLocation? = nil
    ) {
        self.id = UUID()
        self.date = startTime
        self.startTime = startTime
        self.endTime = nil
        self.lunchStart = nil
        self.lunchEnd = nil
        self.employee = teamMember.name
        self.employeeID = teamMember.id
        self.rate = rate
        self.category = category
        self.isPaid = false
        self.paymentMethod = nil
        self.paymentNote = nil
        self.paymentTimestamp = nil
        self.isApproved = false
        self.approvedBy = nil
        self.approvedAt = nil
        self.validationNotes = nil
        
        // Set location data
        if let location = location {
            self.clockInLatitude = location.coordinate.latitude
            self.clockInLongitude = location.coordinate.longitude
            self.clockInTimestamp = location.timestamp
        } else {
            self.clockInLatitude = nil
            self.clockInLongitude = nil
            self.clockInTimestamp = nil
        }
        
        self.clockOutLatitude = nil
        self.clockOutLongitude = nil
        self.clockOutTimestamp = nil
    }
    
    // MARK: - Time Validation
    
    public var isValid: Bool {
        // Basic validation rules
        guard let endTime = endTime else { return true } // Active timers are valid
        guard endTime > startTime else { return false } // End must be after start
        guard hours <= 24 else { return false } // No more than 24 hours
        guard hours >= 0.1 else { return false } // At least 6 minutes
        
        // Lunch break validation
        if let lunchStart = lunchStart, let lunchEnd = lunchEnd {
            guard lunchStart >= startTime && lunchEnd <= endTime else { return false }
            guard lunchEnd > lunchStart else { return false }
            guard lunchBreakDuration ?? 0 <= 2.0 else { return false } // Max 2 hour lunch
        }
        
        return true
    }
    
    public var validationIssues: [String] {
        var issues: [String] = []
        
        guard let endTime = endTime else { return issues }
        
        if endTime <= startTime {
            issues.append("End time must be after start time")
        }
        
        if hours > 24 {
            issues.append("Work session cannot exceed 24 hours")
        }
        
        if hours < 0.1 {
            issues.append("Work session must be at least 6 minutes")
        }
        
        if hours > 16 {
            issues.append("Work session exceeds 16 hours - please verify")
        }
        
        if let lunchStart = lunchStart, let lunchEnd = lunchEnd {
            if lunchStart < startTime || lunchEnd > endTime {
                issues.append("Lunch break must be within work hours")
            }
            
            if lunchEnd <= lunchStart {
                issues.append("Lunch end must be after lunch start")
            }
            
            if (lunchBreakDuration ?? 0) > 2.0 {
                issues.append("Lunch break exceeds 2 hours")
            }
        }
        
        return issues
    }
    
    // MARK: - Location Verification
    
    public func distanceFromWorkSite(_ workSiteLocation: CLLocation) -> Double? {
        guard let clockInLocation = clockInLocation else { return nil }
        return clockInLocation.distance(from: workSiteLocation)
    }
    
    public var isLocationVerified: Bool {
        // If no location tracking, assume verified for backward compatibility
        return clockInLocation != nil
    }
    
    // MARK: - Approval Workflow
    
    public mutating func approve(by managerID: UUID, notes: String? = nil) {
        isApproved = true
        approvedBy = managerID
        approvedAt = Date()
        validationNotes = notes
    }
    
    public mutating func reject(by managerID: UUID, reason: String) {
        isApproved = false
        approvedBy = managerID
        approvedAt = Date()
        validationNotes = reason
    }
    
    // MARK: - Coding Keys
    private enum CodingKeys: String, CodingKey {
        case id, date, startTime, endTime, lunchStart, lunchEnd
        case employee, employeeID, rate, category
        case isPaid, paymentMethod, paymentNote, paymentTimestamp
        case clockInLatitude, clockInLongitude, clockInTimestamp
        case clockOutLatitude, clockOutLongitude, clockOutTimestamp
        case isApproved, approvedBy, approvedAt, validationNotes
    }
}
