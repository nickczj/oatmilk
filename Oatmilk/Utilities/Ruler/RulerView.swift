import SwiftUI

struct RulerView: View {
    @State private var unit: MeasurementUnit = .centimeters
    @State private var markers: [RulerMarker] = []
    @State private var showCalibration = false
    @State private var calibrationFactor: CGFloat = 1.0

    // Standard iOS: 163 points per inch (based on original iPhone)
    private let basePointsPerInch: CGFloat = 163.0

    private var pointsPerInch: CGFloat {
        basePointsPerInch * calibrationFactor
    }

    private var pointsPerCm: CGFloat {
        pointsPerInch / 2.54
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    // Ruler strip on the left
                    rulerStrip(height: geometry.size.height)

                    // Main content area
                    VStack(spacing: 20) {
                        Spacer()

                        measurementDisplay

                        unitToggle

                        markerControls

                        instructionsCard

                        calibrationButton

                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
            }
            .onTapGesture { location in
                addMarker(at: location.y, maxHeight: geometry.size.height)
            }
        }
        .navigationTitle("Ruler")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCalibration) {
            CalibrationView(calibrationFactor: $calibrationFactor)
        }
    }

    // MARK: - Ruler Strip

    private func rulerStrip(height: CGFloat) -> some View {
        Canvas { context, size in
            let rulerWidth: CGFloat = 50

            // Background
            context.fill(
                Path(CGRect(x: 0, y: 0, width: rulerWidth, height: size.height)),
                with: .color(Color(.systemYellow).opacity(0.15))
            )

            // Draw markings based on unit
            switch unit {
            case .centimeters:
                drawCentimeterMarkings(context: context, height: size.height, width: rulerWidth)
            case .inches:
                drawInchMarkings(context: context, height: size.height, width: rulerWidth)
            }

            // Draw markers
            for marker in markers {
                let y = marker.position
                context.fill(
                    Path(CGRect(x: 0, y: y - 2, width: rulerWidth, height: 4)),
                    with: .color(.orange)
                )

                // Draw triangle indicator
                var triangle = Path()
                triangle.move(to: CGPoint(x: rulerWidth - 10, y: y))
                triangle.addLine(to: CGPoint(x: rulerWidth, y: y - 8))
                triangle.addLine(to: CGPoint(x: rulerWidth, y: y + 8))
                triangle.closeSubpath()
                context.fill(triangle, with: .color(.orange))
            }
        }
        .frame(width: 50)
    }

    private func drawCentimeterMarkings(context: GraphicsContext, height: CGFloat, width: CGFloat) {
        var y: CGFloat = 0
        var cmCount = 0

        while y < height {
            let isCm = cmCount % 10 == 0
            let isHalfCm = cmCount % 5 == 0

            let lineLength: CGFloat
            if isCm {
                lineLength = width * 0.7
            } else if isHalfCm {
                lineLength = width * 0.5
            } else {
                lineLength = width * 0.3
            }

            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: lineLength, y: y))
                },
                with: .color(.primary),
                lineWidth: isCm ? 2 : 1
            )

            // Draw number for each cm
            if isCm && cmCount > 0 {
                let text = Text("\(cmCount / 10)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                context.draw(text, at: CGPoint(x: width - 12, y: y), anchor: .leading)
            }

            y += pointsPerCm / 10 // 1mm increments
            cmCount += 1
        }
    }

    private func drawInchMarkings(context: GraphicsContext, height: CGFloat, width: CGFloat) {
        var y: CGFloat = 0
        var sixteenthCount = 0

        while y < height {
            let isInch = sixteenthCount % 16 == 0
            let isHalf = sixteenthCount % 8 == 0
            let isQuarter = sixteenthCount % 4 == 0
            let isEighth = sixteenthCount % 2 == 0

            let lineLength: CGFloat
            if isInch {
                lineLength = width * 0.7
            } else if isHalf {
                lineLength = width * 0.55
            } else if isQuarter {
                lineLength = width * 0.4
            } else if isEighth {
                lineLength = width * 0.3
            } else {
                lineLength = width * 0.2
            }

            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: lineLength, y: y))
                },
                with: .color(.primary),
                lineWidth: isInch ? 2 : 1
            )

            // Draw number for each inch
            if isInch && sixteenthCount > 0 {
                let text = Text("\(sixteenthCount / 16)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                context.draw(text, at: CGPoint(x: width - 12, y: y), anchor: .leading)
            }

            y += pointsPerInch / 16 // 1/16" increments
            sixteenthCount += 1
        }
    }

    // MARK: - Measurement Display

    private var measurementDisplay: some View {
        VStack(spacing: 8) {
            if markers.count >= 2 {
                let distance = abs(markers[1].position - markers[0].position)
                let measurement = unit == .centimeters
                    ? distance / pointsPerCm
                    : distance / pointsPerInch

                Text(String(format: "%.2f", measurement))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)

                Text(unit.abbreviation)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else if markers.count == 1 {
                Text("Place second marker")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tap to place markers")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Unit Toggle

    private var unitToggle: some View {
        Picker("Unit", selection: $unit) {
            Text("cm").tag(MeasurementUnit.centimeters)
            Text("in").tag(MeasurementUnit.inches)
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
    }

    // MARK: - Marker Controls

    private var markerControls: some View {
        HStack(spacing: 16) {
            Button {
                if !markers.isEmpty {
                    withAnimation {
                        _ = markers.removeLast()
                    }
                }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(markers.isEmpty ? Color(.systemGray5) : Color(.systemGray5))
                    .foregroundStyle(markers.isEmpty ? .secondary : .primary)
                    .clipShape(Capsule())
            }
            .disabled(markers.isEmpty)

            Button {
                withAnimation {
                    markers.removeAll()
                }
            } label: {
                Label("Clear All", systemImage: "trash")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(markers.isEmpty ? Color(.systemGray5) : Color.red.opacity(0.15))
                    .foregroundStyle(markers.isEmpty ? .secondary : .red)
                    .clipShape(Capsule())
            }
            .disabled(markers.isEmpty)
        }
    }

    // MARK: - Instructions

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How to measure", systemImage: "info.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Text("1. Place your iPhone flat with the ruler edge against the object")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("2. Tap the screen to place up to 2 markers")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("3. The distance between markers is shown above")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Calibration

    private var calibrationButton: some View {
        Button {
            showCalibration = true
        } label: {
            Label("Calibrate Ruler", systemImage: "ruler")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Marker Management

    private func addMarker(at y: CGFloat, maxHeight: CGFloat) {
        let clampedY = max(0, min(y, maxHeight))

        if markers.count >= 2 {
            // Replace markers when we already have 2
            markers.removeAll()
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            markers.append(RulerMarker(position: clampedY))
        }
    }
}

// MARK: - Supporting Types

enum MeasurementUnit: String, CaseIterable {
    case centimeters
    case inches

    var abbreviation: String {
        switch self {
        case .centimeters: return "cm"
        case .inches: return "in"
        }
    }
}

struct RulerMarker: Identifiable {
    let id = UUID()
    let position: CGFloat
}

// MARK: - Calibration View

struct CalibrationView: View {
    @Binding var calibrationFactor: CGFloat
    @Environment(\.dismiss) private var dismiss

    @State private var knownLength: String = ""
    @State private var measuredLength: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Use a known measurement (like a credit card width of 85.6mm) to calibrate your ruler for more accurate results.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Known Object") {
                    TextField("Actual length (mm)", text: $knownLength)
                        .keyboardType(.decimalPad)

                    TextField("Measured length (mm)", text: $measuredLength)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button("Apply Calibration") {
                        applyCalibration()
                    }
                    .disabled(knownLength.isEmpty || measuredLength.isEmpty)

                    Button("Reset to Default") {
                        calibrationFactor = 1.0
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }

                Section("Tips") {
                    Label("Credit card width: 85.6mm", systemImage: "creditcard")
                    Label("US quarter diameter: 24.26mm", systemImage: "circle")
                    Label("Standard paper width: 210mm (A4)", systemImage: "doc")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func applyCalibration() {
        guard let known = Double(knownLength),
              let measured = Double(measuredLength),
              measured > 0 else { return }

        calibrationFactor = CGFloat(known / measured)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        RulerView()
    }
}
