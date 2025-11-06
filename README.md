## Concordium ID Swift SDK

A lightweight Swift SDK to integrate Concordium ID App flows in iOS/macOS apps. It provides:

- Core APIs to sign and submit credential deployment transactions
- Utilities to derive account keys from a mnemonic
- SwiftUI components for QR connection and create/recover account flows

### Installation

Add the package using Swift Package Manager (Xcode or `Package.swift`).

```swift
.package(url: "https://github.com/your-org/concordium-id-swift-sdk.git", from: "1.0.0")
```

Then add the library to your target dependencies.

### Quick Start (Core)

```swift
import ConcordiumIDAppSDK

// Prepare inputs
let seedPhrase = "abandon ability able ..." // BIP39
let network: Network = .testnet
let accountIndex: CredentialCounter = 0
let serialized = "{\n  \"expiry\": 1730830000,\n  \"randomness\": { ... },\n  \"unsignedCdi\": "... JSON ..."\n}"

Task {
    do {
        try await ConcordiumIDAppSDK.signAndSubmit(
            accountIndex: accountIndex,
            seedPhrase: seedPhrase,
            serializedCredentialDeploymentTransaction: String,
            network: network
        )
    } catch {
        // handle error
    }
}
```

Derive an account key pair:

```swift
let keys = try await ConcordiumIDAppSDK.generateAccountWithSeedPhrase(
    from: seedPhrase,
    network: network,
    accountIndex: accountIndex
)
print(keys.publicKey)
```

### Quick Start (UI)

QR connect popup:

```swift
ConcordiumIDAppPoup.invokeIdAppDeepLinkPopup(walletConnectUri: "wc:...@2?...")
```

Provide flow (create/recover):

```swift
ConcordiumIDAppPoup.invokeIdAppActionsPopup(
    onCreateAccount: { /* async create */ },
    onRecoverAccount: { /* async recover */ },
    walletConnectSessionTopic: "ABCD"
)
```

### Documentation

- Low-Level Design and sequence diagrams: `docs/LLD.md`
