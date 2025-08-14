import SwiftUI

struct TimeTrackingWidget: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @State private var showingLiveTracking = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                
                Text("Time Tracking")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingLiveTracking = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Current Status
            if projectVM.activeTimers.isEmpty {
                clockedOutView
            } else {
                activeTimersView
            }
            
            // Quick Stats
            if let project = projectVM.selectedProject {
                quickStatsView(for: project)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingLiveTracking) {
            LiveTimeTrackingView()
                .environmentObject(projectVM)
        }
    }
    
    @ViewBuilder
    private var clockedOutView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.plus")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Ready to Clock In")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            Button(action: { showingLiveTracking = true }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Start Tracking")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.green)
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private var activeTimersView: some View {
        VStack(spacing: 8) {
            ForEach(projectVM.activeTimers.prefix(2)) { timer in
                ActiveTimerRow(timer: timer)
            }
            
            if projectVM.activeTimers.count > 2 {
                Button("View All (\(projectVM.activeTimers.count) active)") {
                    showingLiveTracking = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
    
    @ViewBuilder
    private func quickStatsView(for project: Project) -> some View {
        let todayHours = getTodayHours(for: project)
        let weeklyHours = getWeeklyHours(for: project)
        
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(todayHours, specifier: "%.1f")h")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            VStack(alignment: .center, spacing: 4) {
                Text("This Week")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(weeklyHours, specifier: "%.1f")h")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Active")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(projectVM.activeTimers.count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(projectVM.activeTimers.isEmpty ? .secondary : .green)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTodayHours(for project: Project) -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return project.loggedHours
            .filter { $0.date >= today && $0.date < tomorrow }
            .reduce(0) { $0 + $1.hours }
    }
    
    private func getWeeklyHours(for project: Project) -> Double {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
              let weekEnd = calendar.dateInterval(of: .weekOfYear, for: Date())?.end
        else { return 0 }
        
        return project.loggedHours
            .filter { $0.startTime >= weekStart && $0.startTime < weekEnd }
            .reduce(0) { $0 + $1.hours }
    }
}

struct ActiveTimerRow: View {
    let timer: WorkHour
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(timer.employee)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(timer.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(timer.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(elapsedTime)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var elapsedTime: String {
        let elapsed = Date().timeIntervalSince(timer.startTime)
        let hours = Int(elapsed) / 3600
        let minutes = Int(elapsed) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    TimeTrackingWidget()
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
        .padding()
}