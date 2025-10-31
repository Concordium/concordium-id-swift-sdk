import SwiftUI
import UIKit

#if DEBUG
struct ConcordiumIDAppPoup_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                Color.gray.opacity(0.3)
                    .ignoresSafeArea()

                ConcordiumIDAppPoup.invokeIdAppDeepLinkPopup(
                    walletConnectUri: "wc:1234567890abcdef@2?relay-protocol=irn&symKey=abcdef1234567890"
                )
            }
            .previewDisplayName("QR Code Flow")

            ZStack {
                Color.gray.opacity(0.3)
                    .ignoresSafeArea()

                ConcordiumIDAppPoup.invokeIdAppActionsPopup(
                    onCreateAccount: {
                        print("Create account tapped")
                    },
                    onRecoverAccount: {
                        print("Recover account tapped")
                    },
                    walletConnectSessionTopic: "D323"
                )
            }
            .previewDisplayName("Create & Recover")

            ZStack {
                Color.gray.opacity(0.3)
                    .ignoresSafeArea()

                ConcordiumIDAppPoup.invokeIdAppActionsPopup(
                    onCreateAccount: {
                        print("Create account tapped")
                    },
                    walletConnectSessionTopic: "B8A2"
                )
            }
            .previewDisplayName("Create Only")

            ZStack {
                Color.gray.opacity(0.3)
                    .ignoresSafeArea()

                ConcordiumIDAppPoup.invokeIdAppActionsPopup(
                    onRecoverAccount: {
                        print("Recover account tapped")
                    }
                )
            }
            .previewDisplayName("Recover Only")
        }
    }
}
#endif


