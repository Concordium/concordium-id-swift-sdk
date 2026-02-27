# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.0] - 2026-02-27
### Added
- Added `IDAppRequestMethod.requestVerifiablePresentationV1` (`request_verifiable_presentation_v1`)
- Added request-method based `invokeIdAppActionsPopup` overload with `onGenerateProof` callback
- Added popup CTA switching between `Create New Account` and `Generate Proof` based on request method

### Changed
- Kept existing `invokeIdAppActionsPopup(onCreateAccount:walletConnectSessionTopic:)` as backward-compatible wrapper

---

## [1.1.0] - 2025-12-08
### Added
- Implemented getKeyAccounts() method to resolve a public key to wallet address(s)
- Updated Readme.

### Fixed
- Removed all old recovery code and UI elements
---

