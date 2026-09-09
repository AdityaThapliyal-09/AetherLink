# Security Policy & Cryptographic Model

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.0   | :white_check_mark: |

---

## 🛡️ Cryptographic Architecture

AetherLink is engineered for extreme hostile environments where nodes cannot rely on certificate authorities (CAs), public key infrastructures (PKI), or remote key servers.

### 1. Key Agreement & Identity
* **Curve25519 (X25519 ECDH)**:
  * Each node generates an X25519 keypair during identity initialization.
  * Private keys are secured in encrypted on-device storage.
  * Mutual key exchange is performed automatically upon Bluetooth Low Energy connection.
* **HKDF-SHA256**:
  * Shared Diffie-Hellman secrets are passed through HKDF (HMAC-based Key Derivation Function) with protocol domain salt (`AetherLink-v1-Salt`) to derive a 256-bit symmetric session key.

### 2. Authenticated Symmetric Encryption
* **AES-256-GCM (Galois/Counter Mode)**:
  * All 1-to-1 payload data (messages, receipts) are encrypted with 256-bit AES-GCM.
  * Every packet carries a 12-byte cryptographically secure nonce (IV) and a 16-byte MAC authentication tag.
  * Relay nodes forward ciphertexts blindly; intermediate hops cannot inspect or tamper with message contents.

### 3. Out-of-Band Fingerprint Verification
* Users can verify peer identities out-of-band by comparing the SHA-256 key fingerprint (truncated 16-character hexadecimal) in person, mitigating Man-In-The-Middle (MITM) attacks.

---

## 🚨 Reporting a Vulnerability

If you discover a security vulnerability or cryptographic defect in AetherLink:
1. **Do NOT open a public GitHub issue.**
2. Send a detailed report to the core security maintainers:
   * **Aditya Thapliyal**: `adityathapliyal52@gmail.com`
   * **Suhail**: `Khansuhail49758@gmail.com`
3. Include:
   * Description of the vulnerability
   * Steps to reproduce or proof of concept
   * Affected device models or Android OS versions
4. The maintainers will respond within 48 hours to validate and prepare a patch.
