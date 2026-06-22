#if os(iOS)
import Photos

/// Deletes Photos-library assets we successfully imported. Only ever called
/// for assets already safely copied into the app's own storage; the system
/// presents its own confirmation sheet, and a user cancel leaves everything
/// untouched.
enum PhotoLibrary {
    static func deleteAssets(localIdentifiers ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}
#endif
