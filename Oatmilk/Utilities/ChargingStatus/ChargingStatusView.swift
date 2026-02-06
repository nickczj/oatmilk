import SwiftUI

struct ChargingStatusView: View {
    @State private var battery = BatteryService()
    @State private var showSessionsSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                batteryGauge
                recordingSection
                statusCards
                detailsSection
                sessionsSection
            }
            .padding()
        }
        .navigationTitle("Charging Status")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showSessionsSheet) {
            ChargingSessionsListView(battery: battery)
        }
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

    // MARK: - Recording Section

    private var recordingSection: some View {
        VStack(spacing: 12) {
            if battery.isRecording {
                HStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .modifier(PulseAnimation())

                    Text("Recording Charging Session")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    if let session = battery.activeSession {
                        Text("\(session.dataPoints.count) points")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 12) {
                    Button {
                        withAnimation {
                            battery.stopRecording()
                        }
                    } label: {
                        Label("Stop & Save", systemImage: "stop.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Button {
                        withAnimation {
                            battery.cancelRecording()
                        }
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            } else {
                Button {
                    withAnimation {
                        battery.startRecording()
                    }
                } label: {
                    Label("Start Recording Charge Curve", systemImage: "record.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text("Record a full charging session to generate a charge curve graph with power data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
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
                title: "Est. Power",
                value: battery.estimatedWattsDescription,
                icon: "bolt.circle.fill",
                valueColor: battery.estimatedWatts > 0 ? .orange : .secondary
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
                DetailRow(label: "Est. Power", value: battery.estimatedWattsDescription)
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

    // MARK: - Sessions Section

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved Sessions")
                    .font(.title3.weight(.semibold))

                Spacer()

                if !battery.savedSessions.isEmpty {
                    Button("View All") {
                        showSessionsSheet = true
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 4)

            if battery.savedSessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("No recorded sessions yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Start recording while charging to capture a charge curve.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(battery.savedSessions.prefix(3)) { session in
                        NavigationLink {
                            ChargingCurveView(session: session)
                        } label: {
                            SessionRow(session: session)
                        }
                        .buttonStyle(.plain)

                        if session.id != battery.savedSessions.prefix(3).last?.id {
                            Divider().padding(.leading)
                        }
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
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

private struct SessionRow: View {
    let session: ChargingSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(session.startPercentage)% → \(session.endPercentage)%")
                    .font(.subheadline.weight(.medium))

                Text(session.dateRangeFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(session.chargeGainedPercentage)%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)

                Text(session.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

private struct PulseAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Sessions List View

struct ChargingSessionsListView: View {
    @Bindable var battery: BatteryService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(battery.savedSessions) { session in
                    NavigationLink {
                        ChargingCurveView(session: session)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(session.startPercentage)% → \(session.endPercentage)%")
                                    .font(.headline)

                                Spacer()

                                Text("+\(session.chargeGainedPercentage)%")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.green)
                            }

                            HStack {
                                Text(session.dateRangeFormatted)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(session.durationFormatted)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if session.avgEstimatedWatts > 0 {
                                Text("Avg: \(String(format: "%.1fW", session.avgEstimatedWatts))")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let session = battery.savedSessions[index]
                        battery.deleteSession(id: session.id)
                    }
                }
            }
            .navigationTitle("Charging Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if battery.savedSessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Record charging sessions to see them here.")
                    )
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChargingStatusView()
    }
}
