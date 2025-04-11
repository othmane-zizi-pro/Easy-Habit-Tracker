import Foundation
import SwiftUI

class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    private let saveKey = "savedHabits"
    
    init() {
        loadHabits()
    }
    
    func addHabit(title: String, type: HabitType, frequency: HabitFrequency = .daily, color: Color = .green, goal: Double? = nil) {
        let habit = Habit(title: title, type: type, frequency: frequency, color: color, goal: goal)
        habits.append(habit)
        saveHabits()
    }
    
    func toggleHabit(habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].isCompleted.toggle()
            let today = Calendar.current.startOfDay(for: Date())
            if habits[index].isCompleted {
                habits[index].history[today] = HabitEntry(value: 1.0)
                
                // If it's a weekly habit, add soft checks for the next 6 days
                if habits[index].type == .yesNo && habits[index].frequency == .weekly {
                    addSoftChecksForWeeklyHabit(habitIndex: index, startDate: today)
                }
            } else {
                habits[index].history.removeValue(forKey: today)
                
                // If it's a weekly habit, remove soft checks
                if habits[index].type == .yesNo && habits[index].frequency == .weekly {
                    removeSoftChecksForWeeklyHabit(habitIndex: index, startDate: today)
                }
            }
            saveHabits()
        }
    }
    
    private func addSoftChecksForWeeklyHabit(habitIndex: Int, startDate: Date) {
        let calendar = Calendar.current
        
        // Add soft checks for the next 6 days
        for dayOffset in 1...6 {
            if let nextDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                // Use 0.5 value to indicate a soft check (weekly habit)
                habits[habitIndex].history[nextDate] = HabitEntry(value: 0.5)
            }
        }
    }
    
    private func removeSoftChecksForWeeklyHabit(habitIndex: Int, startDate: Date) {
        let calendar = Calendar.current
        
        // Remove soft checks for the next 6 days
        for dayOffset in 1...6 {
            if let nextDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                habits[habitIndex].history.removeValue(forKey: nextDate)
            }
        }
    }
    
    func updateMeasurement(habit: Habit, measurement: Double) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].measurement = measurement
            let today = Calendar.current.startOfDay(for: Date())
            habits[index].history[today] = HabitEntry(value: measurement)
            saveHabits()
        }
    }
    
    func deleteHabit(at indexSet: IndexSet) {
        habits.remove(atOffsets: indexSet)
        saveHabits()
    }
    
    func calculateStreak(for habit: Habit) -> Int {
        let sortedDates = habit.history.keys.sorted(by: >)
        var streak = 0
        var previousDate: Date? = nil
        
        for date in sortedDates {
            if let prev = previousDate {
                let calendar = Calendar.current
                let isConsecutive = calendar.isDate(date, inSameDayAs: prev) || 
                                   calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: prev)!)
                if isConsecutive {
                    streak += 1
                } else {
                    break
                }
            } else {
                streak += 1
            }
            previousDate = date
        }
        
        return streak
    }
    
    func updateHabitHistory(habit: Habit, date: Date, value: Double?, memo: String? = nil) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            let calendar = Calendar.current
            let normalizedDate = calendar.startOfDay(for: date)
            
            if let value = value {
                // Update or add the value for this date
                let existingMemo = habits[index].history[normalizedDate]?.memo
                habits[index].history[normalizedDate] = HabitEntry(value: value, memo: memo ?? existingMemo)
                
                // If it's a weekly habit with a hard check (value=1.0), add soft checks
                if habits[index].type == .yesNo && habits[index].frequency == .weekly && value == 1.0 {
                    addSoftChecksForWeeklyHabit(habitIndex: index, startDate: normalizedDate)
                }
                
                // If this is today, also update the current measurement
                if calendar.isDateInToday(normalizedDate) {
                    habits[index].measurement = value
                    habits[index].isCompleted = value > 0
                }
            } else {
                // Remove the entry for this date
                let wasHardCheck = habits[index].history[normalizedDate]?.value == 1.0
                habits[index].history.removeValue(forKey: normalizedDate)
                
                // If it was a hard check for a weekly habit, remove the soft checks too
                if wasHardCheck && habits[index].type == .yesNo && habits[index].frequency == .weekly {
                    removeSoftChecksForWeeklyHabit(habitIndex: index, startDate: normalizedDate)
                }
                
                // If this is today, also update the current measurement
                if calendar.isDateInToday(normalizedDate) {
                    habits[index].measurement = nil
                    habits[index].isCompleted = false
                }
            }
            saveHabits()
        }
    }
    
    // Check if a date has a soft check (part of a weekly habit)
    func isSoftCheck(habit: Habit, date: Date) -> Bool {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        return habit.history[normalizedDate]?.value == 0.5
    }
    
    func updateMemo(habit: Habit, date: Date, memo: String?) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            if var entry = habits[index].history[date] {
                entry.memo = memo
                habits[index].history[date] = entry
                saveHabits()
            }
        }
    }
    
    func getCompletionRate(for habit: Habit) -> Double {
        let totalDays = Calendar.current.dateComponents([.day], from: habit.creationDate, to: Date()).day ?? 1
        return Double(habit.history.count) / Double(totalDays)
    }
    
    func getWeeklyCompletionData(for habit: Habit) -> [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var weekData: [Double] = Array(repeating: 0, count: 7)
        
        for i in 0..<7 {
            if let dayInPast = calendar.date(byAdding: .day, value: -i, to: today) {
                if let entry = habit.history[dayInPast] {
                    weekData[6-i] = entry.value
                }
            }
        }
        
        return weekData
    }
    
    func getMonthlyCompletionData(for habit: Habit) -> [Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var monthData = Array(repeating: 0, count: 12)
        
        for (date, _) in habit.history {
            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date)
            let currentYear = calendar.component(.year, from: today)
            
            if year == currentYear {
                monthData[month-1] += 1
            }
        }
        
        return monthData
    }
    
    private func saveHabits() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        }
    }
} 