//
//  ConcordiumIDAppPoup.swift
//  concordium-id-swift-sdk
//
//  Created by Lov  on 23/10/25.
//


import SwiftUI
import CoreImage.CIFilterBuiltins

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
            popupBox
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var popupBox: some View {
        VStack(spacing: 0) {
            VStack(alignment: .center, spacing: 16) {
                HStack { Spacer(); closeButton }
                stepHeader
                Divider()
                Text("Please follow and complete the\naccount setup in [ID App].")
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)
                if let walletConnectUri {
                    QRCodeView(text: "\("IDAPP_HOSTS.mobile")wallet-connect?encodedUri=\(walletConnectUri)")
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
            Spacer()
        }
        .frame(alignment: .top)
    }

    private var stepHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                VStack {
                    Circle().fill(Color(#colorLiteral(red: 0.066, green: 0.262, blue: 0.655, alpha: 1))).frame(width: 16, height: 16)
                    Text("Connect /\n Pair Apps").font(.system(size: 11, weight: .bold)).multilineTextAlignment(.center)
                }
                Rectangle().fill(Color.black.opacity(0.2)).frame(height: 1)
                VStack {
                    Circle().strokeBorder(Color.black, lineWidth: 1).frame(width: 16, height: 16)
                    Text("Complete ID\nVerification").font(.system(size: 11, weight: .semibold)).multilineTextAlignment(.center)
                }
                Rectangle().fill(Color.black.opacity(0.2)).frame(height: 1)
                VStack {
                    Circle().strokeBorder(Color.black, lineWidth: 1).frame(width: 16, height: 16)
                    Text(actionText).font(.system(size: 11, weight: .regular)).multilineTextAlignment(.center)
                }
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
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        if let image = generateQRCode(from: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.2), lineWidth: 1))
        } else {
            ZStack {
                Color.gray.opacity(0.1)
                Text("⚠️ Invalid QR data")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")

        guard let outputImage = filter.outputImage else { return nil }

        // Scale QR to higher resolution
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
