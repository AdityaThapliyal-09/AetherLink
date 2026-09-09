# Contributing to AetherLink

First off, thank you for considering contributing to **AetherLink**! Disaster communication networks are life-critical systems, and your help makes our mesh routing and offline protocols more resilient, secure, and performant.

---

## 🛠️ Development Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/AdityaThapliyal-09/AetherLink.git
   cd AetherLink
   ```

2. **Install Flutter & Dart**:
   Ensure you have Flutter 3.24+ and Dart 3.5+ installed.
   ```bash
   flutter --version
   flutter doctor
   ```

3. **Fetch Dependencies**:
   ```bash
   flutter pub get
   ```

4. **Verify Quality & Static Analysis**:
   ```bash
   flutter analyze
   flutter test
   ```

---

## 📐 Coding Standards & Guidelines

- **Architecture**: Follow the clean layered architecture pattern:
  - `lib/core/`: Protocol constants, error definitions, utilities.
  - `lib/data/`: Local persistence (SQLite DAOs, database migrations).
  - `lib/domain/entities/`: Core data models (Packets, Peers, Messages, Routes).
  - `lib/services/`: BLE central/peripheral logic, AODV router, CryptoService.
  - `lib/presentation/`: Theme tokens, reusable widgets, navigation.
  - `lib/features/`: Feature screens (Chat, Home, Network, Peers, Settings, SOS).
- **Design System**: Strictly adhere to the Spotify-inspired dark UI tokens defined in `lib/presentation/theme/aether_theme.dart`:
  - Surfaces: `#121212` background, `#181818` card surfaces, `#1F1F1F` elevated controls.
  - Accent: `#1ED760` (Spotify Green), `#F3727F` (Emergency SOS Red).
  - Geometry: `BorderRadius.circular(8)` for cards, `BorderRadius.circular(9999)` for pill buttons/chips, `BoxShape.circle` for avatars and action buttons.
- **Safety**: Do NOT alter cryptographic primitive choices (X25519, AES-256-GCM) or BLE GATT packet chunking thresholds without corresponding automated unit test suites.

---

## 🧪 Testing Checklist

Before submitting a pull request, ensure:
1. `flutter analyze` reports **0 issues**.
2. All unit tests pass with 100% success: `flutter test`.
3. If introducing changes to BLE packet encoding or encryption, add unit tests in `test/crypto_test.dart` or corresponding test files.
4. Release compilation succeeds: `flutter build apk --release`.

---

## 🔀 Git Workflow

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feat/your-feature-name
   ```
2. Commit your changes with meaningful commit messages:
   ```bash
   git commit -m "feat(mesh): optimize AODV route expiry timer"
   ```
3. Push to your fork/branch and submit a Pull Request targeting `main`.
