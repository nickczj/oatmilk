import Foundation

struct UtilityInfo: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let category: String
    var isInstalled: Bool

    static let allUtilities: [UtilityInfo] = [
        UtilityInfo(
            id: "charging_status",
            name: "Charging Status",
            description: "Monitor battery level, charging speed, power state, and thermal condition in real time.",
            iconName: "battery.100percent.bolt",
            category: "Battery",
            isInstalled: false
        ),
        UtilityInfo(
            id: "ruler",
            name: "Ruler",
            description: "Use your iPhone as a physical ruler. Measure objects in centimeters or inches with marker points.",
            iconName: "ruler",
            category: "Measurement",
            isInstalled: false
        ),
    ]
}
