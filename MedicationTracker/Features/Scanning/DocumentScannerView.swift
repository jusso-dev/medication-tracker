import SwiftUI
import UIKit
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    let onComplete: ([Data]) -> Void
    let onCancel: () -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: VNDocumentCameraViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentScannerView

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount <= 10 else {
                parent.onError("Scan up to 10 pages at a time.")
                return
            }
            let images = (0..<scan.pageCount).map {
                SendableScanImage(image: scan.imageOfPage(at: $0))
            }
            Task {
                let pages = await Task.detached(priority: .userInitiated) {
                    images.compactMap {
                        $0.image.jpegData(compressionQuality: 0.8)
                    }
                }.value
                parent.onComplete(pages)
            }
        }

        func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onError(error.localizedDescription)
        }
    }
}

private struct SendableScanImage: @unchecked Sendable {
    let image: UIImage
}
