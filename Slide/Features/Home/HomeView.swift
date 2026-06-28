import SwiftUI
import SwiftData
import Combine

struct HomeView: View {
    @Query(sort: \Period.orderIndex) private var periods: [Period]
    @Query private var cells: [TimetableCell]
    @Query(sort: \ClassSubject.name) private var classes: [ClassSubject]
    @Query(sort: \Slide.captureDate, order: .reverse) private var recentSlides: [Slide]

    @Environment(\.scenePhase) private var scenePhase

    @State private var now = Date()
    @State private var showingCapture = false
    @State private var showingImporter = false
    @State private var showingTimetable = false
    @State private var showingClassPicker = false
    @State private var manualTarget: ClassSubject?
    @State private var viewerInitial: Slide?

    private var resolution: (subject: ClassSubject, period: Period)? {
        CurrentClassResolver().current(at: now, periods: periods, cells: cells)
    }

    private var effectiveTarget: ClassSubject? {
        manualTarget ?? resolution?.subject
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if classes.isEmpty {
                        emptyState
                    } else {
                        captureTile
                        if !recentSlides.isEmpty {
                            recentStrip
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("SlideShelf")
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showingTimetable = true
                    } label: {
                        Label("Timetable", systemImage: "calendar")
                    }
                }
            }
        }
        .onAppear { now = Date() }
        .onReceive(Timer.publish(every: 45, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { now = Date() }
        }
        .sheet(isPresented: $showingTimetable) {
            TimetableEditorView()
        }
        #if os(iOS)
        .sheet(isPresented: $showingCapture) {
            CaptureSheet(defaultTarget: effectiveTarget)
        }
        #endif
        .sheet(isPresented: $showingImporter) {
            ImageImporter(defaultTarget: effectiveTarget)
        }
        .sheet(isPresented: $showingClassPicker) {
            ClassPickerSheet(selection: $manualTarget)
        }
        .platformCover(item: $viewerInitial) { initial in
            SlideViewerView(slides: recentSlides, initial: initial)
        }
    }

    @ViewBuilder
    private var header: some View {
        if let manualTarget {
            HStack(spacing: 12) {
                Circle().fill(Color(hex: manualTarget.colorHex)).frame(width: 14, height: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(manualTarget.name).font(.title3.weight(.semibold))
                    Text("Manually selected").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reset") { self.manualTarget = nil }
                    .font(.caption)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        } else if let resolution {
            HStack(spacing: 12) {
                Circle().fill(Color(hex: resolution.subject.colorHex)).frame(width: 14, height: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(resolution.subject.name).font(.title3.weight(.semibold))
                    Text("\(resolution.period.label) · \(timeRange(resolution.period))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .onTapGesture { showingClassPicker = true }
        } else {
            HStack {
                Image(systemName: "moon.zzz")
                Text("No class right now")
                Spacer()
                Button("Choose Class") { showingClassPicker = true }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var captureTile: some View {
        VStack(spacing: 12) {
            #if os(iOS)
            Button {
                startAction { showingCapture = true }
            } label: {
                HStack {
                    Image(systemName: "camera.viewfinder").font(.largeTitle)
                    VStack(alignment: .leading) {
                        Text("Capture Slides").font(.headline)
                        Text("Scan or take photos").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            #endif

            Button {
                startAction { showingImporter = true }
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled").font(.title2)
                    Text("Import from Photos").font(.subheadline.weight(.medium))
                    Spacer()
                }
                .padding()
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }

    private var recentStrip: some View {
        VStack(alignment: .leading) {
            Text("Recent").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentSlides.prefix(20)) { slide in
                        Button {
                            viewerInitial = slide
                        } label: {
                            SlideThumbnail(slide: slide)
                                .frame(width: 90, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ContentUnavailableView(
                "Welcome to SlideShelf",
                systemImage: "camera.viewfinder",
                description: Text("Create a class in the Classes tab to start capturing and organizing your slides.")
            )
            Button {
                showingTimetable = true
            } label: {
                Label("Set Up Timetable", systemImage: "calendar")
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Break/free period (no resolved class) routes to the class picker first;
    /// otherwise proceeds straight to the requested action.
    private func startAction(_ action: () -> Void) {
        if effectiveTarget != nil {
            action()
        } else {
            showingClassPicker = true
        }
    }

    private func timeRange(_ period: Period) -> String {
        func format(_ minutes: Int) -> String {
            String(format: "%02d:%02d", minutes / 60, minutes % 60)
        }
        return "\(format(period.startMinutes))–\(format(period.endMinutes))"
    }
}

private struct ClassPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClassSubject.name) private var classes: [ClassSubject]
    @Binding var selection: ClassSubject?

    var body: some View {
        NavigationStack {
            List {
                if classes.isEmpty {
                    ContentUnavailableView(
                        "No Classes",
                        systemImage: "books.vertical",
                        description: Text("Create a class in the Classes tab first.")
                    )
                }
                ForEach(classes) { subject in
                    Button {
                        selection = subject
                        dismiss()
                    } label: {
                        HStack {
                            Circle().fill(Color(hex: subject.colorHex)).frame(width: 10, height: 10)
                            Text(subject.name)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Choose Class")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
