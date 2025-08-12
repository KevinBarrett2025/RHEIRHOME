import SwiftUI
import CoreLocation

struct LiveTimeTrackingView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var timerManager = TimeTrackingManager()
    @StateObject private var locationManager = LocationManager()
    
    @State private var selectedMember: TeamMember?
    @State private var selectedRate: EmployeeRate?
    @State private var selectedCategory = "Labor"
    @State private var notes = ""
    @State private var showingClockInConfirmation = false
    @State private var showingManualEntry = false
    
    private let categories = ["Labor", "General Conditions", "Contingency"]
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            headerSection
            
            // Current Timer Display
            if let activeTimer = timerManager.activeTimer {
                activeTimerSection(activeTimer)
            } else {
                clockInSection
            }
            
            // Recent Activity
            recentActivitySection
            
            Spacer()
        }
        .padding()
        .navigationTitle("Time Tracking")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Manual Entry") {
                    showingManualEntry = true
                }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            LogHoursView(isPresented: $showingManualEntry)
                .environmentObject(projectVM)
        }
        .onAppear {
            timerManager.projectVM = projectVM
            locationManager.requestLocationPermission()
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Time Tracking")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let project = projectVM.selectedProject {
                        Text("Project: \(project.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Today's Summary
            if let project = projectVM.selectedProject {
                todaySummaryCard(for: project)
            }
        }
    }
    
    @ViewBuilder
    private func todaySummaryCard(for project: Project) -> some View {
        let todayHours = getTodayHours(for: project)
        let todayEarnings = getTodayEarnings(for: project)
        
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Hours")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(todayHours, specifier: "%.1f") hrs")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Today's Earnings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(todayEarnings.formatAsCurrency())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var clockInSection: some View {
        VStack(spacing: 20) {
            // Team Member Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Team Member")
                    .font(.headline)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(projectVM.teamMembers.filter { $0.employmentStatus.canBeAssignedToProjects }) { member in
                            TeamMemberClockCard(
                                member: member,
                                isSelected: selectedMember?.id == member.id
                            ) {
                                selectedMember = member
                                selectedRate = member.defaultRate
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Rate & Category Selection
            if let member = selectedMember {
                VStack(spacing: 16) {
                    // Rate Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Rate")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(member.rates) { rate in
                                RateSelectionCard(
                                    rate: rate,
                                    isSelected: selectedRate?.id == rate.id
                                ) {
                                    selectedRate = rate
                                }
                            }
                        }
                    }
                    
                    // Category Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Work Category")
                            .font(.headline)
                        
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            
            // Clock In Button
            Button(action: clockIn) {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                    
                    Text("Clock In")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canClockIn ? Color.green : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!canClockIn)
        }
    }
    
    @ViewBuilder
    private func activeTimerSection(_ timer: ActiveTimer) -> some View {
        VStack(spacing: 20) {
            // Active Timer Display
            VStack(spacing: 16) {
                Text("Currently Clocked In")
                    .font(.headline)
                    .foregroundColor(.green)
                
                // Timer Display
                Text(timerManager.elapsedTimeFormatted)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                
                // Timer Details
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "person.fill")
                        Text(timer.employeeName)
                        Spacer()
                        Text(timer.rate.formatAsCurrency() + "/hr")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Image(systemName: "tag.fill")
                        Text(timer.category)
                        Spacer()
                        Text("Started: \(timer.startTime.formatted(date: .omitted, time: .shortened))")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Current Earnings
                let currentEarnings = timerManager.elapsedTime * timer.rate
                Text("Current Earnings: \(currentEarnings.formatAsCurrency())")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            // Notes Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (optional)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Add notes about this work session...", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
            
            // Clock Out Button
            Button(action: clockOut) {
                HStack(spacing: 12) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                    
                    Text("Clock Out")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                Button("View All") {
                    // Navigate to full time history
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if let project = projectVM.selectedProject {
                let recentHours = getRecentHours(for: project)
                
                if recentHours.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("No recent time entries")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(recentHours.prefix(5)) { hour in
                            RecentActivityCard(workHour: hour)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canClockIn: Bool {
        selectedMember != nil && selectedRate != nil && !selectedCategory.isEmpty
    }
    
    // MARK: - Actions
    
    private func clockIn() {
        guard let member = selectedMember,
              let rate = selectedRate else { return }
        
        let timer = ActiveTimer(
            id: UUID(),
            employeeName: member.name,
            employeeID: member.id,
            rate: rate.rate,
            category: selectedCategory,
            startTime: Date(),
            location: locationManager.currentLocation
        )
        
        timerManager.startTimer(timer)
        
        // Reset selections for next use
        selectedMember = nil
        selectedRate = nil
        selectedCategory = "Labor"
    }
    
    private func clockOut() {
        guard let timer = timerManager.activeTimer else { return }
        
        // Create work hour entry
        projectVM.logHours(
            startTime: timer.startTime,
            endTime: Date(),
            employee: timer.employeeName,
            rate: timer.rate,
            category: timer.category,
            lunchBreakDuration: nil // TODO: Add lunch break tracking
        )
        
        timerManager.stopTimer()
        notes = ""
    }
    
    // MARK: - Helper Methods
    
    private func getTodayHours(for project: Project) -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return project.loggedHours
            .filter { $0.date >= today && $0.date < tomorrow }
            .reduce(0) { $0 + $1.hours }
    }
    
    private func getTodayEarnings(for project: Project) -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return project.loggedHours
            .filter { $0.date >= today && $0.date < tomorrow }
            .reduce(0) { $0 + ($1.hours * $1.rate) }
    }
    
    private func getRecentHours(for project: Project) -> [WorkHour] {
        return project.loggedHours
            .sorted { $0.startTime > $1.startTime }
            .prefix(10)
            .compactMap { $0 }
    }
}

// MARK: - Active Timer Model
struct ActiveTimer: Identifiable {
    let id: UUID
    let employeeName: String
    let employeeID: UUID
    let rate: Double
    let category: String
    let startTime: Date
    let location: CLLocation?
}

// MARK: - Time Tracking Manager
class TimeTrackingManager: ObservableObject {
    @Published var activeTimer: ActiveTimer?
    @Published var elapsedTime: TimeInterval = 0
    
    var projectVM: ProjectViewModel?
    private var timer: Timer?
    
    var elapsedTimeFormatted: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) % 3600 / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func startTimer(_ activeTimer: ActiveTimer) {
        self.activeTimer = activeTimer
        self.elapsedTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.elapsedTime = Date().timeIntervalSince(activeTimer.startTime)
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        activeTimer = nil
        elapsedTime = 0
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}

// MARK: - Supporting Views

struct TeamMemberClockCard: View {
    let member: TeamMember
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(member.name.prefix(2)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(isSelected ? .white : .secondary)
                    )
                
                Text(member.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RateSelectionCard: View {
    let rate: EmployeeRate
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(rate.taskType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(rate.rate.formatAsCurrency() + "/hr")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentActivityCard: View {
    let workHour: WorkHour
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workHour.employee)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text(workHour.category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text(workHour.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(workHour.hours, specifier: "%.1f") hrs")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text((workHour.hours * workHour.rate).formatAsCurrency())
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationView {
        LiveTimeTrackingView()
            .environmentObject(ProjectViewModel())
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
    }
}