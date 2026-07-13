# macOS Hand Server (Apple Vision)

Streams 21 hand landmarks (MediaPipe joint order) as NDJSON over TCP for the Godot client.

## Build

```bash
./build.sh
# → ../../bin/macos_hand_server.app
```

## Run

```bash
../../bin/macos_hand_server --port 17452
```

Godot `HandTracker` spawns this automatically on macOS when the binary exists.

## Protocol

One JSON object per line:

```json
{"t":1234.5,"ok":true,"hands":[{"side":"Right","conf":0.9,"pts":[[x,y,c], ...21]}]}
```

- Coordinates: normalized, origin **top-left**, unmirrored
- Godot applies selfie mirror in `HandMath.landmarks_to_sample`

## Permissions

System Settings → Privacy & Security → Camera → allow **WoW Body Hand Server** (and Godot).
