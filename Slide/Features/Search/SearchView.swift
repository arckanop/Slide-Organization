import SwiftUI
import SwiftData

struct SearchView: View {
    @Query(sort: \Slide.captureDate, order: .reverse) private var allSlides: [Slide]
    @Query(sort: \ClassSubject.name) private var classes: [ClassSubject]

    @State private var queryText = ""
    @State private var selectedClassIDs: Set<UUID> = []
    @State private var datePreset: DatePreset = .any
    @State private var viewerInitial: Slide?

    private enum DatePreset: String, CaseIterable, Identifiable {
        case any, today, last7, thisMonth

        var id: String { rawValue }

        var label: String {
            switch self {
            case .any: return "Any Date"
            case .today: return "Today"
            case .last7: return "Last 7 Days"
            case .thisMonth: return "This Month"
            }
        }
    }

    /// Combines text + class + date filters with AND, preserving the
    /// newest-first order of the underlying query.
    private var filteredSlides: [Slide] {
        allSlides.filter { matchesText($0) && matchesClass($0) && matchesDate($0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !classes.isEmpty {
                    classChips
                }
                datePresetPicker

                if allSlides.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Slides Yet",
                        systemImage: "photo.on.rectangle",
                        description: Text("Capture or import slides to search them here.")
                    )
                    Spacer()
                } else if filteredSlides.isEmpty {
                    Spacer()
                    ContentUnavailableView.search(text: queryText)
                    Spacer()
                } else {
                    resultsGrid
                }
            }
            .navigationTitle("Search")
            .searchable(text: $queryText, prompt: "Slide text, title, or notes")
        }
        .platformCover(item: $viewerInitial) { initial in
            SlideViewerView(slides: filteredSlides, initial: initial)
        }
    }

    private var classChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(classes) { subject in
                    let isSelected = selectedClassIDs.contains(subject.id)
                    Button {
                        if isSelected {
                            selectedClassIDs.remove(subject.id)
                        } else {
                            selectedClassIDs.insert(subject.id)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: subject.colorHex)).frame(width: 8, height: 8)
                            Text(subject.name)
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ? Color(hex: subject.colorHex).opacity(0.3) : Color.gray.opacity(0.12),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var datePresetPicker: some View {
        Picker("Date", selection: $datePreset) {
            ForEach(DatePreset.allCases) { preset in
                Text(preset.label).tag(preset)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(filteredSlides) { slide in
                    Button {
                        viewerInitial = slide
                    } label: {
                        SlideThumbnail(slide: slide)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func matchesText(_ slide: Slide) -> Bool {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return [slide.ocrText, slide.sessionTitle, slide.note]
            .compactMap { $0 }
            .contains { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    private func matchesClass(_ slide: Slide) -> Bool {
        guard !selectedClassIDs.isEmpty else { return true }
        guard let subjectID = slide.subject?.id else { return false }
        return selectedClassIDs.contains(subjectID)
    }

    private func matchesDate(_ slide: Slide) -> Bool {
        let calendar = Calendar.current
        switch datePreset {
        case .any:
            return true
        case .today:
            return calendar.isDateInToday(slide.captureDate)
        case .last7:
            guard let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) else { return true }
            return slide.captureDate >= cutoff
        case .thisMonth:
            return calendar.isDate(slide.captureDate, equalTo: Date(), toGranularity: .month)
        }
    }
}
