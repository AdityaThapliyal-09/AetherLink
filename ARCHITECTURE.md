# AetherLink System Architecture & Protocol Specification

## 1. High-Level Architecture Overview

AetherLink is an autonomous, decentralized disaster communication mesh network built for mobile Android devices. It operates completely offline with zero reliance on cellular towers, Wi-Fi infrastructure, or internet uplinks.

```mermaid
graph TD
    subgraph Presentation Layer
        UI[Flutter UI - Spotify Dark Design]
        Router[GoRouter Navigation]
        Theme[AetherTheme Token Engine]
        Overlay[In-App Notification Heads-Up]
    end

    subgraph State & Orchestration Layer
        Provider[AetherProvider ChangeNotifier]
        Store[SQLite DAOs: Peers, Messages, Routes, Identity]
    end

    subgraph Core Mesh & Networking Layer
        NetMgr[NetworkManager Facade]
        AODV[AODV Routing Engine]
        Crypto[CryptoService: ECDH X25519 + AES-256-GCM]
        Chunker[GATT Chunker & Assembler]
    end

    subgraph Hardware & Native Android Layer
        BLE[AetherBleManager.kt - Dual-Role Central/Peripheral]
        Siren[Native AudioTrack PCM Siren 650-1400Hz]
        Vibrator[Android System Haptic Engine]
        Notif[Android NotificationManager Heads-Up Channel]
    end

    UI --> Provider
    Provider --> NetMgr
    NetMgr --> AODV
    NetMgr --> Crypto
    NetMgr --> Chunker
    NetMgr --> BLE
    BLE --> Siren
    BLE --> Vibrator
    BLE --> Notif
    Store --> Provider
```

---

## 2. Physical & Transport Layer: Dual-Role Bluetooth Low Energy

Every device running AetherLink functions simultaneously as a **GATT Client (Central)** and a **GATT Server (Peripheral)**:

1. **BLE Advertising & Discovery**:
   - **Primary Advertising Frame (`data`)**: Contains the 128-bit `SERVICE_UUID` (21 bytes total <= 31 bytes legacy BLE advertisement frame limit).
   - **Scan Response Frame (`scanResponse`)**: Contains Manufacturer Data (`0xAE78`) with local Node ID and truncated display name (28 bytes <= 31 bytes limit).
   - **Scanning Engine**: Operates with `ScanSettings.SCAN_MODE_LOW_LATENCY` (100% duty cycle). Features dual hardware filters for `SERVICE_UUID` and `MANUFACTURER_ID` with automatic fallback to software parsing for hardware-agnostic chipset support.

2. **Packet Chunking & Assembly**:
   - Standard BLE GATT MTU ranges between 23 and 512 bytes.
   - The `GattChunker` segments higher-level binary packet envelopes into MTU-safe fragments with 4-byte sequence headers and transparently reassembles them at the receiver before delivery.

---

## 3. Network & Routing Layer: AODV Mobile Mesh

AetherLink implements a mobile-optimized **Ad-hoc On-Demand Distance Vector (AODV)** routing algorithm:

```mermaid
sequenceDiagram
    autonumber
    participant NodeA as Node A (Source)
    participant NodeB as Node B (Relay)
    participant NodeC as Node C (Destination)

    Note over NodeA,NodeC: Route Discovery (Out of Radio Range)
    NodeA->>NodeB: RREQ (Route Request: Target=Node C, Seq=1)
    NodeB->>NodeC: RREQ (Forwarded: Target=Node C, Hop=2)
    NodeC-->>NodeB: RREP (Route Reply: Dest=Node C, HopCount=1)
    NodeB-->>NodeA: RREP (Route Reply: NextHop=Node B, TotalHops=2)
    
    Note over NodeA,NodeC: Encrypted End-to-End Data Delivery
    NodeA->>NodeB: Encrypted Packet (Dest: Node C, via Node B)
    NodeB->>NodeC: Forwarded Encrypted Packet (Blind Relay)
```

- **RREQ (Route Request)**: Broadcasts when a destination node is not in the active routing table.
- **RREP (Route Reply)**: Unicast back along the reverse path with hop counts and destination sequence numbers.
- **RERR (Route Error)**: Emitted when an active link breaks to invalidate broken paths.
- **Loop Prevention**: TTL decrementation, sequence number freshness, and a circular message ID cache eliminate broadcast storms.

---

## 4. Cryptographic Security Layer

```mermaid
flowchart LR
    A[Plaintext Message] --> B[AES-256-GCM Encryptor]
    K[X25519 ECDH Session Key] --> B
    IV[12-Byte Secure Nonce] --> B
    B --> C[Ciphertext + 16-Byte Auth Tag]
    C --> D[Blind Mesh Relay Transmission]
    D --> E[Recipient AES-256-GCM Decryptor]
    K --> E
    E --> F[Verified Plaintext Message]
```

- **Identity Generation**: Ed25519 keypair for identity signing, X25519 keypair for key exchange.
- **Key Agreement**: Instant mutual ECDH upon peer connection with domain separation via HKDF-SHA256.
- **Authenticated Encryption**: AES-256-GCM authenticated cipher with 12-byte IV and 16-byte MAC tag.
- **Blind Forwarding**: Intermediate relay nodes see only envelope headers; payload ciphertexts remain indecipherable and tamper-evident.

---

## 5. Emergency SOS Siren: Native Audio Synthesis

- When an emergency SOS packet is detected across the mesh, Android's `AudioTrack` synthesizes a dual-frequency audio sine wave directly into 16-bit PCM memory (`650 Hz ↔ 1400 Hz`) on `STREAM_ALARM`.
- Operates 100% offline with zero external audio assets or player dependencies.
- Synchronized with hardware vibration pulses (`longArrayOf(0, 450, 150, 450, 150, 450)`).
