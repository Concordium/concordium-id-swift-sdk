import SwiftUI

struct ConcordiumLogoView: View {
    var body: some View {
        Image("concordium_logo", bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 200, height: 60)
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
            Image("app_store", bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 40)
                .cornerRadius(8)
        })
    }
}


