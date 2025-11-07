import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private struct PackageImageView: View {
    let name: String

    var body: some View {
#if canImport(UIKit)
        if let image = loadUIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            missingImagePlaceholder
        }
#elseif canImport(AppKit)
        if let image = loadNSImage(named: name) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            missingImagePlaceholder
        }
#else
        missingImagePlaceholder
#endif
    }

#if canImport(UIKit)
    private func loadUIImage(named name: String) -> UIImage? {
        if let systemImage = UIImage(named: name, in: .module, compatibleWith: nil) {
            return systemImage
        }

        for ext in ["png", "jpg", "jpeg"] {
            if let url = Bundle.module.url(forResource: name, withExtension: ext),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }

        return nil
    }
#endif

#if canImport(AppKit)
    private func loadNSImage(named name: String) -> NSImage? {
        if let bundledImage = Bundle.module.image(forResource: NSImage.Name(name)) {
            return bundledImage
        }

        for ext in ["png", "jpg", "jpeg"] {
            if let url = Bundle.module.url(forResource: name, withExtension: ext),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
    }
#endif

    private var missingImagePlaceholder: some View {
        Color.clear
    }
}

/// Renders the Concordium logo from the SDK bundle.
struct ConcordiumLogoView: View {
    var body: some View {
        PackageImageView(name: "concordium_logo")
            .frame(width: 200, height: 60)
    }
}

/// Button that opens the App Store listing for the Concordium ID App.
struct AppStoreButtonView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(action: {
            if let url = URL(string: "https://apps.apple.com/app/concordium-id/id123456789") {
                openURL(url)
            }
        }, label: {
            PackageImageView(name: "app_store")
                .frame(width: 120, height: 40)
                .cornerRadius(8)
        })
    }
}
