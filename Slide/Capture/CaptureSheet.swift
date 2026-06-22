#if os(iOS)
import SwiftUI
import SwiftData

/// Entry point for capture: choose/confirm the target class, then pick a
/// mode. Document Scanner is presented first/default; Camera is secondary.
struct CaptureSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClassSubject.name) private var classes: [ClassSubject]

    @State private var target: ClassSubject?
    @State private var activeMode: CaptureMode?

    private enum CaptureMode: Identifiable {
        case scan, camera
        var id: Self { self }
    }

    init(defaultTarget: ClassSubject? = nil) {
        _target = State(initialValue: defaultTarget)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                targetClassPicker

                VStack(spacing: 16) {
                    CaptureModeButton(title: "Scan Slides", subtitle: "Default — auto-crop & deskew", systemImage: "doc.text.viewfinder") {
                        activeMode = .scan
                    }
                    CaptureModeButton(title: "Use Camera", subtitle: "Rapid multi-shot", systemImage: "camera.fill") {
                        activeMode = .camera
                    }
                }
                .disabled(target == nil)
                .opacity(target == nil ? 0.5 : 1)

                if target == nil {
                    Text(classes.isEmpty ? "Create a class first." : "Choose a class before capturing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Add Slides")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .fullScreenCover(item: $activeMode) { mode in
            switch mode {
            case .scan:
                DocumentScannerView(
                    onFinish: { pages in finish(pages) },
                    onCancel: { activeMode = nil }
                )
            case .camera:
                CameraView(onFinish: { pages in finish(pages) })
            }
        }
    }

    private var targetClassPicker: some View {
        Menu {
            ForEach(classes) { subject in
                Button(subject.name) { target = subject }
            }
        } label: {
            HStack {
                if let target {
                    Circle().fill(Color(hex: target.colorHex)).frame(width: 10, height: 10)
                    Text(target.name)
                } else {
                    Text("Choose a class")
                }
                Image(systemName: "chevron.up.chevron.down")
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
        }
    }

    private func finish(_ pages: [Data]) {
        activeMode = nil
        guard let target, !pages.isEmpty else { return }
        CaptureFlow.commit(pages: pages, to: target, context: context)
        dismiss()
    }
}

private struct CaptureModeButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage).font(.title2)
                VStack(alignment: .leading) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
#endif
