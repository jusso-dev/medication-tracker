import SwiftUI
import UIKit

struct ScanThumbnail: View {
    let data: Data?
    var identifier = "scan.thumbnail"

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipped()
                .clipShape(.rect(cornerRadius: 12))
                .accessibilityLabel("Scanned label photo")
                .accessibilityIdentifier(identifier)
        }
    }
}
