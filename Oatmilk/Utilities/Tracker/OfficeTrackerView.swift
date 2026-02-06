import SwiftUI

struct OfficeTrackerView: View {
    @State private var tracker = OfficeTrackerService()
    @State private var displayedMonth = Date()
    @State private var showSettings = false
    @State private var showQuickAdd = false

    private var displayedYear: Int {
        Calendar.current.component(.year, from: displayedMonth)
    }

    private var displayedMonthNum: Int {
        Calendar.current.component(.month, from: displayedMonth)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                progressHeader
                statusBanner
                calendarSection
                quickActions
                recentEntries
            }
            .padding()
        }
        .navigationTitle("Office Days")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            OfficeTrackerSettingsView(tracker: tracker)
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        let summary = tracker.currentMonthSummary

        return VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: summary.progress)
                    .stroke(
                        summary.isComplete ? Color.green : Color.orange,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: summary.progress)

                VStack(spacing: 2) {
                    Text("\(summary.loggedDays)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))

                    Text("of \(summary.targetDays)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(summary.monthName)
                .font(.headline)
                .foregroundStyle(.secondary)

            if summary.isComplete {
                Label("Target Complete!", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Text("\(summary.remaining) days remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        let summary = tracker.currentMonthSummary

        if summary.isBehindSchedule {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Behind Schedule")
                        .font(.subheadline.weight(.semibold))

                    Text("\(summary.remaining) days needed, only \(summary.workingDaysLeft) working days left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(.yellow.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if !summary.isComplete {
            let daysPerWeek = summary.workingDaysLeft > 0
                ? Double(summary.remaining) / (Double(summary.workingDaysLeft) / 5.0)
                : 0

            if daysPerWeek > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("On Track")
                            .font(.subheadline.weight(.semibold))

                        Text("~\(String(format: "%.1f", daysPerWeek)) days/week needed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 12) {
            // Month Navigation
            HStack {
                Button {
                    withAnimation {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Spacer()

                Text(monthYearString)
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 8)

            // Today Button
            if !Calendar.current.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) {
                Button {
                    withAnimation {
                        displayedMonth = Date()
                    }
                } label: {
                    Text("Today")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            // Weekday Headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar Grid
            CalendarGridView(
                year: displayedYear,
                month: displayedMonthNum,
                tracker: tracker
            )
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    tracker.toggleDate(Date())
                }
            } label: {
                let isToday = tracker.isDateLogged(Date())
                Label(
                    isToday ? "Remove Today" : "Log Today",
                    systemImage: isToday ? "minus.circle.fill" : "plus.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isToday ? Color(.systemGray5) : Color.orange)
                .foregroundStyle(isToday ? .primary : .white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Recent Entries

    private var recentEntries: some View {
        let summary = tracker.summary(for: displayedMonth)

        return VStack(alignment: .leading, spacing: 12) {
            Text("This Month's Entries")
                .font(.headline)
                .padding(.horizontal, 4)

            if summary.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("No office days logged yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Tap on a date in the calendar to log a day")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(summary.entries.reversed()) { entry in
                        HStack {
                            Text(entryDateString(entry.date))
                                .font(.subheadline)

                            Spacer()

                            Text(weekdayString(entry.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                withAnimation {
                                    tracker.removeEntry(for: entry.date)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()

                        if entry.id != summary.entries.first?.id {
                            Divider().padding(.leading)
                        }
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func entryDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private func weekdayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Calendar Grid

struct CalendarGridView: View {
    let year: Int
    let month: Int
    @Bindable var tracker: OfficeTrackerService

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var daysInMonth: Int {
        tracker.daysInMonth(year: year, month: month)
    }

    private var firstWeekday: Int {
        tracker.firstWeekdayOfMonth(year: year, month: month)
    }

    private var leadingSpaces: Int {
        firstWeekday - 1 // Sunday = 1, so Sunday needs 0 spaces
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            // Leading empty spaces
            ForEach(0..<leadingSpaces, id: \.self) { _ in
                Color.clear
                    .frame(height: 40)
            }

            // Days
            ForEach(1...daysInMonth, id: \.self) { day in
                DayCell(
                    day: day,
                    date: dateFor(day: day),
                    isLogged: isLogged(day: day),
                    isToday: isToday(day: day),
                    isWeekend: isWeekend(day: day),
                    isFuture: isFuture(day: day)
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        tracker.toggleDate(dateFor(day: day))
                    }
                }
            }
        }
    }

    private func dateFor(day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    private func isLogged(day: Int) -> Bool {
        tracker.isDateLogged(dateFor(day: day))
    }

    private func isToday(day: Int) -> Bool {
        Calendar.current.isDateInToday(dateFor(day: day))
    }

    private func isWeekend(day: Int) -> Bool {
        let date = dateFor(day: day)
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }

    private func isFuture(day: Int) -> Bool {
        dateFor(day: day) > Date()
    }
}

struct DayCell: View {
    let day: Int
    let date: Date
    let isLogged: Bool
    let isToday: Bool
    let isWeekend: Bool
    let isFuture: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isLogged {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 36, height: 36)
                } else if isToday {
                    Circle()
                        .stroke(Color.orange, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }

                Text("\(day)")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundStyle(
                        isLogged ? .white :
                        isWeekend ? .secondary :
                        isFuture ? .tertiary : .primary
                    )
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }
}

// MARK: - Settings View

struct OfficeTrackerSettingsView: View {
    @Bindable var tracker: OfficeTrackerService
    @Environment(\.dismiss) private var dismiss

    @State private var targetDays: Double

    init(tracker: OfficeTrackerService) {
        self.tracker = tracker
        self._targetDays = State(initialValue: Double(tracker.monthlyTarget))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly Target") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Required office days")
                            Spacer()
                            Text("\(Int(targetDays))")
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }

                        Slider(value: $targetDays, in: 1...25, step: 1)
                            .tint(.orange)
                            .onChange(of: targetDays) { _, newValue in
                                tracker.updateTarget(Int(newValue))
                            }
                    }
                }

                Section("Notifications") {
                    Toggle("Behind Schedule Alerts", isOn: Binding(
                        get: { tracker.notificationsEnabled },
                        set: { tracker.toggleNotifications($0) }
                    ))

                    if tracker.notificationsEnabled {
                        Text("You'll receive a reminder at 9 AM when you're behind your target pace.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Data") {
                    let summary = tracker.currentMonthSummary

                    LabeledContent("This Month", value: "\(summary.loggedDays) days")
                    LabeledContent("Total Logged", value: "\(tracker.entries.count) days")
                }

                Section {
                    Button("Clear All Entries", role: .destructive) {
                        tracker.entries.removeAll()
                    }
                }
            }
            .navigationTitle("Settings")
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
}

#Preview {
    NavigationStack {
        OfficeTrackerView()
    }
}
