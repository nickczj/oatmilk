import SwiftUI
import Charts

struct ChargingCurveView: View {
    let session: ChargingSession

    @State private var selectedDataPoint: BatteryDataPoint?
    @State private var showWattage = true

    private var elapsedMinutes: [Double] {
        session.dataPoints.map {
            $0.timestamp.timeIntervalSince(session.startDate) / 60
        }
    }

    private var maxMinutes: Double {
        elapsedMinutes.max() ?? 1
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryHeader
                chartSection
                statsSection
                dataPointsList
            }
            .padding()
        }
        .navigationTitle("Charging Curve")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 24) {
                VStack {
                    Text("\(session.startPercentage)%")
                        .font(.title2.weight(.bold))
                    Text("Start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack {
                    Text("\(session.endPercentage)%")
                        .font(.title2.weight(.bold))
                    Text("End")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("+\(session.chargeGainedPercentage)%")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.green)
                    Text(session.durationFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(session.dateRangeFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Charging Curve")
                    .font(.headline)

                Spacer()

                Toggle("Show Power", isOn: $showWattage)
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .font(.caption)
            }

            Chart {
                // Battery level line
                ForEach(Array(session.dataPoints.enumerated()), id: \.element.id) { index, point in
                    let minutes = point.timestamp.timeIntervalSince(session.startDate) / 60

                    LineMark(
                        x: .value("Time", minutes),
                        y: .value("Battery", point.percentage),
                        series: .value("Series", "Battery")
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    AreaMark(
                        x: .value("Time", minutes),
                        y: .value("Battery", point.percentage),
                        series: .value("Series", "Battery")
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.green.opacity(0.3), .green.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Time", minutes),
                        y: .value("Battery", point.percentage)
                    )
                    .foregroundStyle(.green)
                    .symbolSize(30)
                }

                // Wattage line (on secondary Y axis, scaled to fit)
                if showWattage {
                    let maxWatts = session.maxEstimatedWatts
                    ForEach(Array(session.dataPoints.enumerated()), id: \.element.id) { index, point in
                        if let watts = point.estimatedWatts, maxWatts > 0 {
                            let minutes = point.timestamp.timeIntervalSince(session.startDate) / 60
                            // Scale watts to 0-100 range to overlay with battery %
                            let scaledWatts = (watts / maxWatts) * 50 // Scale to 0-50 range

                            LineMark(
                                x: .value("Time", minutes),
                                y: .value("Power", scaledWatts),
                                series: .value("Series", "Power")
                            )
                            .foregroundStyle(.orange)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        }
                    }
                }

                // Reference lines
                RuleMark(y: .value("Target", 90))
                    .foregroundStyle(.blue.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("90%")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }

                RuleMark(y: .value("Min", 10))
                    .foregroundStyle(.red.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("10%")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
            }
            .chartXAxisLabel("Time (minutes)")
            .chartYAxisLabel("Battery %")
            .chartYScale(domain: 0...100)
            .chartXScale(domain: 0...(maxMinutes + 1))
            .frame(height: 280)
            .padding(.vertical, 8)

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Battery Level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if showWattage {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.orange)
                            .frame(width: 16, height: 2)
                        Text("Est. Power")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatBox(title: "Duration", value: session.durationFormatted, icon: "clock.fill")
                StatBox(title: "Charge Gained", value: "+\(session.chargeGainedPercentage)%", icon: "bolt.fill")
                StatBox(
                    title: "Avg Rate",
                    value: String(format: "%.2f%%/min", session.averageChargingRate * 100),
                    icon: "speedometer"
                )
                StatBox(
                    title: "Avg Power",
                    value: session.avgEstimatedWatts > 0 ? String(format: "%.1fW", session.avgEstimatedWatts) : "--",
                    icon: "bolt.circle.fill"
                )
                StatBox(
                    title: "Peak Power",
                    value: session.maxEstimatedWatts > 0 ? String(format: "%.1fW", session.maxEstimatedWatts) : "--",
                    icon: "arrow.up.circle.fill"
                )
                StatBox(title: "Data Points", value: "\(session.dataPoints.count)", icon: "chart.dots.scatter")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Data Points List

    private var dataPointsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Points")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(session.dataPoints.enumerated()), id: \.element.id) { index, point in
                    HStack {
                        Text(formatTime(point.timestamp))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)

                        Text("\(point.percentage)%")
                            .font(.subheadline.weight(.medium))
                            .frame(width: 50, alignment: .trailing)

                        if let watts = point.estimatedWatts {
                            Text(String(format: "%.1fW", watts))
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(width: 50, alignment: .trailing)
                        } else {
                            Text("--")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }

                        Spacer()

                        if index > 0 {
                            let prevLevel = session.dataPoints[index - 1].level
                            let diff = point.level - prevLevel
                            Text(String(format: "%+.1f%%", diff * 100))
                                .font(.caption)
                                .foregroundStyle(diff >= 0 ? .green : .red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                    if index < session.dataPoints.count - 1 {
                        Divider().padding(.leading)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Subviews

private struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)

            Text(value)
                .font(.subheadline.weight(.semibold))

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        ChargingCurveView(session: ChargingSession.preview)
    }
}

// MARK: - Preview Data

extension ChargingSession {
    static var preview: ChargingSession {
        var session = ChargingSession(startDate: Date().addingTimeInterval(-3600), startLevel: 0.15)

        let dataPoints: [(minutesAgo: Double, level: Float, watts: Float)] = [
            (55, 0.22, 18.5),
            (50, 0.30, 19.2),
            (45, 0.38, 18.8),
            (40, 0.45, 17.5),
            (35, 0.52, 16.2),
            (30, 0.58, 14.8),
            (25, 0.64, 13.5),
            (20, 0.70, 12.0),
            (15, 0.75, 10.5),
            (10, 0.80, 9.0),
            (5, 0.84, 7.5),
            (0, 0.87, 5.0),
        ]

        for point in dataPoints {
            session.dataPoints.append(
                BatteryDataPoint(
                    timestamp: Date().addingTimeInterval(-point.minutesAgo * 60),
                    level: point.level,
                    estimatedWatts: point.watts
                )
            )
        }

        session.endDate = Date()
        session.endLevel = 0.87
        return session
    }
}
