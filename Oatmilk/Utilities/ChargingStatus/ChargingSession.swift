import Foundation

struct BatteryDataPoint: Codable, Identifiable {
    var id: Date { timestamp }
    let timestamp: Date
    let level: Float // 0.0 - 1.0
    let estimatedWatts: Float? // Estimated power based on charge rate

    var percentage: Int {
        Int(level * 100)
    }

    init(timestamp: Date, level: Float, estimatedWatts: Float? = nil) {
        self.timestamp = timestamp
        self.level = level
        self.estimatedWatts = estimatedWatts
    }
}

struct ChargingSession: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    var endDate: Date?
    var dataPoints: [BatteryDataPoint]
    var startLevel: Float
    var endLevel: Float?

    var isActive: Bool {
        endDate == nil
    }

    var duration: TimeInterval {
        let end = endDate ?? Date()
        return end.timeIntervalSince(startDate)
    }

    var durationFormatted: String {
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    var chargeGained: Float {
        let end = endLevel ?? dataPoints.last?.level ?? startLevel
        return end - startLevel
    }

    var chargeGainedPercentage: Int {
        Int(chargeGained * 100)
    }

    var startPercentage: Int {
        Int(startLevel * 100)
    }

    var endPercentage: Int {
        Int((endLevel ?? dataPoints.last?.level ?? startLevel) * 100)
    }

    var averageChargingRate: Float {
        guard duration > 0 else { return 0 }
        return chargeGained / Float(duration / 60) // per minute
    }

    var dateRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let start = formatter.string(from: startDate)
        if let end = endDate {
            formatter.dateStyle = .none
            return "\(start) - \(formatter.string(from: end))"
        }
        return "\(start) - now"
    }

    init(startDate: Date = Date(), startLevel: Float) {
        self.id = UUID()
        self.startDate = startDate
        self.startLevel = startLevel
        self.dataPoints = [BatteryDataPoint(timestamp: startDate, level: startLevel, estimatedWatts: nil)]
    }

    mutating func addDataPoint(level: Float, estimatedWatts: Float?) {
        dataPoints.append(BatteryDataPoint(timestamp: Date(), level: level, estimatedWatts: estimatedWatts))
    }

    mutating func finish(endLevel: Float, estimatedWatts: Float?) {
        self.endDate = Date()
        self.endLevel = endLevel
        addDataPoint(level: endLevel, estimatedWatts: estimatedWatts)
    }

    var maxEstimatedWatts: Float {
        dataPoints.compactMap { $0.estimatedWatts }.max() ?? 0
    }

    var avgEstimatedWatts: Float {
        let watts = dataPoints.compactMap { $0.estimatedWatts }
        guard !watts.isEmpty else { return 0 }
        return watts.reduce(0, +) / Float(watts.count)
    }
}

// MARK: - Persistence

final class ChargingSessionStore {
    private static let sessionsKey = "chargingSessions"

    static func loadSessions() -> [ChargingSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([ChargingSession].self, from: data)
        } catch {
            return []
        }
    }

    static func saveSessions(_ sessions: [ChargingSession]) {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: sessionsKey)
        } catch {
            // Handle silently
        }
    }

    static func addSession(_ session: ChargingSession) {
        var sessions = loadSessions()
        sessions.insert(session, at: 0)
        // Keep only the last 50 sessions
        if sessions.count > 50 {
            sessions = Array(sessions.prefix(50))
        }
        saveSessions(sessions)
    }

    static func updateSession(_ session: ChargingSession) {
        var sessions = loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            saveSessions(sessions)
        }
    }

    static func deleteSession(id: UUID) {
        var sessions = loadSessions()
        sessions.removeAll { $0.id == id }
        saveSessions(sessions)
    }
}
