# Changelog

All notable changes to the **AetherLink** project are documented in this file.

## [1.0.0] - 2026-09-08 — Production Release

### 🚀 Major Features
* **Decentralized BLE Mesh Networking**:
  * Dual-role Bluetooth Low Energy GATT architecture (simultaneous Central and Peripheral).
  * High-speed discovery with dual hardware filters for `SERVICE_UUID` and `MANUFACTURER_ID` (`0xAE78`).
  * 31-byte legacy advertising overflow compliance with split payload architecture.
* **AODV Mobile Ad-Hoc Routing**:
  * Ad-hoc On-Demand Distance Vector routing engine for multi-hop dynamic path discovery.
  * Loop prevention with TTL decrementing, sequence number validation, and message ID deduplication cache.
  * Store-and-forward queue for offline / delayed link resilience.
* **End-to-End Cryptography (E2EE)**:
  * Curve25519 (X25519 ECDH) key agreement with HKDF-SHA256 session key derivation.
  * AES-256-GCM authenticated encryption with 12-byte secure nonces and 16-byte MAC authentication tags.
  * Visual out-of-band SHA-256 key fingerprint verification.
* **Emergency Life-Safety SOS & Native Siren**:
  * Priority mesh flooding for emergency SOS distress alerts.
  * Zero-dependency native Android PCM 16-bit `AudioTrack` dual-frequency siren synthesizer (650 Hz ↔ 1400 Hz) on `STREAM_ALARM`.
  * Coordinated hardware vibration alert patterns.
* **Heads-Up Notifications & Tracking**:
  * In-app animated heads-up dropdown notification overlay.
  * High-importance Android status bar heads-up notifications.
  * Dynamic unread message counters on navigation bar and peer cards with auto-clearing logic.
* **Spotify-Inspired Visual Identity & Dark Theme**:
  * Complete UI overhaul adopting the Spotify design system: `#121212` background, `#181818` card surfaces, `#1F1F1F` elevated controls, `#1ED760` Spotify Green accents, and `#F3727F` SOS emergency triggers.
  * Full pill (`BorderRadius.circular(9999)`) inputs, badges, and action buttons.
  * 8px (`BorderRadius.circular(8)`) card containers.
  * Black and neon-green circular Spotify-style launcher icon with glowing concentric arcs.
* **Dedicated About & Academic Attribution**:
  * Comprehensive credit screen honoring the project development team and academic mentorship at Graphic Era Hill University (GEHU).
