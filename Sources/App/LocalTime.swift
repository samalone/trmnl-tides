import Foundation

struct LocalTime: Codable, Equatable, Hashable {
    var year: Int
    var month: Int  // 1-based
    var day: Int    // 1-based
    var hour: Int   // 0-based, 24 hours since midnight
    var minute: Int
    
    init(year: Int, month: Int, day: Int, hour: Int, minute: Int) {
        assert(1...12 ~= month)
        assert(1...31 ~= day)
        assert(0...23 ~= hour)
        assert(0...59 ~= minute)
        
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
    }
    
    init(_ date: Date) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        self.year = components.year!
        self.month = components.month!
        self.day = components.day!
        self.hour = components.hour!
        self.minute = components.minute!
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let isoString = try container.decode(String.self)
        self = LocalTime(stringLiteral: isoString)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }
    
    var date: Date {
        let components = DateComponents(calendar: Calendar.current, year: year, month: month, day: day,
                                        hour: hour, minute: minute)
        return Calendar.current.date(from: components)!
    }
    
    var dayOfWeek: Int {
        let components = Calendar.current.dateComponents([.weekday], from: date)
        return components.weekday!
    }
    
    var dayOfWeekName: String {
        let components = Calendar.current.dateComponents([.weekday], from: date)
        return Calendar.current.weekdaySymbols[components.weekday! - 1]
    }
    
    var daysInMonth: Int {
        let components = DateComponents(calendar: Calendar.current, year: year, month: month)
        let date = Calendar.current.date(from: components)!
        let range = Calendar.current.range(of: .day, in: .month, for: date)!
        return range.count
    }
    
    var daysInYear: Int {
        let components = DateComponents(calendar: Calendar.current, year: year)
        let date = Calendar.current.date(from: components)!
        let range = Calendar.current.range(of: .day, in: .year, for: date)!
        return range.count
    }
    
    func daysInMonthToDate() -> Int {
        return day - 1
    }
    
    func daysInMonthFrom() -> Int {
        return daysInMonth - day
    }
    
    var isoString: String {
        let year = String(format: "%04d", self.year)
        let month = String(format: "%02d", self.month)
        let day = String(format: "%02d", self.day)
        let hour = String(format: "%02d", self.hour)
        let minute = String(format: "%02d", self.minute)
        return "\(year)-\(month)-\(day) \(hour):\(minute)"
    }
    
    // The CO-OPS API accepts dates in yyyyMMdd format and
    // date/times in yyyMMdd HH:mm format.
    var coopsDateString: String {
        let year = String(format: "%04d", self.year)
        let month = String(format: "%02d", self.month)
        let day = String(format: "%02d", self.day)
        return "\(year)\(month)\(day)"
    }
    
    var coopsDateTimeString: String {
        let year = String(format: "%04d", self.year)
        let month = String(format: "%02d", self.month)
        let day = String(format: "%02d", self.day)
        let hour = String(format: "%02d", self.hour)
        let minute = String(format: "%02d", self.minute)
        return "\(year)\(month)\(day) \(hour):\(minute)"
    }
    
//    var mediumString: String {
//        return DateFormatter.mediumDate.string(from: date)
//    }
}

extension LocalTime: Comparable {
    static func < (lhs: LocalTime, rhs: LocalTime) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        if lhs.month != rhs.month {
            return lhs.month < rhs.month
        }
        if lhs.day != rhs.day {
            return lhs.day < rhs.day
        }
        if lhs.hour != rhs.hour {
            return lhs.hour < rhs.hour
        }
        return lhs.minute < rhs.minute
    }
    
    static func == (lhs: LocalTime, rhs: LocalTime) -> Bool {
        return lhs.year == rhs.year && lhs.month == rhs.month && lhs.day == rhs.day
            && lhs.hour == rhs.hour && lhs.minute == rhs.minute
    }
}

extension LocalTime: ExpressibleByStringLiteral {
    /// Initialize from s string like "2025-01-02 21:58"
    init(stringLiteral value: String) {
        let parts = value.split(separator: " ")
        let dateParts = parts[0].split(separator: "-").map { Int($0)! }
        let timeParts = parts[1].split(separator: ":").map { Int($0)! }
        self.init(year: dateParts[0], month: dateParts[1], day: dateParts[2],
                  hour: timeParts[0], minute: timeParts[1])
    }
}

extension LocalTime: CustomStringConvertible {
    var description: String {
        isoString
    }
}
