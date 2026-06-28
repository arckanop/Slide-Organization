import SwiftUI
import SwiftData

struct ClassDetailView: View {
    @Bindable var classSubject: ClassSubject
    @State private var showingEdit = false
    @State private var showingCapture = false
    @State private var showingImporter = false
    @State private var viewerInitial: Slide?
    @State private var isExportingPDF = false
    @State private var pdfExportURL: URL?
    @State private var showingPDFShare = false
    @State private var pdfExportFailed = false

    private var groupedSlides: [(date: Date, slides: [Slide])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: classSubject.slides) { calendar.startOfDay(for: $0.captureDate) }
        return groups.keys.sorted(by: >).map { day in
            (day, groups[day]!.sorted { $0.captureDate > $1.captureDate })
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 100), spacing: 8)]
    }

    var body: some View {
        Group {
            if classSubject.slides.isEmpty {
                ContentUnavailableView(
                    "No Slides Yet",
                    systemImage: "photo.on.rectangle",
                    description: Text("Slides you capture or import into \(classSubject.name) will appear here.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedSlides, id: \.date) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.date, style: .date)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                LazyVGrid(columns: gridColumns, spacing: 8) {
                                    ForEach(group.slides) { slide in
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
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle(classSubject.name)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCapture = true
                } label: {
                    Label("Add Slides", systemImage: "camera")
                }
            }
            #endif
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingImporter = true
                } label: {
                    Label("Import from Photos", systemImage: "photo.on.rectangle.angled")
                }
                Button {
                    Task { await exportPDF() }
                } label: {
                    if isExportingPDF {
                        ProgressView()
                    } else {
                        Label("Export to PDF", systemImage: "doc.richtext")
                    }
                }
                .disabled(isExportingPDF || classSubject.slides.isEmpty)
                Button("Edit Class") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            ClassEditView(classSubject: classSubject)
        }
        .sheet(isPresented: $showingImporter) {
            ImageImporter(defaultTarget: classSubject)
        }
        #if os(iOS)
        .sheet(isPresented: $showingCapture) {
            CaptureSheet(defaultTarget: classSubject)
        }
        #endif
        .sheet(isPresented: $showingPDFShare) {
            if let pdfExportURL {
                PDFShareSheet(url: pdfExportURL, slideCount: classSubject.slides.count)
            }
        }
        .alert("Couldn't Create PDF", isPresented: $pdfExportFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("None of the slides for \(classSubject.name) could be exported. Please try again.")
        }
        .platformCover(item: $viewerInitial) { initial in
            SlideViewerView(
                slides: classSubject.slides.sorted { $0.captureDate > $1.captureDate },
                initial: initial
            )
        }
    }

    private func exportPDF() async {
        isExportingPDF = true
        let pages = classSubject.slides.map { (url: FileStore.shared.imageURL($0.imageFileName), date: $0.captureDate) }
        let name = classSubject.name
        pdfExportURL = await Task.detached {
            PDFExporter.export(pages: pages, title: name)
        }.value
        isExportingPDF = false
        if pdfExportURL != nil {
            showingPDFShare = true
        } else {
            pdfExportFailed = true
        }
    }
}

private struct PDFShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    let slideCount: Int

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("PDF ready — \(slideCount) slide(s), oldest first.")
                    .multilineTextAlignment(.center)
                ShareLink(item: url) {
                    Label("Share PDF", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
