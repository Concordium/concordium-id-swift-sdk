import SwiftUI

public struct ConcordiumIDAppPoup: View {
    private let walletConnectUri: String?
    private let onCreateAccount: (() async -> Void)?
    private let onRecoverAccount: (() async -> Void)?
    private let walletConnectSessionTopic: String?

    @Environment(\.openURL) private var openURL
    @State private var isPresented: Bool = true
    @State private var isProcessingCreate: Bool = false
    @State private var isProcessingRecover: Bool = false

    public init(
        walletConnectUri: String? = nil,
        onCreateAccount: (() async -> Void)? = nil,
        onRecoverAccount: (() async -> Void)? = nil,
        walletConnectSessionTopic: String? = nil
    ) {
        self.walletConnectUri = walletConnectUri
        self.onCreateAccount = onCreateAccount
        self.onRecoverAccount = onRecoverAccount
        self.walletConnectSessionTopic = walletConnectSessionTopic
    }

    public var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.5).ignoresSafeArea()
                popupBox
            }
        }
    }

    private var popupBox: some View {
        VStack(spacing: 0) {
            VStack(alignment: .center, spacing: 16) {
                HStack { Spacer(); closeButton }
                stepHeader
                Text("Please follow and complete the\naccount setup in [ID App].")
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)
                if let walletConnectUri {
                    QRCodeView(text: "\(IDAPPHOSTS.mobile)wallet-connect?encodedUri=\(walletConnectUri)")
                        .frame(width: 160, height: 160)
                }
                openIDAppButton
            }
            .padding(24)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let topic = walletConnectSessionTopic, !topic.isEmpty {
                VStack(spacing: 8) {
                    Text("To Create an Account, match the code below in the [ID App]")
                        .font(.system(size: 13, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text(String(topic.prefix(4)).uppercased())
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 86, height: 86)
                        .overlay(Circle().stroke(Color(#colorLiteral(red: 0.066, green: 0.262, blue: 0.655, alpha: 1)), lineWidth: 2))
                }
                .padding(16)
                .frame(maxWidth: 330)
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: 330)
    }

    private var stepHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(Color(#colorLiteral(red: 0.066, green: 0.262, blue: 0.655, alpha: 1))).frame(width: 16, height: 16)
                Rectangle().fill(Color.black.opacity(0.2)).frame(height: 1)
                Circle().strokeBorder(Color.black, lineWidth: 1).frame(width: 16, height: 16)
                Rectangle().fill(Color.black.opacity(0.2)).frame(height: 1)
                Circle().strokeBorder(Color.black, lineWidth: 1).frame(width: 16, height: 16)
            }
            HStack {
                Text("Connect /\n Pair Apps").font(.system(size: 11, weight: .bold)).multilineTextAlignment(.center)
                Spacer()
                Text("Complete ID\nVerification").font(.system(size: 11, weight: .semibold)).multilineTextAlignment(.center)
                Spacer()
                Text(actionText).font(.system(size: 11, weight: .regular)).multilineTextAlignment(.center)
            }
        }
    }

    private var openIDAppButton: some View {
        VStack(spacing: 12) {
            if let onCreateAccount {
                Button(action: { Task { await runCreate(onCreateAccount) } }) {
                    Text(isProcessingCreate ? "⏳ Please wait" : "Create New Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(#colorLiteral(red: 0.0, green: 0.290, blue: 0.576, alpha: 1)))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .disabled(isProcessingCreate)
            }

            if let onRecoverAccount {
                Button(action: { Task { await runRecover(onRecoverAccount) } }) {
                    Text(isProcessingRecover ? "⏳ Please wait" : "Recover Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                }
                .disabled(isProcessingRecover)
            }
        }
    }

    private var closeButton: some View {
        Button(action: { isPresented = false }) {
            Text("×").font(.system(size: 24)).foregroundColor(.gray)
        }
        .accessibilityLabel(Text("Close"))
    }

    private var actionText: String {
        switch (onCreateAccount != nil, onRecoverAccount != nil) {
        case (true, false): return "Create\n Account"
        case (false, true): return "Recover\n Account"
        case (true, true): return "Create / Recover\n Account"
        default: return "Create / Recover\n Account"
        }
    }

    private func runCreate(_ action: @escaping () async -> Void) async {
        isProcessingCreate = true
        await action()
        isProcessingCreate = false
    }

    private func runRecover(_ action: @escaping () async -> Void) async {
        isProcessingRecover = true
        await action()
        isProcessingRecover = false
    }
}

public struct QRCodeView: View {
    let text: String
    public init(text: String) { self.text = text }
    public var body: some View {
        // Placeholder view; replace with CoreImage CIFilter.qrCodeGenerator
        ZStack {
            Color.white
            Text("QR").foregroundColor(.black)
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))
    }
}


