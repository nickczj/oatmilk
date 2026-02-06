import Foundation
import UserNotifications
import Observation

// MARK: - Office Day Entry

struct OfficeDayEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    var note: String?

    init(date: Date, note: String? = nil) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.note = note
    }

    var dayOfMonth: Int {
        Calendar.current.component(.day, from: date)
    }
}

// MARK: - Monthly Summary

struct MonthlySummary {
    let year: Int
    let month: Int
    let targetDays: Int
    let loggedDays: Int
    let entries: [OfficeDayEntry]

    var remaining: Int {
        max(0, targetDays - loggedDays)
    }

    var isComplete: Bool {
        loggedDays >= targetDays
    }

    var progress: Double {
        guard targetDays > 0 else { return 0 }
        return min(1.0, Double(loggedDays) / Double(targetDays))
    }

    var workingDaysLeft: Int {
        let calendar = Calendar.current
        let today = Date()

        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return 0
        }

        let startDate = max(today, monthStart)
        guard startDate <= monthEnd else { return 0 }

        var count = 0
        var currentDate = startDate

        while currentDate <= monthEnd {
            let weekday = calendar.component(.weekday, from: currentDate)
            // Monday = 2, Friday = 6
            if weekday >= 2 && weekday <= 6 {
                count += 1
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return count
    }

    var isBehindSchedule: Bool {
        guard !isComplete else { return false }
        return remaining > workingDaysLeft
    }

    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "" }
        return formatter.string(from: date)
    }
}

// MARK: - Office Tracker Service

@Observable
final class OfficeTrackerService {
    private static let entriesKey = "officeTrackerEntries"
    private static let targetKey = "officeTrackerTarget"
    private static let notificationsEnabledKey = "officeTrackerNotifications"

    var entries: [OfficeDayEntry] = []
    var monthlyTarget: Int = 9
    var notificationsEnabled: Bool = false

    init() {
        loadData()
        checkNotificationStatus()
    }

    // MARK: - Current Month

    var currentMonthSummary: MonthlySummary {
        summary(for: Date())
    }

    func summary(for date: Date) -> MonthlySummary {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        let monthEntries = entries.filter { entry in
            let entryYear = calendar.component(.year, from: entry.date)
            let entryMonth = calendar.component(.month, from: entry.date)
            return entryYear == year && entryMonth == month
        }

        return MonthlySummary(
            year: year,
            month: month,
            targetDays: monthlyTarget,
            loggedDays: monthEntries.count,
            entries: monthEntries.sorted { $0.date < $1.date }
        )
    }

    // MARK: - Entry Management

    func isDateLogged(_ date: Date) -> Bool {
        let dayStart = Calendar.current.startOfDay(for: date)
        return entries.contains { Calendar.current.isDate($0.date, inSameDayAs: dayStart) }
    }

    func toggleDate(_ date: Date) {
        let dayStart = Calendar.current.startOfDay(for: date)

        if let index = entries.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: dayStart) }) {
            entries.remove(at: index)
        } else {
            entries.append(OfficeDayEntry(date: dayStart))
        }

        saveData()
        scheduleNotificationIfNeeded()
    }

    func addEntry(for date: Date, note: String? = nil) {
        guard !isDateLogged(date) else { return }
        entries.append(OfficeDayEntry(date: date, note: note))
        saveData()
        scheduleNotificationIfNeeded()
    }

    func removeEntry(for date: Date) {
        let dayStart = Calendar.current.startOfDay(for: date)
        entries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: dayStart) }
        saveData()
        scheduleNotificationIfNeeded()
    }

    func updateTarget(_ newTarget: Int) {
        monthlyTarget = max(1, newTarget)
        UserDefaults.standard.set(monthlyTarget, forKey: Self.targetKey)
        scheduleNotificationIfNeeded()
    }

    // MARK: - Persistence

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: Self.entriesKey),
           let decoded = try? JSONDecoder().decode([OfficeDayEntry].self, from: data) {
            entries = decoded
        }

        let savedTarget = UserDefaults.standard.integer(forKey: Self.targetKey)
        monthlyTarget = savedTarget > 0 ? savedTarget : 9

        notificationsEnabled = UserDefaults.standard.bool(forKey: Self.notificationsEnabledKey)
    }

    private func saveData() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: Self.entriesKey)
        }
    }

    // MARK: - Notifications

    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                notificationsEnabled = granted
                UserDefaults.standard.set(granted, forKey: Self.notificationsEnabledKey)
                if granted {
                    scheduleNotificationIfNeeded()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    func toggleNotifications(_ enabled: Bool) {
        notificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.notificationsEnabledKey)

        if enabled {
            Task {
                await requestNotificationPermission()
            }
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus != .authorized {
                    self.notificationsEnabled = false
                    UserDefaults.standard.set(false, forKey: Self.notificationsEnabledKey)
                }
            }
        }
    }

    func scheduleNotificationIfNeeded() {
        guard notificationsEnabled else { return }

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let summary = currentMonthSummary
        guard summary.isBehindSchedule else { return }

        let content = UNMutableNotificationContent()
        content.title = "Office Days Reminder"
        content.body = "You have \(summary.remaining) office days remaining with only \(summary.workingDaysLeft) working days left this month."
        content.sound = .default

        // Schedule for tomorrow at 9 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "officeTracker.behindSchedule",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Calendar Helpers

    func entriesForMonth(year: Int, month: Int) -> [OfficeDayEntry] {
        let calendar = Calendar.current
        return entries.filter { entry in
            let entryYear = calendar.component(.year, from: entry.date)
            let entryMonth = calendar.component(.month, from: entry.date)
            return entryYear == year && entryMonth == month
        }
    }

    func daysInMonth(year: Int, month: Int) -> Int {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month)
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 30
        }
        return range.count
    }

    func firstWeekdayOfMonth(year: Int, month: Int) -> Int {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = calendar.date(from: components) else { return 1 }
        // Returns 1 for Sunday, 2 for Monday, etc.
        return calendar.component(.weekday, from: date)
    }
}
