import SwiftUI

struct LaborModuleView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Binding var selectedTab: Tab
    @State private var showingLogHours = false
    @State private var showingAddEmployee = false
    
    private var hasSelectedProject: Bool {
        projectVM.selectedProject != nil
    }
    
    private var totalUnpaidHours: Double {
        guard let project = projectVM.selectedProject else { return 0 }
        return project.loggedHours.filter { !$0.isPaid }.reduce(0) { $0 + $1.hours }
    }
    
    private var totalUnpaidAmount: Double {
        guard let project = projectVM.selectedProject else { return 0 }
        return project.loggedHours.filter { !$0.isPaid }.reduce(0) { $0 + ($1.hours * $1.rate) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if hasSelectedProject {
                    laborContentView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Labor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Log Hours") {
                            showingLogHours = true
                        }
                        .disabled(!hasSelectedProject)
                        
                        Button("Add Team Member") {
                            showingAddEmployee = true
                        }
                        
                        if hasSelectedProject {
                            NavigationLink("View All Hours") {
                                EmployeeHoursList()
                                    .environmentObject(projectVM)
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingLogHours) {
                if hasSelectedProject {
                    LogHoursView(isPresented: $showingLogHours)
                        .environmentObject(projectVM)
                }
            }
            .sheet(isPresented: $showingAddEmployee) {
                AddEmployeeView(isPresented: $showingAddEmployee)
                    .environmentObject(projectVM)
            }
        }
    }
    
    private var laborContentView: some View {
        List {
            Section("Summary") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Unpaid Hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(totalUnpaidHours, specifier: "%.1f") hrs")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Unpaid Amount")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(totalUnpaidAmount, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Quick Actions") {
                Button(action: { showingLogHours = true }) {
                    Label("Log Hours", systemImage: "clock.fill")
                }
                
                NavigationLink(destination: EmployeeHoursList().environmentObject(projectVM)) {
                    Label("View All Hours", systemImage: "list.bullet")
                }
                
                Button(action: { showingAddEmployee = true }) {
                    Label("Add Team Member", systemImage: "person.badge.plus")
                }
            }
            
            Section("Team Members") {
                ForEach(projectVM.teamMembers) { member in
                    NavigationLink(destination: EmployeeHoursDetailView(employee: member).environmentObject(projectVM)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(member.name)
                                    .font(.headline)
                                Text(member.jobTitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if let defaultRate = member.defaultRate {
                                Text("$\(defaultRate.rate, specifier: "%.2f")/hr")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Project Selected")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Select a project from the Projects tab to track labor hours")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Go to Projects") {
                selectedTab = .projects
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct LaborModuleView_Previews: PreviewProvider {
    static var previews: some View {
        LaborModuleView(selectedTab: .constant(.labor))
            .environmentObject(ProjectViewModel())
    }
}