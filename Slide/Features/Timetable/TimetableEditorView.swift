import SwiftUI
import SwiftData

struct TimetableEditorView: View {
    private enum EditorTab {
        case grid, schedule
    }

    @State private var tab: EditorTab = .grid

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Weekly Grid").tag(EditorTab.grid)
                    Text("Bell Schedule").tag(EditorTab.schedule)
                }
                .pickerStyle(.segmented)
                .padding()

                switch tab {
                case .grid: WeeklyGridEditor()
                case .schedule: BellScheduleEditor()
                }
            }
            .navigationTitle("Timetable")
        }
    }
}

private struct BellScheduleEditor: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Period.orderIndex) private var periods: [Period]

    var body: some View {
        List {
            ForEach(periods) { period in
                PeriodRow(period: period)
            }
            .onDelete(perform: delete)
            .onMove(perform: move)

            Button {
                addPeriod()
            } label: {
                Label("Add Period", systemImage: "plus")
            }
        }
    }

    private func addPeriod() {
        let nextOrder = (periods.map(\.orderIndex).max() ?? 0) + 1
        let start = periods.last?.endMinutes ?? 480
        let new = Period(orderIndex: nextOrder, startMinutes: start, endMinutes: start + 50, label: "Period \(nextOrder)")
        context.insert(new)
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(periods[index]) }
        try? context.save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = periods
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, period) in reordered.enumerated() {
            period.orderIndex = index + 1
        }
        try? context.save()
    }
}

private struct PeriodRow: View {
    @Bindable var period: Period

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Label", text: $period.label)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    timePicker(minutes: Binding(
                        get: { period.startMinutes },
                        set: { period.startMinutes = $0 }
                    ))
                    Text("–")
                    timePicker(minutes: Binding(
                        get: { period.endMinutes },
                        set: { period.endMinutes = $0 }
                    ))
                }
            }
            Spacer()
            Toggle("Break", isOn: $period.isBreak)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private func timePicker(minutes: Binding<Int>) -> some View {
        DatePicker("", selection: Binding(
            get: { Self.date(fromMinutes: minutes.wrappedValue) },
            set: { minutes.wrappedValue = Self.minutes(from: $0) }
        ), displayedComponents: .hourAndMinute)
        .labelsHidden()
    }

    private static func date(fromMinutes minutes: Int) -> Date {
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        return Calendar.current.date(from: components) ?? Date()
    }

    private static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

private struct CellSelection: Identifiable {
    let id = UUID()
    let weekday: Int
    let period: Period
}

private struct WeeklyGridEditor: View {
    @Query(sort: \Period.orderIndex) private var periods: [Period]
    @Query private var cells: [TimetableCell]

    @AppStorage(AppSettingsKey.visibleWeekdays) private var visibleWeekdaysRaw = AppSettingsDefault.visibleWeekdaysStorage

    @State private var selection: CellSelection?

    private var visibleWeekdays: [Int] {
        let set = VisibleWeekdaysCoding.decode(visibleWeekdaysRaw)
        return Weekday.mondayFirstOrder.filter { set.contains($0) }
    }

    private var assignablePeriods: [Period] {
        periods.filter { !$0.isBreak }
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .topLeading, horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    Text("").frame(width: 90)
                    ForEach(visibleWeekdays, id: \.self) { weekday in
                        Text(Weekday.shortLabel(forCalendarWeekday: weekday))
                            .font(.caption.weight(.semibold))
                            .frame(width: 64)
                    }
                }
                ForEach(assignablePeriods) { period in
                    GridRow {
                        Text(period.label)
                            .font(.caption)
                            .frame(width: 90, alignment: .leading)
                        ForEach(visibleWeekdays, id: \.self) { weekday in
                            cellButton(weekday: weekday, period: period)
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(item: $selection) { selection in
            SubjectPickerSheet(weekday: selection.weekday, period: selection.period)
        }
    }

    private func cellButton(weekday: Int, period: Period) -> some View {
        let cell = cells.first { $0.weekday == weekday && $0.period?.id == period.id }
        let subject = cell?.subject
        return Button {
            selection = CellSelection(weekday: weekday, period: period)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(subject != nil ? Color(hex: subject!.colorHex).opacity(0.25) : Color.gray.opacity(0.1))
                Text(subject?.name ?? "")
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(2)
            }
            .frame(width: 64, height: 44)
        }
        .buttonStyle(.plain)
    }
}

private struct SubjectPickerSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClassSubject.name) private var classes: [ClassSubject]
    @Query private var cells: [TimetableCell]

    let weekday: Int
    let period: Period

    private var existingCell: TimetableCell? {
        cells.first { $0.weekday == weekday && $0.period?.id == period.id }
    }

    var body: some View {
        NavigationStack {
            List {
                Button("Clear") { assign(nil) }
                    .foregroundStyle(.red)
                ForEach(classes) { subject in
                    Button {
                        assign(subject)
                    } label: {
                        HStack {
                            Circle().fill(Color(hex: subject.colorHex)).frame(width: 10, height: 10)
                            Text(subject.name)
                            if existingCell?.subject?.id == subject.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("\(period.label) · \(Weekday.shortLabel(forCalendarWeekday: weekday))")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func assign(_ subject: ClassSubject?) {
        if let existingCell {
            existingCell.subject = subject
        } else if let subject {
            context.insert(TimetableCell(weekday: weekday, period: period, subject: subject))
        }
        try? context.save()
        dismiss()
    }
}
