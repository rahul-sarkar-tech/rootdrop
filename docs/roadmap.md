# RootDrop Development Roadmap

RootDrop is an evolving ecosystem. Our goal is to create the fastest, most private P2P engine for the modern web. Below is our vision for the upcoming versions.

## 🟢 Phase 1: Stability & Polish (Current)
*   [x] Multi-Socket Parallel Transport Engine
*   [x] Background Isolate Processing
*   [x] Modern OLED-Optimized UI
*   [x] Multi-Tier Storage Fallback System
*   [x] Professional Social Integration

## 🟡 Phase 2: Security & Privacy (Q3 2024)
*   **End-to-End Encryption (E2EE)**: Implementation of TLS or Noise Protocol for all local pipes.
*   **Zero-Knowledge Transfers**: Hashing all metadata so the transport layer has no visibility into file contents.
*   **Certificate Pinning**: Automatic trust establishment between frequent peers.

## 🟠 Phase 3: Advanced Transport (Q4 2024)
*   **Swarm Transfers**: Support for sending a single file to multiple receivers simultaneously (Multicast streaming).
*   **Resume Support**: Intelligent chunk tracking to resume interrupted transfers without re-sending the whole file.
*   **WebAssembly (WASM) Port**: Bringing the RootDrop engine to the browser for zero-install transfers.

## 🔴 Phase 4: Ecosystem Expansion (2025)
*   **Native Windows/Linux Clients**: Full desktop builds with system-tray integration.
*   **CLI Version**: A headless version of RootDrop for server-to-server transfers.
*   **RootDrop Cloud Relay**: Optional TURN/STUN relay for transfers when devices aren't on the same local network.

---
*Want to contribute? Check out our [Architecture Guide](./architecture.md) and join the movement.*
