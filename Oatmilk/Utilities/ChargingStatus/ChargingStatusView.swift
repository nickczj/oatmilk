import SwiftUI

struct ChargingStatusView: View {
    @State private var battery = BatteryService()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                batteryGauge
                statusCards
                detailsSection
            }
            .padding()
        }
        .navigationTitle("Charging Status")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Battery Gauge

    private var batteryGauge: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 16)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: CGFloat(max(0, battery.batteryLevel)))
                    .stroke(
                        batteryColor,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: battery.batteryLevel)

                VStack(spacing: 4) {
                    Text("\(battery.batteryPercentage)%")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())

                    Label(battery.stateDescription, systemImage: stateIcon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if battery.batteryState == .charging {
                Text(battery.chargingSpeedCategory)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Status Cards

    private var statusCards: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            StatusCard(
                title: "Power State",
                value: battery.stateDescription,
                icon: stateIcon
            )

            StatusCard(
                title: "Time to Full",
                value: battery.estimatedTimeDescription,
                icon: "clock.fill"
            )

            StatusCard(
                title: "Thermal State",
                value: battery.thermalStateDescription,
                icon: "thermometer.medium",
                valueColor: thermalColor
            )

            StatusCard(
                title: "Low Power",
                value: battery.isLowPowerMode ? "On" : "Off",
                icon: "bolt.slash.fill",
                valueColor: battery.isLowPowerMode ? .yellow : .green
            )
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.title3.weight(.semibold))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                DetailRow(label: "Battery Level", value: "\(battery.batteryPercentage)%")
                Divider().padding(.leading)
                DetailRow(label: "Charging Status", value: battery.stateDescription)
                Divider().padding(.leading)
                DetailRow(label: "Charging Speed", value: battery.chargingSpeedCategory)
                Divider().padding(.leading)
                DetailRow(
                    label: "Charge Rate",
                    value: battery.batteryState == .charging
                        ? String(format: "%.2f%%/min", battery.chargingRatePerMinute * 100)
                        : "--"
                )
                Divider().padding(.leading)
                DetailRow(label: "Est. Time to Full", value: battery.estimatedTimeDescription)
                Divider().padding(.leading)
                DetailRow(label: "Thermal Condition", value: battery.thermalStateDescription)
                Divider().padding(.leading)
                DetailRow(label: "Low Power Mode", value: battery.isLowPowerMode ? "Enabled" : "Disabled")
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Helpers

    private var batteryColor: Color {
        if battery.batteryLevel < 0.2 {
            return .red
        } else if battery.batteryLevel < 0.5 {
            return .yellow
        } else {
            return .green
        }
    }

    private var stateIcon: String {
        switch battery.batteryState {
        case .charging: return "bolt.fill"
        case .full: return "checkmark.circle.fill"
        case .unplugged: return "battery.100percent"
        default: return "questionmark.circle"
        }
    }

    private var thermalColor: Color {
        switch battery.thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .secondary
        }
    }
}

// MARK: - Subviews

private struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        ChargingStatusView()
    }
}
