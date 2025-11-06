# **Concordium ID Swift SDK**

A lightweight and modern Swift SDK that enables seamless integration of **Concordium ID App** flows into your iOS applications.

The SDK provides a complete set of APIs and UI components for:

* Creating and submitting **credential deployment transactions**
* Deriving **account keys** securely from a BIP39 mnemonic phrase
* Presenting **SwiftUI-based flows** for QR connection and account creation/recovery

---

## 🚀 **Features**

* 🔐 Wallet and key derivation using secure BIP39-based seed phrases
* 🧩 Simple async APIs for signing and submitting credential deployments
* 🪄 Pre-built SwiftUI popups for Create, Recover, and WalletConnect flows
* ⚙️ Environment configuration (Testnet / Mainnet)
* 💻 Works across iOS and macOS targets

---

## 📦 **Installation**

The SDK is distributed via **Swift Package Manager (SPM)**.

### **Using Xcode**

1. In Xcode, go to **File ▸ Add Packages...**
2. Enter the repository URL:

   ```
   https://github.com/your-org/concordium-id-swift-sdk.git
   ```
3. Select **Up to Next Major Version** and add the package to your target.

### **Using `Package.swift`**

```swift
dependencies: [
    .package(url: "https://github.com/Concordium/concordium-id-swift-sdk.git", from: "1.0.0")
]
```

Then include the library in your target dependencies:

```swift
.target(
    name: "Client target app name",
    dependencies: ["ConcordiumIDAppSDK"]
)
```

---

## ⚡️ **Quick Start — Core APIs**

Import the SDK:

```swift
import ConcordiumIDAppSDK
```

Initialize the SDK (optional, defaults to `.testnet`):

```swift
ConcordiumIDAppSDK.initialize(with: .testnet)
```

### **Submit a Credential Deployment Transaction**

```swift
let seedPhrase = "abandon ability able ..." // BIP39 mnemonic
let network: Network = .testnet
let accountIndex: CredentialCounter = 0

let serializedTransaction = """
{
    "expiry": 1730830000,
    "unsignedCdi": "{ ... JSON ... }"
}
"""

Task {
    do {
        let txHash = try await ConcordiumIDAppSDK.signAndSubmit(
            accountIndex: accountIndex,
            seedPhrase: seedPhrase,
            serializedCredentialDeploymentTransaction: serializedTransaction,
            network: network
        )
        print("✅ Transaction submitted with hash: \(txHash)")
    } catch {
        print("❌ Failed to submit transaction: \(error)")
    }
}
```

### **Derive an Account Key Pair**

```swift
let accountKeys = try await ConcordiumIDAppSDK.generateAccountWithSeedPhrase(
    from: seedPhrase,
    network: network,
    accountIndex: accountIndex
)

print("Public Key:", accountKeys.publicKey)
```

---

## 🖼️ **Quick Start — SwiftUI Components**

### **QR Connect Popup**

```swift
ConcordiumIDAppPoup.invokeIdAppDeepLinkPopup(
    walletConnectUri: "wc:...@2?..."
)
```

### **Create / Recover Account Popup**

```swift
ConcordiumIDAppPoup.invokeIdAppActionsPopup(
    onCreateAccount: { /* async create flow */ },
    onRecoverAccount: { /* async recover flow */ },
    walletConnectSessionTopic: "ABCD"
)
```

These pre-built popups handle UI presentation and user interaction for Concordium ID flows.

---

## ⚙️ **Configuration**

You can connect to either **Mainnet** or **Testnet** by initializing with the appropriate configuration:

```swift
ConcordiumIDAppSDK.initialize(with: .mainnet)
```

Or define your own custom configuration:

```swift
let customConfig = ConcordiumConfiguration(
    host: "grpc.devnet.concordium.com",
    port: 20000,
    useTLS: true
)

ConcordiumIDAppSDK.initialize(with: customConfig)
```

---

## 📘 **Documentation**

Detailed documentation and diagrams can be found in:

```
docs/LLD.md
```

It includes:

* Sequence diagrams for credential deployment
* Key derivation flow
* SDK initialization and GRPC communication model

---

## 🧱 **Architecture Overview**

| Layer              | Description                                                 |
| ------------------ | ----------------------------------------------------------- |
| **Core SDK**       | Core APIs for key derivation, signing, and GRPC interaction |
| **UI Components**  | SwiftUI-based popups and flows for ID App integration       |
| **Configuration**  | Simple setup for network endpoints (Mainnet/Testnet)        |
| **Error Handling** | Unified `SDKError` enum for predictable failure cases       |

---

## 🧩 **Requirements**

* iOS 15.0+
* Swift 6.0+
* Xcode 16.0+

---
