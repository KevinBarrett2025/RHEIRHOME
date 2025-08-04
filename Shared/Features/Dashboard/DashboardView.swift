//  DashboardView.swift
//  RheirMultiplatformApp

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Overview for")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let p = projectVM.selectedProject {
                    Text(p.name)
                        .font(.title2).bold()

                    HStack {
                        // Show the budgeted labor cost
                        VStack {
                            Text("Labor")
                            Text(p.laborCost.formatAsCurrency())
                        }

                        Spacer()

                        // Sum of your three expense buckets
                        VStack {
                            Text("Expenses")
                            let spent = projectVM.spentGeneralConditions
                                     + projectVM.spentMaterials
                                     + projectVM.spentContingency
                            Text(spent.formatAsCurrency())
                        }

                        Spacer()

                        // Total budget
                        VStack {
                            Text("Budget")
                            Text(p.totalBudget.formatAsCurrency())
                        }
                    }
                    .padding()
                } else {
                    Text("Select a project to get started.")
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        // match your Project initializer exactly
        let sampleProject = Project(
            id: UUID(),
            name: "Demo Project",
            client: "Acme Corp",
            phone: "",
            street: "",
            city: "",
            state: "",
            zip: "",
            notes: "",
            totalBudget: 5_000,
            materialCost:      200,
            laborCost:         300,
            generalConditions: 100,
            contingency:       50,
            spentContingency:  25,
            profit:            500,
            startDate: .now.addingTimeInterval(-86_400),
            endDate:   .now.addingTimeInterval(86_400),
            loggedHours:    [],
            tasks:          [],
            communications: [],
            progressLogs:   [],
            changeOrders:   [],
            receipts:       [],
            taskTemplates:  [],
            status: .active
        )

        let vm = ProjectViewModel(cloudKitService: CloudKitAuthService())
        vm.organizationProjects = [sampleProject]
        vm.selectedProject = sampleProject

        return DashboardView()
            .environmentObject(vm)
    }
}