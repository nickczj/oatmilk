import Foundation
import UIKit
import Observation

@Observable
final class BatteryService {
    // Current readings
    var batteryLevel: Float = 0
    var batteryState: UIDevice.BatteryState = .unknown
    var isLowPowerMode: Bool = false
    var thermalState: ProcessInfo.ThermalState = .nominal

    // Charging rate tracking
    var chargingRatePerMinute: Float = 0
    var estimatedMinutesToFull: Int?
    var estimatedWatts: Float = 0

    // Session recording
    var activeSession: ChargingSession?
    var isRecording: Bool { activeSession != nil }
    var savedSessions: [ChargingSession] = []

    // Typical iPhone battery capacity in Wh (used for wattage estimation)
    private let estimatedBatteryCapacityWh: Float = 14.0

    private var levelSamples: [(date: Date, level: Float)] = []
    private var sampleTimer: Timer?
    private var sessionSampleTimer: Timer?

    init() {
        loadSavedSessions()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Session Recording

    func startRecording() {
        guard activeSession == nil else { return }
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return }

        activeSession = ChargingSession(startLevel: level)

        // Sample every 60 seconds during recording for the curve
        sessionSampleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.recordSessionSample()
        }
    }

    func stopRecording() {
        guard var session = activeSession else { return }

        sessionSampleTimer?.invalidate()
        sessionSampleTimer = nil

        let level = UIDevice.current.batteryLevel
        session.finish(endLevel: level, estimatedWatts: estimatedWatts)

        ChargingSessionStore.addSession(session)
        loadSavedSessions()
        activeSession = nil
    }

    func cancelRecording() {
        sessionSampleTimer?.invalidate()
        sessionSampleTimer = nil
        activeSession = nil
    }

    func deleteSession(id: UUID) {
        ChargingSessionStore.deleteSession(id: id)
        loadSavedSessions()
    }

    private func loadSavedSessions() {
        savedSessions = ChargingSessionStore.loadSessions()
    }

    private func recordSessionSample() {
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return }
        activeSession?.addDataPoint(level: level, estimatedWatts: estimatedWatts)

        // Persist in-progress session
        if let session = activeSession {
            ChargingSessionStore.updateSession(session)
        }
    }

    func startMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refreshReadings()

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshReadings()
        }

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshReadings()
        }

        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.thermalState = ProcessInfo.processInfo.thermalState
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }

        // Sample battery level every 30 seconds to calculate charge rate
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.recordSample()
        }
        recordSample()
    }

    func stopMonitoring() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    private func refreshReadings() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermalState = ProcessInfo.processInfo.thermalState
    }

    private func recordSample() {
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return }

        let now = Date()
        levelSamples.append((date: now, level: level))

        // Keep only the last 5 minutes of samples
        let cutoff = now.addingTimeInterval(-300)
        levelSamples.removeAll { $0.date < cutoff }

        calculateChargingRate()
    }

    private func calculateChargingRate() {
        guard levelSamples.count >= 2,
              batteryState == .charging else {
            chargingRatePerMinute = 0
            estimatedMinutesToFull = nil
            estimatedWatts = 0
            return
        }

        let oldest = levelSamples.first!
        let newest = levelSamples.last!
        let elapsed = newest.date.timeIntervalSince(oldest.date) / 60.0

        guard elapsed > 0 else { return }

        let levelDelta = newest.level - oldest.level
        chargingRatePerMinute = Float(Double(levelDelta) / elapsed)

        if chargingRatePerMinute > 0 {
            let remaining = 1.0 - newest.level
            estimatedMinutesToFull = Int(Double(remaining) / Double(chargingRatePerMinute))

            // Estimate wattage: (% per minute) × (battery capacity in Wh) × 60 = Watts
            // Example: 1%/min on 14Wh battery = 0.01 × 14 × 60 = 8.4W
            estimatedWatts = chargingRatePerMinute * estimatedBatteryCapacityWh * 60
        } else {
            estimatedMinutesToFull = nil
            estimatedWatts = 0
        }
    }

    // Human-readable descriptions
    var batteryPercentage: Int {
        max(0, Int(batteryLevel * 100))
    }

    var stateDescription: String {
        switch batteryState {
        case .unknown: return "Unknown"
        case .unplugged: return "On Battery"
        case .charging: return "Charging"
        case .full: return "Fully Charged"
        @unknown default: return "Unknown"
        }
    }

    var thermalStateDescription: String {
        switch thermalState {
        case .nominal: return "Normal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    var thermalStateColor: String {
        switch thermalState {
        case .nominal: return "green"
        case .fair: return "yellow"
        case .serious: return "orange"
        case .critical: return "red"
        @unknown default: return "gray"
        }
    }

    var chargingSpeedCategory: String {
        guard batteryState == .charging, chargingRatePerMinute > 0 else {
            return "Not Charging"
        }
        // Rough heuristic: percent per minute
        let pctPerMin = chargingRatePerMinute * 100
        if pctPerMin > 1.5 {
            return "Fast Charging"
        } else if pctPerMin > 0.5 {
            return "Normal Charging"
        } else {
            return "Slow Charging"
        }
    }

    var estimatedTimeDescription: String {
        guard let minutes = estimatedMinutesToFull else {
            return "--"
        }
        if minutes < 1 { return "< 1 min" }
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m) min"
    }

    var estimatedWattsDescription: String {
        guard estimatedWatts > 0 else { return "--" }
        return String(format: "%.1fW", estimatedWatts)
    }
}
