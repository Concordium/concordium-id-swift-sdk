//
//  ConcordiumIDAppPopup.swift
//  concordium-id-swift-sdk
//

import SwiftUI
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif


// MARK: - IDApp Hosts

public enum IDAppHost {
    /// Mobile deep link host (iOS / Android)
    public static let mobile = "concordiumidapp://"
}


/// Popup view for interacting with the Concordium ID App from a host application.
///
/// Provides two modes:
/// - QR code flow for connecting to the ID App.
/// - Provide flow to create or recover an account via async handlers.
public struct ConcordiumIDAppPopup: View {
    private let walletConnectUri: String?
    private let onCreateAccount: (() async -> Void)?
    private let walletConnectSessionTopic: String?

    @Environment(\.openURL) private var openURL
    @State private var isPresented: Bool = true
    @State private var isProcessingCreate: Bool = false

    private init(
        walletConnectUri: String? = nil,
        onCreateAccount: (() async -> Void)? = nil,
        walletConnectSessionTopic: String? = nil
    ) {
        self.walletConnectUri = walletConnectUri
        self.onCreateAccount = onCreateAccount
        self.walletConnectSessionTopic = walletConnectSessionTopic
    }

    // Determine if we should show the Provide case (account creation/recovery flow)
    private var shouldShowProvideCase: Bool {
        return onCreateAccount != nil
    }

    /// Main content based on the selected flow.
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
     Closes the popup.
     This method is used to dismiss the currently displayed popup.
     */
    public static func closePopup() {
        // This would be handled by the presenting view controller
        // In a real implementation, you might use a notification or delegate pattern
        NotificationCenter.default.post(name: NSNotification.Name("ConcordiumIDAppPopupClose"), object: nil)
    }

    /**
     Opens the ID App using a deep link.
     This method is used to redirect the user to the ID App on mobile devices.
     */
    public static func openIdapp(walletConnectMobileUrl: String, walletConnectDesktopUrl: String? = nil) {
        if let url = URL(string: walletConnectMobileUrl) {
            UIApplication.shared.open(url)
        }
    }

    /**
     Shows the QR code popup for wallet connection.
     This function creates a popup that prompts the user to scan a QR code for wallet connection.
     */
    public static func invokeIdAppDeepLinkPopup(walletConnectUri: String) -> ConcordiumIDAppPopup {
        guard !walletConnectUri.isEmpty else {
            fatalError("ConcordiumIDAppPopup.invokeIdAppDeepLinkPopup() requires a valid walletConnectUri")
        }

        return ConcordiumIDAppPopup(walletConnectUri: walletConnectUri)
    }

    /**
     Shows the account creation/recovery popup.
     This function creates a popup that allows users to create new accounts or recover existing ones.
     */
    public static func invokeIdAppActionsPopup(
        onCreateAccount: (() async -> Void)? = nil,
        walletConnectSessionTopic: String? = nil
    ) -> ConcordiumIDAppPopup {
        guard onCreateAccount != nil else {
            fatalError("onCreateAccount handler must be provided")
        }

        guard walletConnectSessionTopic != nil else {
            fatalError("Wallet Connect's session.topic is required for account creation")
        }

        return ConcordiumIDAppPopup(
            onCreateAccount: onCreateAccount,
            walletConnectSessionTopic: walletConnectSessionTopic
        )
    }

    // MARK: - Provide Case (Account Creation/Recovery Flow)
    private var provideCasePopup: some View {
        VStack(spacing: 0) {
            // Header with logo and close button
            VStack(spacing: 16) {
                // Concordium Logo and Brand
                ConcordiumLogoView()
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var provideCaseStepHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 0) {
                StepView(title: "Connect /\nPair Apps", isActive: true)
                ConnectingLine()
                StepView(title: "Complete ID \nVerification", isActive: true)
                ConnectingLine()
                StepView(title: "Create Account", isActive: false)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if let onCreateAccount = onCreateAccount {
                Button(action: { Task { await runCreate(onCreateAccount) } }, label: {
                    Text(isProcessingCreate ? "⏳ Please wait" : "Create New Account")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color(#colorLiteral(red: 0.0, green: 0.290, blue: 0.576, alpha: 1)))
                        .cornerRadius(6)
                })
                .disabled(isProcessingCreate)
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
                ConcordiumLogoView()

                // Progress Steps
                stepHeader

                // Main Content
                VStack(spacing: 32) {
                    Text("Please follow and complete the \n account setup in [ID App].")
                        .font(.system(size: 16, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.black)

                    if let walletConnectUri {
                        QRCodeView(text: "\("IDAppHost.mobile")wallet-connect?encodedUri=\(walletConnectUri)")
                            .frame(width: 200, height: 200)
                    }
                    Button(action: {
                        // Your action here
                    }, label: {
                        Text("Open {ID App}")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color(#colorLiteral(red: 0.066, green: 0.262, blue: 0.655, alpha: 1)))
                            .cornerRadius(8)
                    })
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
                StepView(title: "Connect /\nPair Apps ", isActive: true)
                ConnectingLine()
                StepView(title: "Complete ID\nVerification", isActive: false)
                ConnectingLine()
                StepView(title: "Create Account", isActive: false)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var appStoreButton: some View { AppStoreButtonView() }

    private var closeButton: some View {
        Button(action: {
            ConcordiumIDAppPopup.closePopup()
            isPresented = false
        }, label: {
            Text("x").font(.system(size: 24)).foregroundColor(.gray)
        })
        .accessibilityLabel(Text("Close"))
    }

    private var actionText: String {
        return "Create\n Account"
    }

    private func runCreate(_ action: @escaping () async -> Void) async {
        isProcessingCreate = true
        await action()
        isProcessingCreate = false
    }

}
