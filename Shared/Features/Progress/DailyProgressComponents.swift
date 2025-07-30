import SwiftUI

// MARK: - Models
struct IdentifiableInt: Identifiable {
    let id: Int
    
    init(_ value: Int) {
        self.id = value
    }
}

struct DailyProgressGroup {
    let date: Date
    let entries: [ProgressLog]
    
    var taskEntries: [ProgressLog] {
        entries.filter { $0.taskID != nil }
    }
    
    var manualEntries: [ProgressLog] {
        entries.filter { $0.taskID == nil }
    }
}

struct WeekPeriod: Identifiable, Hashable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: startDate)
        let endMonth = calendar.component(.month, from: endDate)
        
        if startMonth == endMonth {
            return "Week of \(formatter.string(from: startDate)) - \(calendar.component(.day, from: endDate))"
        } else {
            return "Week of \(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }
}

// MARK: - Week Selector
struct WeekSelectorView: View {
    let weeks: [WeekPeriod]
    @Binding var selectedWeek: WeekPeriod?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(weeks) { week in
                    Button {
                        selectedWeek = week
                    } label: {
                        Text(week.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedWeek?.id == week.id ? Color.blue : Color(.systemGray5))
                            )
                            .foregroundColor(selectedWeek?.id == week.id ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Daily Progress Card
struct DailyProgressCard: View {
    let dailyGroup: DailyProgressGroup
    let employees: [Employee]
    let tasks: [ProjectTask]
    let onTaskTap: (ProjectTask) -> Void
    let onDeleteTask: (ProjectTask) -> Void
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with date and expand/collapse
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dailyGroup.date, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("\(dailyGroup.entries.count) \(dailyGroup.entries.count == 1 ? "entry" : "entries")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: 12) {
                    // Completed Tasks Section
                    if !dailyGroup.taskEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Completed Tasks")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            ForEach(dailyGroup.taskEntries) { entry in
                                TaskProgressEntry(
                                    entry: entry,
                                    employees: employees,
                                    tasks: tasks,
                                    onTaskTap: onTaskTap,
                                    onDeleteTask: onDeleteTask
                                )
                            }
                        }
                    }
                    
                    // Manual Progress Entries Section
                    if !dailyGroup.manualEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundColor(.blue)
                                Text("Manual Progress")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            ForEach(dailyGroup.manualEntries) { entry in
                                ManualProgressEntry(entry: entry, employees: employees)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Task Progress Entry
struct TaskProgressEntry: View {
    let entry: ProgressLog
    let employees: [Employee]
    let tasks: [ProjectTask]
    let onTaskTap: (ProjectTask) -> Void
    let onDeleteTask: (ProjectTask) -> Void
    @State private var selectedImageIndex: IdentifiableInt?
    @State private var showingDeleteAlert = false
    @State private var taskToDelete: ProjectTask?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    if let taskID = entry.taskID,
                       let task = tasks.first(where: { $0.id == taskID }) {
                        onTaskTap(task)
                    }
                } label: {
                    HStack {
                        Text(entry.workDescription)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Delete button for task
                Button {
                    if let taskID = entry.taskID,
                       let task = tasks.first(where: { $0.id == taskID }) {
                        taskToDelete = task
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(4)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !entry.employeeIDs.isEmpty {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(employeeNames(for: entry.employeeIDs))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Photos if any
            if !entry.imageDatas.isEmpty {
                LazyVStack {
                    ForEach(Array(entry.imageDatas.enumerated()), id: \.offset) { index, imageData in
                        if let uiImage = UIImage(data: imageData) {
                            HStack {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipped()
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        selectedImageIndex = IdentifiableInt(index)
                                    }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .fullScreenCover(item: $selectedImageIndex) { identifiableIndex in
            if let imageData = entry.imageDatas[safe: identifiableIndex.id],
               let uiImage = UIImage(data: imageData) {
                ZoomableImageView(image: uiImage) {
                    selectedImageIndex = nil
                }
            }
        }
        .alert("Delete Task", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let task = taskToDelete {
                    onDeleteTask(task)
                }
                taskToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this task? This will remove it from the project and all related progress entries. This action cannot be undone.")
        }
    }
    
    private func employeeNames(for employeeIDs: [UUID]) -> String {
        let names = employeeIDs.compactMap { employeeID in
            employees.first { $0.id == employeeID }?.name
        }
        return names.joined(separator: ", ")
    }
}

// MARK: - Manual Progress Entry
struct ManualProgressEntry: View {
    let entry: ProgressLog
    let employees: [Employee]
    @State private var selectedImageIndex: IdentifiableInt?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.workDescription)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !entry.employeeIDs.isEmpty {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(employeeNames(for: entry.employeeIDs))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Photos if any
            if !entry.imageDatas.isEmpty {
                LazyVStack {
                    ForEach(Array(entry.imageDatas.enumerated()), id: \.offset) { index, imageData in
                        if let uiImage = UIImage(data: imageData) {
                            HStack {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipped()
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        selectedImageIndex = IdentifiableInt(index)
                                    }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .fullScreenCover(item: $selectedImageIndex) { identifiableIndex in
            if let imageData = entry.imageDatas[safe: identifiableIndex.id],
               let uiImage = UIImage(data: imageData) {
                ZoomableImageView(image: uiImage) {
                    selectedImageIndex = nil
                }
            }
        }
    }
    
    private func employeeNames(for employeeIDs: [UUID]) -> String {
        let names = employeeIDs.compactMap { employeeID in
            employees.first { $0.id == employeeID }?.name
        }
        return names.joined(separator: ", ")
    }
}

// Safe array access extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}