import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var viewModel = HabitViewModel()
    @State private var showingAddHabit = false
    @State private var editingHabit: Habit? = nil
    @State private var selectedHabit: Habit? = nil
    @State private var orientation = UIDevice.current.orientation
    @State private var activeSheet: ActiveSheet? = nil
    
    enum ActiveSheet: Identifiable {
        case addHabit, editHabit(Habit), habitDetail(Habit)
        
        var id: Int {
            switch self {
            case .addHabit: return 0
            case .editHabit: return 1
            case .habitDetail: return 2
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Date Header
                    HStack(spacing: 0) {
                        Text("")
                            .frame(width: 120, alignment: .leading)
                        
                        ForEach(getVisibleDays(), id: \.self) { date in
                            let calendar = Calendar.current
                            let components = calendar.dateComponents([.day, .month], from: date)
                            let monthName = getMonthName(month: components.month ?? 1)
                            
                            VStack(spacing: 0) {
                                Text(monthName)
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                Text("\(components.day ?? 0)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    
                    if viewModel.habits.isEmpty {
                        EmptyStateView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.habits) { habit in
                                    HabitRowView(habit: habit, viewModel: viewModel, visibleDays: getVisibleDays())
                                        .contentShape(Rectangle())
                                        .contextMenu {
                                            Button(action: {
                                                activeSheet = .editHabit(habit)
                                            }) {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            
                                            Button(role: .destructive, action: {
                                                if let index = viewModel.habits.firstIndex(where: { $0.id == habit.id }) {
                                                    viewModel.deleteHabit(at: IndexSet(integer: index))
                                                }
                                            }) {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .onTapGesture {
                                            activeSheet = .habitDetail(habit)
                                        }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Habits")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        activeSheet = .addHabit
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addHabit:
                    AddHabitView(viewModel: viewModel)
                case .editHabit(let habit):
                    EditHabitView(viewModel: viewModel, habit: habit)
                case .habitDetail(let habit):
                    HabitDetailView(habit: habit, viewModel: viewModel)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                orientation = UIDevice.current.orientation
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }
    
    private func getLastSevenDays() -> [Date] {
        let calendar = Calendar.current
        return (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: Date())! }
    }
    
    private func getVisibleDays() -> [Date] {
        let days = getLastSevenDays()
        // Show last 4 days in portrait, more in landscape
        let isPortrait = orientation.isPortrait || (!orientation.isLandscape && !orientation.isFlat)
        return isPortrait ? Array(days.prefix(4)) : days
    }
    
    private func getMonthName(month: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        let date = Calendar.current.date(from: DateComponents(month: month))!
        return dateFormatter.string(from: date)
    }
}

struct HabitRowView: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    let visibleDays: [Date]
    @State private var editingDate: Date? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(habit.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 120, alignment: .leading)
                    .lineLimit(1)
                
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            
            // Date cells
            HStack(spacing: 0) {
                Text("Streak: \(viewModel.calculateStreak(for: habit))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(habit.color)
                    .frame(width: 120, alignment: .leading)
                
                ForEach(visibleDays, id: \.self) { date in
                    DateCell(habit: habit, date: date, viewModel: viewModel)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(habit.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct DateCell: View {
    let habit: Habit
    let date: Date
    @ObservedObject var viewModel: HabitViewModel
    @State private var showingValueEditor = false
    @State private var showingQuickValueInput = false
    @State private var quickValue: String = ""
    
    var body: some View {
        Button(action: {
            // For yes/no habits, toggle completion status
            if habit.type == .yesNo {
                toggleHabitForDate()
            } else {
                // For measurable habits, show quick input
                showQuickInputForMeasurable()
            }
        }) {
            ZStack {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 22)
                
                // Cell content
                cellContent
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    // Show full editor with memo on long press
                    showingValueEditor = true
                }
        )
        .sheet(isPresented: $showingValueEditor) {
            EditValueView(habit: habit, date: date, viewModel: viewModel)
        }
        .sheet(isPresented: $showingQuickValueInput) {
            QuickValueInputView(
                habit: habit, 
                date: date, 
                viewModel: viewModel,
                initialValue: getCurrentValue(),
                onDismiss: { showingQuickValueInput = false }
            )
        }
    }
    
    private func getCurrentValue() -> String {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        if let entry = habit.history[normalizedDate] {
            return String(format: "%.0f", entry.value)
        } else {
            return ""
        }
    }
    
    private func showQuickInputForMeasurable() {
        showingQuickValueInput = true
    }
    
    @ViewBuilder
    private var cellContent: some View {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        if let entry = habit.history[normalizedDate], entry.value > 0 {
            dateCellWithValue(entry: entry)
        } else {
            Text("-")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    private func dateCellWithValue(entry: HabitEntry) -> some View {
        if habit.type == .yesNo {
            // Check if it's a soft check (weekly habit)
            if entry.value == 0.5 {
                softCheckCell(entry: entry)
            } else {
                yesNoCell(entry: entry)
            }
        } else {
            measurableCell(entry: entry)
        }
    }
    
    @ViewBuilder
    private func softCheckCell(entry: HabitEntry) -> some View {
        Image(systemName: "checkmark")
            .foregroundColor(habit.color.opacity(0.4))
            .font(.system(size: 10))
            .overlay(memoIndicator(memo: entry.memo))
    }
    
    @ViewBuilder
    private func yesNoCell(entry: HabitEntry) -> some View {
        Image(systemName: "checkmark")
            .foregroundColor(habit.color)
            .font(.system(size: 10))
            .overlay(memoIndicator(memo: entry.memo))
    }
    
    @ViewBuilder
    private func measurableCell(entry: HabitEntry) -> some View {
        // For measurable habits, check if goal is achieved
        let hasGoal = habit.goal != nil && habit.goal! > 0
        let goalAchieved = hasGoal && entry.value >= habit.goal!
        
        ZStack {
            // Background achievement indicator
            if goalAchieved {
                Circle()
                    .fill(habit.color.opacity(0.3))
                    .frame(width: 16, height: 16)
            }
            
            // Value
            Text("\(Int(entry.value))")
                .font(.system(size: 10, weight: goalAchieved ? .bold : .regular))
                .foregroundColor(goalAchieved ? habit.color : .green)
                .overlay(memoIndicator(memo: entry.memo))
        }
    }
    
    @ViewBuilder
    private func memoIndicator(memo: String?) -> some View {
        if let memo = memo, !memo.isEmpty {
            Circle()
                .fill(Color.yellow)
                .frame(width: 3, height: 3)
                .offset(x: 6, y: -6)
        } else {
            EmptyView()
        }
    }
    
    private func toggleHabitForDate() {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        if let entry = habit.history[normalizedDate] {
            // Remove the completion for this date (don't preserve the memo)
            viewModel.updateHabitHistory(
                habit: habit, 
                date: normalizedDate, 
                value: nil,
                memo: nil
            )
        } else {
            // Mark as completed for this date
            viewModel.updateHabitHistory(habit: habit, date: normalizedDate, value: 1.0)
        }
    }
}

struct EditValueView: View {
    @Environment(\.presentationMode) var presentationMode
    let habit: Habit
    let date: Date
    @ObservedObject var viewModel: HabitViewModel
    @State private var value: String
    @State private var memo: String
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    private var formattedDate: String {
        return dateFormatter.string(from: date)
    }
    
    init(habit: Habit, date: Date, viewModel: HabitViewModel) {
        self.habit = habit
        self.date = date
        self.viewModel = viewModel
        
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        if let entry = habit.history[normalizedDate] {
            _value = State(initialValue: String(format: "%.0f", entry.value))
            _memo = State(initialValue: entry.memo ?? "")
        } else {
            _value = State(initialValue: "")
            _memo = State(initialValue: "")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Update for \(formattedDate)")) {
                    if habit.type == .measurable {
                        TextField("Value", text: $value)
                            .keyboardType(.numberPad)
                    } else {
                        Toggle("Completed", isOn: Binding(
                            get: { !value.isEmpty },
                            set: { value = $0 ? "1" : "" }
                        ))
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $memo)
                        .frame(minHeight: 100)
                        .background(Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                .padding(-4)
                        )
                        .padding(4)
                }
                
                if habit.type == .yesNo && !value.isEmpty {
                    // Quick actions for yes/no habits
                    Section(header: Text("Quick Actions")) {
                        Button(action: {
                            // Clear the value but keep the memo
                            value = ""
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Mark as Not Completed")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // Help text at the bottom to explain the difference
                Section {
                    Text("This is the full editor where you can add both values and notes. Quick value entry is available with a tap.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveValue()
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .navigationTitle("Update Entry")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func saveValue() {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        if value.isEmpty {
            // Remove the value
            viewModel.updateHabitHistory(habit: habit, date: normalizedDate, value: nil)
        } else if let doubleValue = Double(value) {
            // Update with new value and memo
            viewModel.updateHabitHistory(
                habit: habit,
                date: normalizedDate,
                value: doubleValue,
                memo: memo.isEmpty ? nil : memo
            )
        }
    }
}

struct QuickValueInputView: View {
    let habit: Habit
    let date: Date
    let viewModel: HabitViewModel
    let onDismiss: () -> Void
    
    @State private var value: String
    @Environment(\.presentationMode) var presentationMode
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    init(habit: Habit, date: Date, viewModel: HabitViewModel, initialValue: String, onDismiss: @escaping () -> Void) {
        self.habit = habit
        self.date = date
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        _value = State(initialValue: initialValue)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                // Close button in top-right with safe padding
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 16)
                .padding(.top, 32) // Increased top padding to ensure button is visible
            }
            
            VStack(spacing: 20) {
                Text("\(dateFormatter.string(from: date))")
                    .font(.headline)
                
                // Goal indicator if there is a goal
                if let goal = habit.goal, goal > 0 {
                    Text("Goal: \(Int(goal))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                TextField("Value", text: $value)
                    .keyboardType(.numberPad)
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(habit.color.opacity(0.3), lineWidth: 1)
                    )
                
                Button(action: {
                    saveValue()
                    presentationMode.wrappedValue.dismiss()
                    onDismiss()
                }) {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 160, height: 44)
                        .background(value.isEmpty ? Color.gray : habit.color)
                        .cornerRadius(22)
                }
                .disabled(value.isEmpty)
                .padding(.top, 10)
                
                // Note about long press
                Text("Tip: Long press to add notes")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 20)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .padding(.top, -10) // Adjust content to accommodate larger top padding
            
            Spacer()
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .preferredColorScheme(.dark)
        .frame(height: 380) // Increased height slightly to accommodate the larger top padding
        .compactPresentation()
    }
    
    private func saveValue() {
        if let doubleValue = Double(value) {
            let calendar = Calendar.current
            let normalizedDate = calendar.startOfDay(for: date)
            
            // Preserve existing memo if any
            let existingMemo = habit.history[normalizedDate]?.memo
            
            viewModel.updateHabitHistory(
                habit: habit,
                date: normalizedDate,
                value: doubleValue,
                memo: existingMemo
            )
        }
    }
}

// Helper extension for sheet presentation style
extension View {
    @ViewBuilder
    func compactPresentation() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.height(380)])
        } else {
            self
        }
    }
}

struct HabitDetailView: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedDate: Date? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        // Habit info section
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Habit Info")
                                .font(.headline)
                            
                            HStack(spacing: 8) {
                                Text("Type:")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text(habit.type == .yesNo ? "Yes/No" : "Measurable")
                                    .font(.subheadline)
                            }
                            
                            if habit.type == .yesNo {
                                HStack(spacing: 8) {
                                    Text("Frequency:")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    Text(habit.frequency == .daily ? "Daily" : "Weekly")
                                        .font(.subheadline)
                                }
                                
                                if habit.frequency == .weekly {
                                    Text("This habit is considered completed for 7 days after each check.")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            if habit.type == .measurable, let goal = habit.goal {
                                HStack(spacing: 8) {
                                    Text("Goal:")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    Text("\(Int(goal))")
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        
                        // Calendar section for accessing older dates
                        CalendarSection(habit: habit, viewModel: viewModel, selectedDate: $selectedDate)
                        
                        // Charts section
                        ChartsSection(habit: habit, viewModel: viewModel)
                        
                        // History section
                        HistorySection(habit: habit, viewModel: viewModel)
                    }
                    .padding()
                }
            }
            .navigationTitle(habit.title)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(item: Binding<CalendarDateSelection?>(
                get: { 
                    if let date = selectedDate {
                        return CalendarDateSelection(date: date)
                    }
                    return nil
                },
                set: { selection in
                    selectedDate = selection?.date
                }
            )) { selection in
                EditValueView(habit: habit, date: selection.date, viewModel: viewModel)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }
}

// Helper struct to make Date identifiable for sheet presentation
struct CalendarDateSelection: Identifiable {
    let id = UUID()
    let date: Date
}

struct CalendarSection: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    @Binding var selectedDate: Date?
    @State private var monthOffset = 0
    
    private let calendar = Calendar.current
    
    private var currentMonth: Date {
        let today = Date()
        return calendar.date(byAdding: .month, value: monthOffset, to: today) ?? today
    }
    
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    
    private var monthAndYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private func daysInMonth() -> [Date?] {
        // Get the first day of the month
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: currentMonth)
        )!
        
        // Get the number of days in the month
        let range = calendar.range(of: .day, in: .month, for: monthStart)!
        
        // Get the weekday of the first day (0 is Sunday)
        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1
        
        // Create array with initial nil values for days before the first day of month
        var days = Array<Date?>(repeating: nil, count: firstWeekday)
        
        // Add the days of the month
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        
        // Fill the remaining spaces in the grid with nil
        let remainingDays = 42 - days.count // 6 rows of 7 days
        if remainingDays > 0 {
            days.append(contentsOf: Array<Date?>(repeating: nil, count: remainingDays))
        }
        
        return days
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calendar")
                .font(.headline)
            
            VStack(spacing: 10) {
                // Month navigation
                HStack {
                    Button(action: { monthOffset -= 1 }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text(monthAndYear)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { monthOffset += 1 }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                
                // Days of week
                HStack(spacing: 0) {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 4)
                
                // Calendar grid
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(0..<daysInMonth().count, id: \.self) { index in
                        if let date = daysInMonth()[index] {
                            CalendarDayCell(
                                habit: habit,
                                date: date,
                                viewModel: viewModel,
                                onSelect: { selectedDate = date }
                            )
                        } else {
                            // Empty cell
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 32)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
    }
}

struct CalendarDayCell: View {
    let habit: Habit
    let date: Date
    @ObservedObject var viewModel: HabitViewModel
    let onSelect: () -> Void
    
    private let calendar = Calendar.current
    
    private var day: Int {
        calendar.component(.day, from: date)
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    private var hasEntry: Bool {
        let normalizedDate = calendar.startOfDay(for: date)
        return habit.history[normalizedDate] != nil
    }
    
    private var isSoftCheck: Bool {
        let normalizedDate = calendar.startOfDay(for: date)
        return habit.history[normalizedDate]?.value == 0.5
    }
    
    private var goalAchieved: Bool {
        guard habit.type == .measurable, let goal = habit.goal, goal > 0 else {
            return false
        }
        
        let normalizedDate = calendar.startOfDay(for: date)
        guard let entry = habit.history[normalizedDate] else {
            return false
        }
        
        return entry.value >= goal
    }
    
    var body: some View {
        Button(action: onSelect) {
            ZStack {
                Circle()
                    .fill(isToday ? habit.color.opacity(0.3) : Color.clear)
                    .frame(width: 32, height: 32)
                
                Text("\(day)")
                    .font(.system(size: 12))
                    .foregroundColor(hasEntry ? (isSoftCheck ? habit.color.opacity(0.4) : (goalAchieved ? habit.color : .green)) : .white)
                
                if hasEntry {
                    Circle()
                        .stroke(isSoftCheck ? habit.color.opacity(0.4) : (goalAchieved ? habit.color : .green), lineWidth: 1)
                        .frame(width: 28, height: 28)
                }
            }
        }
        .frame(height: 32)
    }
}

struct ChartsSection: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analytics")
                .font(.headline)
            
            // Weekly chart - fix the containment hierarchy
            VStack(alignment: .leading, spacing: 8) {
                Text("Last 7 Days")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Fixed container with explicit height
                ZStack {
                    SimpleWeeklyChart(habit: habit, viewModel: viewModel)
                }
                .frame(height: 180)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
            
            // Monthly chart - fix the containment hierarchy
            VStack(alignment: .leading, spacing: 8) {
                Text("Monthly Completion")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Fixed container with explicit height
                ZStack {
                    SimpleMonthlyChart(habit: habit, viewModel: viewModel)
                }
                .frame(height: 180)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
    }
}

struct SimpleWeeklyChart: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    
    var body: some View {
        // Break up complex expressions
        let weekData = viewModel.getWeeklyCompletionData(for: habit)
        let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let maxValue = max(1.0, weekData.max() ?? 1.0)
        let validDays = min(weekdays.count, weekData.count)
        
        return HStack(alignment: .bottom, spacing: 8) {
            weekBars(weekData: weekData, weekdays: weekdays, maxValue: maxValue, validDays: validDays)
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
    }
    
    @ViewBuilder
    private func weekBars(weekData: [Double], weekdays: [String], maxValue: Double, validDays: Int) -> some View {
        if validDays <= 0 {
            Text("No data available")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
        } else {
            ForEach(0..<validDays, id: \.self) { index in
                weekBar(index: index, value: weekData[index], day: weekdays[index], maxValue: maxValue)
            }
        }
    }
    
    @ViewBuilder
    private func weekBar(index: Int, value: Double, day: String, maxValue: Double) -> some View {
        let height = value / maxValue
        let barHeight = max(value > 0 ? 20 : 1, CGFloat(height) * 140)
        
        // Check if goal is achieved for styling
        let hasGoal = habit.goal != nil && habit.goal! > 0
        let goalAchieved = hasGoal && value >= habit.goal!
        
        VStack(spacing: 4) {
            ZStack {
                Rectangle()
                    .fill(goalAchieved ? habit.color : habit.color.opacity(0.6))
                    .frame(height: barHeight)
                    .cornerRadius(4)
                
                // Value displayed inside the bar in the middle
                if value > 0 {
                    Text("\(Int(value))")
                        .font(.system(size: 10, weight: goalAchieved ? .bold : .regular))
                        .foregroundColor(.white)
                }
            }
            
            Text(day)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SimpleMonthlyChart: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    
    private let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    
    var body: some View {
        // Break up complex expressions into smaller parts
        let monthData = viewModel.getMonthlyCompletionData(for: habit)
        let maxValue = max(1, monthData.max() ?? 1)
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 16) {
                monthBars(monthData: monthData, maxValue: maxValue)
            }
            .padding(.top, 20)
            .padding(.horizontal)
            .frame(minHeight: 160)
        }
    }
    
    @ViewBuilder
    private func monthBars(monthData: [Int], maxValue: Int) -> some View {
        if months.isEmpty {
            EmptyView()
        } else {
            ForEach(0..<months.count, id: \.self) { index in
                monthBar(for: index, monthData: monthData, maxValue: maxValue)
            }
        }
    }
    
    @ViewBuilder
    private func monthBar(for index: Int, monthData: [Int], maxValue: Int) -> some View {
        let value = index < monthData.count ? monthData[index] : 0
        let height = Double(value) / Double(maxValue)
        let barHeight = max(value > 0 ? 20 : 1, CGFloat(height) * 130)
        
        // For daily goal, multiply by 30 for monthly comparison (approximation)
        let monthlyGoalCount = (habit.goal != nil) ? Int(habit.goal! * 30) : 0
        let goalAchieved = monthlyGoalCount > 0 && value >= monthlyGoalCount
        
        VStack(spacing: 6) {
            ZStack {
                Rectangle()
                    .fill(goalAchieved ? habit.color : habit.color.opacity(0.6))
                    .frame(width: 28, height: barHeight)
                    .cornerRadius(4)
                
                // Value displayed inside the bar in the middle
                if value > 0 {
                    Text("\(value)")
                        .font(.system(size: 10, weight: goalAchieved ? .bold : .regular))
                        .foregroundColor(.white)
                }
            }
            
            Text(months[index])
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 30, alignment: .center)
        }
        .frame(width: 30)
    }
}

struct HistorySection: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History with Notes")
                .font(.headline)
            
            // Get data first and ensure it's valid
            let historyEntries = getSortedHistoryEntries()
            
            // Create entries list
            if historyEntries.isEmpty {
                Text("No history entries yet")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(historyEntries.indices, id: \.self) { index in
                        historyEntryView(for: historyEntries[index])
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func historyEntryView(for entry: (date: Date, value: HabitEntry)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dateFormatter.string(from: entry.date))
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                entryValueView(for: entry)
            }
            
            if let memo = entry.value.memo, !memo.isEmpty {
                Text(memo)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func entryValueView(for entry: (date: Date, value: HabitEntry)) -> some View {
        if habit.type == .yesNo {
            // Check if it's a soft check (weekly habit)
            if entry.value.value == 0.5 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(habit.color.opacity(0.4))
                    .overlay(
                        Text("W")
                            .font(.system(size: 8))
                            .foregroundColor(habit.color)
                            .offset(x: 8, y: -8)
                    )
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(habit.color)
            }
        } else {
            // Check if goal was achieved for this entry
            let hasGoal = habit.goal != nil && habit.goal! > 0
            let goalAchieved = hasGoal && entry.value.value >= habit.goal!
            
            Text("\(Int(entry.value.value))")
                .font(.system(size: 14, weight: goalAchieved ? .bold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(goalAchieved ? habit.color.opacity(0.3) : Color.blue.opacity(0.2))
                )
                .foregroundColor(goalAchieved ? habit.color : .white)
        }
    }
    
    private func getSortedHistoryEntries() -> [(date: Date, value: HabitEntry)] {
        // Dictionary keys can't be nil, so we don't need to filter
        return habit.history
            .map { (date: $0.key, value: $0.value) }
            .sorted { $0.date > $1.date }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No habits yet")
                .font(.title2)
                .foregroundColor(.gray)
            Text("Tap the + button to add your first habit")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

struct AddHabitView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: HabitViewModel
    @State private var habitTitle = ""
    @State private var habitType: HabitType = .yesNo
    @State private var habitFrequency: HabitFrequency = .daily
    @State private var selectedColor: Color = .green
    @State private var goalValue: String = ""
    
    private let colorOptions: [Color] = [.green, .blue, .red, .orange, .purple, .teal, .pink]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Habit")) {
                    TextField("Enter habit title", text: $habitTitle)
                    
                    Picker("Habit Type", selection: $habitType) {
                        Text("Yes/No").tag(HabitType.yesNo)
                        Text("Measurable").tag(HabitType.measurable)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if habitType == .yesNo {
                        Picker("Frequency", selection: $habitFrequency) {
                            Text("Daily").tag(HabitFrequency.daily)
                            Text("Weekly").tag(HabitFrequency.weekly)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Text("Weekly habits will count as completed for the next 6 days after checking once.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if habitType == .measurable {
                        TextField("Goal Value", text: $goalValue)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section(header: Text("Appearance")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(colorOptions, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Add Habit")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Add") {
                    if !habitTitle.isEmpty {
                        // Create a new habit with selected color and goal
                        var goal: Double? = nil
                        if habitType == .measurable, let goalDouble = Double(goalValue) {
                            goal = goalDouble
                        }
                        
                        viewModel.addHabit(
                            title: habitTitle,
                            type: habitType,
                            frequency: habitFrequency,
                            color: selectedColor,
                            goal: goal
                        )
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(habitTitle.isEmpty || (habitType == .measurable && goalValue.isEmpty))
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct EditHabitView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: HabitViewModel
    let habit: Habit
    @State private var habitTitle: String
    @State private var habitType: HabitType
    @State private var habitFrequency: HabitFrequency
    @State private var measurement: String = ""
    @State private var selectedColor: Color
    @State private var goalValue: String = ""
    
    private let colorOptions: [Color] = [.green, .blue, .red, .orange, .purple, .teal, .pink]
    
    init(viewModel: HabitViewModel, habit: Habit) {
        self.viewModel = viewModel
        self.habit = habit
        _habitTitle = State(initialValue: habit.title)
        _habitType = State(initialValue: habit.type)
        _habitFrequency = State(initialValue: habit.frequency)
        _selectedColor = State(initialValue: habit.color)
        
        if let measurement = habit.measurement {
            _measurement = State(initialValue: String(format: "%.0f", measurement))
        }
        
        if let goal = habit.goal {
            _goalValue = State(initialValue: String(format: "%.0f", goal))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Habit")) {
                    TextField("Habit Title", text: $habitTitle)
                    
                    Picker("Habit Type", selection: $habitType) {
                        Text("Yes/No").tag(HabitType.yesNo)
                        Text("Measurable").tag(HabitType.measurable)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if habitType == .yesNo {
                        Picker("Frequency", selection: $habitFrequency) {
                            Text("Daily").tag(HabitFrequency.daily)
                            Text("Weekly").tag(HabitFrequency.weekly)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Text("Weekly habits will count as completed for the next 6 days after checking once.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if habitType == .measurable {
                        TextField("Current Value", text: $measurement)
                            .keyboardType(.numberPad)
                        
                        TextField("Goal Value", text: $goalValue)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section(header: Text("Appearance")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(colorOptions, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Edit Habit")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveHabit()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(habitTitle.isEmpty || (habitType == .measurable && goalValue.isEmpty))
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func saveHabit() {
        guard let index = viewModel.habits.firstIndex(where: { $0.id == habit.id }) else { return }
        
        let previousFrequency = viewModel.habits[index].frequency
        let wasChanged = habitFrequency != previousFrequency
        
        viewModel.habits[index].title = habitTitle
        viewModel.habits[index].type = habitType
        viewModel.habits[index].frequency = habitFrequency
        viewModel.habits[index].color = selectedColor
        
        // If changed from daily to weekly, add soft checks
        if wasChanged && habitType == .yesNo && habitFrequency == .weekly {
            // Find the last completed day
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            // Look for recent hard checks within the last 7 days
            for dayOffset in 0..<7 {
                if let checkDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                    if let entry = viewModel.habits[index].history[checkDate], entry.value == 1.0 {
                        // Found a hard check, add soft checks for the next days
                        for i in 1...6 {
                            if let nextDate = calendar.date(byAdding: .day, value: i, to: checkDate) {
                                if viewModel.habits[index].history[nextDate] == nil {
                                    // Add soft checks only if there's no entry yet
                                    viewModel.habits[index].history[nextDate] = HabitEntry(value: 0.5)
                                }
                            }
                        }
                        break
                    }
                }
            }
        }
        
        // If changed from weekly to daily, remove soft checks
        if wasChanged && habitType == .yesNo && habitFrequency == .daily {
            // Find and remove all soft checks
            let softChecks = viewModel.habits[index].history.filter { $0.value.value == 0.5 }
            for (date, _) in softChecks {
                viewModel.habits[index].history.removeValue(forKey: date)
            }
        }
        
        if habitType == .measurable {
            if let value = Double(measurement) {
                viewModel.updateMeasurement(habit: viewModel.habits[index], measurement: value)
            }
            
            if let goal = Double(goalValue) {
                viewModel.habits[index].goal = goal
            }
        } else {
            // If switching to yes/no type, remove the goal
            viewModel.habits[index].goal = nil
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 

