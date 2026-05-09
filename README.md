# 🚀 RootDrop

<div align="center">
  <p align="center">
    <img src="https://img.shields.io/badge/Version-1.0.0-blue.svg?style=for-the-badge" />
    <img src="https://img.shields.io/badge/License-AGPL--3.0-green.svg?style=for-the-badge" />
    <img src="https://img.shields.io/badge/Platform-Android%20%7C%20macOS%20%7C%20Linux-lightgrey.svg?style=for-the-badge" />
  </p>
  
  <p align="center">
    <strong>The High-Performance, Privacy-First P2P Engine for a Cross-Platform World.</strong>
  </p>

  <p align="center">
    RootDrop is a custom-built file sharing engine designed to saturate local network bandwidth. <br />
    No Cloud. No Middlemen. Just pure, parallel TCP streams.
  </p>

  <p align="center">
    <a href="#-features">Features</a> •
    <a href="#-benchmarks">Benchmarks</a> •
    <a href="#-architecture">Architecture</a> •
    <a href="#-getting-started">Quick Start</a>
  </p>
</div>

---

## ⚡ Why RootDrop?

Traditional LAN sharing apps often rely on simple HTTP servers, which hit bottlenecks during large file transfers. RootDrop was engineered from the ground up to solve this using a **Multi-Pipe Parallel Architecture**.

### 💎 Premium Value Stack

| Feature | The RootDrop Advantage |
| :--- | :--- |
| **Throughput** | **4x Parallel Sockets** saturate 5GHz WiFi bands up to 38MB/s. |
| **Privacy** | **Zero-Cloud Architecture**. Your files never leave your physical network. |
| **Integrity** | **Background SHA256 Hashing** ensures every byte is verified in real-time. |
| **Efficiency** | **Zero-Memory Streaming** handles 50GB+ files without a single UI lag. |
| **Resilience** | **Smart Storage Fallbacks** bypass complex OS Sandbox restrictions automatically. |

---

## 📊 Performance Benchmarks

*Measured on 802.11ax (Wi-Fi 6) using MacBook Pro & Android Flagship.*

| Transfer Scenario | Connection | Avg. Speed | Peak Speed | 1GB Transfer |
| :--- | :--- | :--- | :--- | :--- |
| **Android ↔ macOS** | **5 GHz (High Band)** | **32 MB/s** | **38 MB/s** | **~26s** |
| **Android ↔ macOS** | **2.4 GHz (Legacy)** | **6 MB/s** | **8 MB/s** | **~2.1m** |
| **Android ↔ Android** | **Direct Link** | *Pending* | *TBD* | *TBD* |

> [!TIP]
> **Pro Tip**: For maximum speed, ensure both devices are within 5 meters of the router and using the 5GHz band.

---

## 🏗️ Deep-Dive Architecture

RootDrop's performance comes from its non-blocking, multi-threaded approach to networking.

### 1. Discovery Radar (UDP)
Instant peer detection using a custom UDP Multicast protocol. On macOS, RootDrop explicitly binds to the physical WiFi interface to ensure 100% reliable discovery inside the App Sandbox.

### 2. Multi-Pipe Transport (TCP)
Unlike standard apps, RootDrop opens **4 independent TCP pipes** for a single file.
- **Pipe 1**: Command & Control (Negotiation).
- **Pipes 2-4**: High-speed Data Streams.
- **Result**: Drastically reduced TCP overhead and increased overall throughput.

### 3. Background Verification (Isolates)
Hashing is CPU-intensive. RootDrop offloads all SHA256 generation to **dedicated Dart Isolates**, keeping the main UI thread at a silky-smooth 60 FPS even during 40MB/s transfers.

---

## 🛠️ Developer Setup

Get RootDrop running on your machine in under 60 seconds.

```bash
# Clone the repository
git clone https://github.com/rahul-sarkar-tech/rootdrop.git

# Navigate to project
cd rootdrop

# Get dependencies
flutter pub get

# Run on your connected device
flutter run
```

---

## 📁 Key Module Map

- `lib/core/discovery/`: Multicast peer radar.
- `lib/core/transport/`: High-performance TCP socket pool.
- `lib/core/scheduler/`: Multi-pipe session management.
- `lib/core/chunk_engine/`: Isolate-based hashing & merging.
- `lib/core/storage/`: Permission-aware I/O fallback logic.

---

## 🎯 v1.0 Roadmap

- [x] **Parallel Engine**: 4x Multi-socket transport.
- [x] **Turbo Hashing**: Background Isolate verification.
- [x] **Smart Storage**: 4-Tier Sandbox fallback system.
- [x] **Radar Discovery**: Multicast interface binding fix.
- [ ] **Cross-Platform**: Full Linux & Windows support.
- [ ] **Security**: TLS-encrypted local pipes.
- [ ] **UX**: QR-pairing for legacy network discovery.

---

## 📜 License & Open Source

RootDrop is proudly **Open Source**. 
Distributed under the **GNU Affero General Public License v3.0**.

## 👨‍💻 Author

**Rahul Sarkar**

<a href="https://github.com/rahul-sarkar-tech/rootdrop">
  <img src="https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white" />
</a>
<a href="https://www.linkedin.com/in/rahul-rootthrive">
  <img src="https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white" />
</a>
<a href="https://www.instagram.com/rahulxoperator">
  <img src="https://img.shields.io/badge/Instagram-E4405F?style=for-the-badge&logo=instagram&logoColor=white" />
</a>

---

<div align="center">
  <a href="https://github.com/rahul-sarkar-tech/rootdrop">
    <img src="https://img.shields.io/badge/GitHub-View_on_GitHub-181717?style=for-the-badge&logo=github" />
  </a>
</div>

---

<div align="center">
  Built with ❤️ by <strong>Rahul Sarkar</strong> <br />
  Optimized for speed. Designed for privacy.
</div>
