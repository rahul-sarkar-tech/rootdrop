# RootDrop Protocol v1.0

## Overview
RootDrop uses a custom lightweight protocol over raw TCP sockets for file transfers. The protocol is designed to be **receiver-driven**, allowing for resumable and parallel downloads.

## Message Structure
Every message consists of a 4-byte header indicating the length of the JSON metadata, followed by the UTF-8 JSON string, and an optional binary payload (only present in `chunk_data` messages).

```
┌─────────────────────────────────────────┐
│ 4 bytes: Header length (big-endian)     │
├─────────────────────────────────────────┤
│ N bytes: JSON metadata (UTF-8)          │
├─────────────────────────────────────────┤
│ M bytes: Binary payload (chunk data)    │
└─────────────────────────────────────────┘
```

## Discovery
Discovery is handled via UDP Broadcasts on port `41234`.
**Broadcast Payload:**
```json
{
  "app": "rootdrop",
  "version": 1,
  "device_name": "Device Name",
  "platform": "macos",
  "ip": "192.168.1.10",
  "transfer_port": 50000,
  "timestamp": 1715300000000
}
```

## Transfer Lifecycle

1. **Offer (Sender → Receiver)**
```json
{
  "type": "transfer_offer",
  "transfer_id": "uuid",
  "file_name": "example.mp4",
  "file_size": 104857600,
  "chunk_size": 1048576,
  "total_chunks": 100
}
```

2. **Accept (Receiver → Sender)**
```json
{
  "type": "transfer_accept",
  "transfer_id": "uuid"
}
```

3. **Chunk Request (Receiver → Sender)**
```json
{
  "type": "chunk_request",
  "transfer_id": "uuid",
  "chunk_index": 0
}
```

4. **Chunk Data (Sender → Receiver)**
```json
{
  "type": "chunk_data",
  "transfer_id": "uuid",
  "chunk_index": 0,
  "chunk_size": 1048576,
  "sha256": "hash_string"
}
```
*(Followed immediately by binary payload)*

5. **Chunk Ack (Receiver → Sender)**
```json
{
  "type": "chunk_ack",
  "transfer_id": "uuid",
  "chunk_index": 0
}
```

6. **Transfer Complete (Receiver → Sender)**
```json
{
  "type": "transfer_complete",
  "transfer_id": "uuid"
}
```

## Error Handling
- `chunk_nack`: Sent by receiver if SHA256 validation fails. Sender should resend data upon next `chunk_request`.
- `transfer_cancel`: Sent by either party to immediately terminate the transfer.
- `transfer_reject`: Sent by receiver to decline an initial offer.
