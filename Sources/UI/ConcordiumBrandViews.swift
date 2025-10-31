import SwiftUI
import UIKit

struct ConcordiumLogoView: View {
    var body: some View {
        Group {
            if let image = UIImage(named: "concordium_logo", in: Bundle.module, compatibleWith: nil) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 60)
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 32, height: 32)
                    Circle()
                        .fill(Color.black)
                        .frame(width: 12, height: 12)
                }
            }
        }
    }
}

struct AppStoreButtonView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(action: {
            if let url = URL(string: "https://apps.apple.com/app/concordium-id/id123456789") {
                openURL(url)
            }
        }, label: {
            Group {
                if let image = UIImage(named: "app_store", in: Bundle.module, compatibleWith: nil) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 40)
                        .cornerRadius(8)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                        Text("Download on the\nApp Store")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 120, height: 40)
                    .background(Color.black)
                    .cornerRadius(8)
                }
            }
        })
    }
}


