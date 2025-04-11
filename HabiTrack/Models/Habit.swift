import Foundation
import SwiftUI

enum HabitType: String, Codable {
    case yesNo
    case measurable
}

enum HabitFrequency: String, Codable {
    case daily
    case weekly
}

struct HabitEntry: Codable, Equatable {
    var value: Double
    var memo: String?
    
    init(value: Double, memo: String? = nil) {
        self.value = value
        self.memo = memo
    }
}

// ColorCodable wrapper to make Color codable
struct ColorCodable: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
    
    init(color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        self.red = Double(red)
        self.green = Double(green)
        self.blue = Double(blue)
        self.opacity = Double(alpha)
    }
    
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

struct Habit: Identifiable, Codable {
    var id: UUID
    var title: String
    var type: HabitType
    var frequency: HabitFrequency
    var isCompleted: Bool
    var measurement: Double?
    var history: [Date: HabitEntry]
    var creationDate: Date
    var colorData: ColorCodable
    var goal: Double?
    
    var color: Color {
        get { colorData.color }
        set { colorData = ColorCodable(color: newValue) }
    }
    
    init(id: UUID = UUID(), 
         title: String, 
         type: HabitType, 
         frequency: HabitFrequency = .daily,
         isCompleted: Bool = false, 
         measurement: Double? = nil, 
         color: Color = .green, 
         goal: Double? = nil) {
        self.id = id
        self.title = title
        self.type = type
        self.frequency = frequency
        self.isCompleted = isCompleted
        self.measurement = measurement
        self.history = [:]
        self.creationDate = Date()
        self.colorData = ColorCodable(color: color)
        self.goal = goal
    }
} 