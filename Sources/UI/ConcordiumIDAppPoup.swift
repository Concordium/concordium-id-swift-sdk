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

    private init(
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

    // Determine if we should show the Provide case (account creation/recovery flow)
    private var shouldShowProvideCase: Bool {
        return onCreateAccount != nil || onRecoverAccount != nil
    }

    public var body: some View {
        VStack {
            Group {
                if shouldShowProvideCase {
                    provideCasePopup
                } else {
                    popupBox
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(alignment: .top)
    }

    // MARK: - Static Methods (JavaScript API Compatibility)

    /**
     * Closes the popup.
     * This method is used to dismiss the currently displayed popup.
     */
    public static func closePopup() {
        // This would be handled by the presenting view controller
        // In a real implementation, you might use a notification or delegate pattern
        NotificationCenter.default.post(name: NSNotification.Name("ConcordiumIDAppPoupClose"), object: nil)
    }

    /**
     * Opens the ID App using a deep link.
     * This method is used to redirect the user to the ID App on mobile devices.
     */
    public static func openIdapp(walletConnectMobileUrl: String, walletConnectDesktopUrl: String? = nil) {
        if let url = URL(string: walletConnectMobileUrl) {
            UIApplication.shared.open(url)
        }
    }

    /**
     * Shows the QR code popup for wallet connection.
     * This function creates a popup that prompts the user to scan a QR code for wallet connection.
     */
    public static func invokeIdAppDeepLinkPopup(walletConnectUri: String) -> ConcordiumIDAppPoup {
        guard !walletConnectUri.isEmpty else {
            fatalError("ConcordiumIDAppPoup.invokeIdAppDeepLinkPopup() requires a valid walletConnectUri")
        }
        
        return ConcordiumIDAppPoup(walletConnectUri: walletConnectUri)
    }

    /**
     * Shows the account creation/recovery popup.
     * This function creates a popup that allows users to create new accounts or recover existing ones.
     */
    public static func invokeIdAppActionsPopup(
        onCreateAccount: (() async -> Void)? = nil,
        onRecoverAccount: (() async -> Void)? = nil,
        walletConnectSessionTopic: String? = nil
    ) -> ConcordiumIDAppPoup {
        // Check if at least one of the handlers is provided
        guard onCreateAccount != nil || onRecoverAccount != nil else {
            fatalError("At least one of the handlers must be provided")
        }

        // For account creation, walletConnectSessionTopic is required
        if onCreateAccount != nil && walletConnectSessionTopic == nil {
            fatalError("Wallet Connect's session.topic is required for account creation")
        }

        return ConcordiumIDAppPoup(
            onCreateAccount: onCreateAccount,
            onRecoverAccount: onRecoverAccount,
            walletConnectSessionTopic: walletConnectSessionTopic
        )
    }

    // MARK: - Provide Case (Account Creation/Recovery Flow)
    private var provideCasePopup: some View {
        VStack(spacing: 0) {
            // Header with logo and close button
            VStack(spacing: 16) {
                // Concordium Logo and Brand
                concordiumLogo
                // Progress Steps for Provide Case
                provideCaseStepHeader

                Divider()

                // Main Content
                VStack(spacing: 32) {
                    Text("Only once you've completed the ID Verification, choose your next step.")
                        .font(.system(size: 16, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundColor(.black)

                    // Action Buttons based on available handlers
                    actionButtonsSection

                    // Show authentication code only for account creation
                    if onCreateAccount != nil {
                        authenticationCodeSection
                    }
                }
            }
            .padding(20)
            .background(Color.white)
        }
        .overlay(alignment: .topTrailing, content: {
            closeButton
                .padding([.top, .trailing], 32)
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity ,alignment: .top)
    }

    private var provideCaseStepHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 0) {
                stepView(title: "Connect /\nPair Apps", isActive: true)
                connectingLine
                stepView(title: "Complete ID \nVerification", isActive: true)
                connectingLine
                stepView(title: stepTitle, isActive: false)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var stepTitle: String {
        if onCreateAccount != nil && onRecoverAccount != nil {
            return "Create / Recover\nAccount"
        } else if onCreateAccount != nil {
            return "Create Account"
        } else {
            return "Recover Account"
        }
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Create Account Button
            if let onCreateAccount = onCreateAccount {
                Button(action: { Task { await runCreate(onCreateAccount) } }) {
                    Text(isProcessingCreate ? "⏳ Please wait" : "Create New Account")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color(#colorLiteral(red: 0.0, green: 0.290, blue: 0.576, alpha: 1)))
                        .cornerRadius(6)
                }
                .disabled(isProcessingCreate)
            }

            // Recover Account Button/Link
            if let onRecoverAccount = onRecoverAccount {
                if onCreateAccount != nil {
                    // Show as secondary link when both options are available
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black)
                        
                        Button(action: { Task { await runRecover(onRecoverAccount) } }) {
                            Text("Recover")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(#colorLiteral(red: 0.0, green: 0.282, blue: 0.655, alpha: 1)))
                                .underline()
                        }
                        .disabled(isProcessingRecover)
                    }
                } else {
                    // Show as primary button when only recovery is available
                    Button(action: { Task { await runRecover(onRecoverAccount) } }) {
                        Text(isProcessingRecover ? "⏳ Please wait" : "Recover Account")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                    }
                    .disabled(isProcessingRecover)
                }
            }
        }
    }

    private var authenticationCodeSection: some View {
        VStack(spacing: 16) {
            Text("To Create an Account, match the code \n below in the [ID App]")
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(.black)

            // Generate a random 4-character code with exact styling from JS
            if let topic = walletConnectSessionTopic, !topic.isEmpty {
                Text(String(topic.prefix(4)).uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(#colorLiteral(red: 0.0, green: 0.282, blue: 0.655, alpha: 1)))
                    .frame(width: 86, height: 86)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white, Color(red: 0.933, green: 0.933, blue: 0.933)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Circle().stroke(Color(#colorLiteral(red: 0.0, green: 0.282, blue: 0.655, alpha: 1)), lineWidth: 2.15))
                    .clipShape(Circle())
            } else {
                Text("AUTH")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(#colorLiteral(red: 0.0, green: 0.282, blue: 0.655, alpha: 1)))
                    .frame(width: 86, height: 86)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white, Color(red: 0.933, green: 0.933, blue: 0.933)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Circle().stroke(Color(#colorLiteral(red: 0.0, green: 0.282, blue: 0.655, alpha: 1)), lineWidth: 2.15))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
        .padding(.horizontal, -20)
    }

    private var popupBox: some View {
        VStack(spacing: 0) {
            // Header with logo and close button
            VStack(spacing: 16) {
                concordiumLogo

                // Progress Steps
                stepHeader

                // Main Content
                VStack(spacing: 32) {
                    Text("Please follow and complete the \n account setup in [ID App].")
                        .font(.system(size: 16, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.black)
                    
                    if let walletConnectUri {
                        QRCodeView(text: "\("IDAPP_HOSTS.mobile")wallet-connect?encodedUri=\(walletConnectUri)")
                            .frame(width: 200, height: 200)
                    }
                    Button(action: {
                        // Your action here
                    }) {
                        Text("Open {ID App}")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color(#colorLiteral(red: 0.066, green: 0.262, blue: 0.655, alpha: 1)))
                            .cornerRadius(8)
                    }
                    .frame(width: 320)
                }
                .frame(maxHeight: .infinity)
                .padding(.top, -67)
            }
            .frame(maxHeight: .infinity)
            .padding(20)
            .background(Color.white)

            // Footer with App Store buttons
            VStack(spacing: 16) {
                Text("If you don't have {ID App}. Install the app then return back here to continue.")
                    .font(.system(size: 13, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)

                HStack {
                    Spacer(minLength: 0)
                    appStoreButton
                    Spacer(minLength: 0)
                }
            }
            .padding(20)
            .background(Color(red: 0.95, green: 0.95, blue: 0.95))
        }
        .overlay(alignment: .topTrailing, content: {
            closeButton
                .padding([.top, .trailing], 32)
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var stepHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 0) {
                stepView(title: "Connect /\nPair Apps ", isActive: true)
                connectingLine
                stepView(title: "Complete ID\nVerification", isActive: false)
                connectingLine
                stepView(title: "Create / \n Recover Account", isActive: false)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func stepView(title: String, isActive: Bool) -> some View {
        VStack(spacing: 6) {
            Circle()
                .strokeBorder(isActive ? Color.clear : Color.black, lineWidth: 1)
                .background(
                    Circle().fill(isActive ? Color(#colorLiteral(red: 0.0, green: 0.282, blue: 0.655, alpha: 1)) : Color.clear)
                )
                .frame(width: 16, height: 16)
            Text(title)
                .font(.system(size: 11, weight: isActive ? .bold : .medium))
                .multilineTextAlignment(.leading)
                .foregroundColor(isActive ? Color.black : Color.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .top) // maintain alignment
    }

    private var connectingLine: some View {
        // Align line with circle center visually
        Rectangle()
            .fill(Color.black.opacity(0.2))
            .frame(height: 1)
            .frame(maxWidth: 50)
            .offset(y: -18)
    }

    private var concordiumLogo: some View {
        Group {
            if let image = UIImage(named: "concordium_logo", in: Bundle.module, compatibleWith: nil) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 60)
            } else {
                // Fallback to simple logo design
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

    private var appStoreButton: some View {
        Button(action: {
            // Open App Store
            if let url = URL(string: "https://apps.apple.com/app/concordium-id/id123456789") {
                openURL(url)
            }
        }) {
            Group {
                if let image = UIImage(named: "app_store", in: Bundle.module, compatibleWith: nil) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 40)
                        .cornerRadius(8)
                } else {
                    // Fallback to text-based button
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
        }
    }

    private var closeButton: some View {
        Button(action: {
            ConcordiumIDAppPoup.closePopup()
            isPresented = false
        }) {
            Text("x").font(.system(size: 24)).foregroundColor(.gray)
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

// MARK: - Preview
#if DEBUG
struct ConcordiumIDAppPoup_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // QR Code Flow using static method
            ZStack {
                Color.gray.opacity(0.3)
                    .ignoresSafeArea()

                ConcordiumIDAppPoup.invokeIdAppDeepLinkPopup(
                    walletConnectUri: "wc:1234567890abcdef@2?relay-protocol=irn&symKey=abcdef1234567890"
                )
            }
            .previewDisplayName("QR Code Flow")

            // Both Create and Recover Available using static method
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

            // Only Create Account using static method
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

            // Only Recover Account using static method
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
