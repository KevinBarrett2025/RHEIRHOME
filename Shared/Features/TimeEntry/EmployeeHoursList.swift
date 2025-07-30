import SwiftUI

struct EmployeeHoursList: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    
    private var groupedHours: [String: [WorkHour]] {
        return projectVM.groupedHoursByTeamMember
    }
    
    var body: some View {
        List {
            if groupedHours.isEmpty {
                Section {
                    Text("No hours logged yet")
                        .foregroundColor(.secondary)
                        .padding()
                }
            } else {
                ForEach(Array(groupedHours.keys.sorted()), id: \.self) { employeeName in
                    if let hours = groupedHours[employeeName] {
                        Section(employeeName) {
                            ForEach(hours.sorted { $0.date > $1.date }) { hour in
                                EmployeeHourRowView(workHour: hour)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("All Hours")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct EmployeeHourRowView: View {
    let workHour: WorkHour
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workHour.date, style: .date)
                    .font(.headline)
                
                Text("\(workHour.startTime, style: .time) - \(workHour.endTime ?? Date(), style: .time)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !workHour.category.isEmpty {
                    Text(workHour.category)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(workHour.hours, specifier: "%.1f") hrs")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("@ \(workHour.rate.formatAsCurrency())/hr")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text((workHour.hours * workHour.rate).formatAsCurrency())
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(workHour.isPaid ? .green : .orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmployeeHoursList_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EmployeeHoursList()
                .environmentObject(ProjectViewModel())
        }
    }
}