import SwiftUI
import SwiftData

/// Full-screen pager for a fixed set of slides (the "current context" the
/// caller navigated from — a class's slides, or a search result set).
struct SlideViewerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var slides: [Slide]
    @State private var selection: UUID
    @State private var zoomedSlideID: UUID?
    @State private var showingDeleteConfirm = false
    @State private var showingEditor = false
    @State private var showingOCRText = false

    /// Full-screen pager pages downsample to this size by default; only the
    /// page the user has actually pinch-zoomed decodes at full resolution.
    /// Comfortably covers any current device at retina scale while staying
    /// far below a multi-thousand-pixel camera-original HEIC.
    private static let unzoomedMaxPixelSize: CGFloat = 2048

    init(slides: [Slide], initial: Slide) {
        _slides = State(initialValue: slides)
        _selection = State(initialValue: initial.id)
    }

    private var current: Slide? {
        slides.first { $0.id == selection }
    }

    private func maxPixelSize(for slideID: UUID) -> CGFloat? {
        zoomedSlideID == slideID ? nil : Self.unzoomedMaxPixelSize
    }

    private func isZoomedBinding(for slideID: UUID) -> Binding<Bool> {
        Binding(
            get: { zoomedSlideID == slideID },
            set: { zoomedSlideID = $0 ? slideID : nil }
        )
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(slides) { slide in
                AsyncDiskImage(
                    url: FileStore.shared.imageURL(slide.imageFileName),
                    maxPixelSize: maxPixelSize(for: slide.id)
                )
                .modifier(ZoomableModifier(isZoomed: isZoomedBinding(for: slide.id)))
                .tag(slide.id)
            }
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
        .background(Color.black)
        .ignoresSafeArea()
        .overlay(alignment: .top) { topBar }
        .confirmationDialog("Delete this slide?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteCurrent() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingEditor) {
            if let current { SlideEditSheet(slide: current) }
        }
        .sheet(isPresented: $showingOCRText) {
            if let current { OCRTextSheet(slide: current) }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.4))
            }

            Spacer()

            if let current {
                VStack(spacing: 2) {
                    if let title = current.sessionTitle, !title.isEmpty {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    Text(current.captureDate, format: .dateTime.day().month().year().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            Spacer()

            Menu {
                Button {
                    showingEditor = true
                } label: {
                    Label("Edit Details", systemImage: "pencil")
                }
                if let current {
                    ShareLink(item: FileStore.shared.imageURL(current.imageFileName)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showingOCRText = true
                    } label: {
                        Label("Recognized Text", systemImage: "text.viewfinder")
                    }
                    Button {
                        OCRPipeline.shared.process(slide: current, context: context)
                    } label: {
                        Label("Re-run Text Recognition", systemImage: "arrow.clockwise")
                    }
                }
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.4))
            }
        }
        .padding()
    }

    private func deleteCurrent() {
        guard let idx = slides.firstIndex(where: { $0.id == selection }) else { return }
        let toDelete = slides[idx]
        FileStore.shared.delete(imageFileName: toDelete.imageFileName, thumbnailFileName: toDelete.thumbnailFileName)
        context.delete(toDelete)
        try? context.save()
        slides.remove(at: idx)
        if slides.isEmpty {
            dismiss()
        } else {
            selection = slides[min(idx, slides.count - 1)].id
        }
    }
}

private struct SlideEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var slide: Slide
    @Query(sort: \ClassSubject.name) private var classes: [ClassSubject]

    var body: some View {
        NavigationStack {
            Form {
                Section("Class") {
                    Picker("Class", selection: $slide.subject) {
                        ForEach(classes) { subject in
                            Text(subject.name).tag(Optional(subject))
                        }
                    }
                }
                Section("Date") {
                    DatePicker("Capture Date", selection: $slide.captureDate)
                }
                Section("Session Title") {
                    TextField("Title", text: Binding(
                        get: { slide.sessionTitle ?? "" },
                        set: { slide.sessionTitle = $0.isEmpty ? nil : $0 }
                    ))
                }
                Section("Note") {
                    TextField("Note", text: Binding(
                        get: { slide.note ?? "" },
                        set: { slide.note = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Slide")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct OCRTextSheet: View {
    @Environment(\.dismiss) private var dismiss
    let slide: Slide

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(slide.ocrText?.isEmpty == false ? slide.ocrText! : "No English text or numbers recognized on this slide yet.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Recognized Text")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Pinch-to-zoom + pan, double-tap to reset. Plain gesture state, no
/// platform-specific APIs, so it works the same on iOS/macOS/visionOS.
private struct ZoomableModifier: ViewModifier {
    @Binding var isZoomed: Bool
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnification)
            .simultaneousGesture(drag)
            .onTapGesture(count: 2) {
                withAnimation { reset() }
            }
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = max(1, min(lastScale * value.magnification, 4))
                isZoomed = scale > 1
            }
            .onEnded { _ in
                lastScale = scale
                isZoomed = scale > 1
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > 1 else { return }
                lastOffset = offset
            }
    }

    private func reset() {
        scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
        isZoomed = false
    }
}
