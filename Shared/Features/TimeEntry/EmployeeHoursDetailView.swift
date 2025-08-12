import SwiftUI

struct EmployeeHoursDetailView: View {
    let employee: TeamMember
    @EnvironmentObject var projectVM: ProjectViewModel
    
    private var employeeHours: [WorkHour] {
        return projectVM.groupedHoursByTeamMember[employee.name] ?? []
    }
    
    private var totalHours: Double {
        return employeeHours.reduce(0) { $0 + $1.hours }
    }
    
    private var totalPay: Double {
        return employeeHours.reduce(0) { $0 + ($1.hours * $1.rate) }
    }
    
    private var unpaidHours: Double {
        return employeeHours.filter { !$0.isPaid }.reduce(0) { $0 + $1.hours }
    }
    
    private var unpaidPay: Double {
        return employeeHours.filter { !$0.isPaid }.reduce(0) { $0 + ($1.hours * $1.rate) }
    }
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(totalHours, specifier: "%.1f")")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Total Pay")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(totalPay.formatAsCurrency())
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Unpaid Hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(unpaidHours, specifier: "%.1f")")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Unpaid Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(unpaidPay.formatAsCurrency())
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.vertical)
            }
            
            Section("Work History") {
                if employeeHours.isEmpty {
                    Text("No hours logged yet")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(employeeHours.sorted { $0.date > $1.date }) { hour in
                        EmployeeHourRowView(workHour: hour)
                    }
                }
            }
        }
        .navigationTitle(employee.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct EmployeeHoursDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEmployee = TeamMember(
            name: "John Doe",
            email: "john@example.com",
            jobTitle: "Carpenter",
            organizationID: "RHEIR-LLC-MAIN-ORG"
        )
        
        NavigationStack {
            EmployeeHoursDetailView(employee: sampleEmployee)
                .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
        }
    }
}