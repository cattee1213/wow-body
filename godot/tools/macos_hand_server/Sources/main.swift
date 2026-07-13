import AVFoundation
import CoreMedia
import Foundation
import Network
import Vision

/// Streams Apple Vision hand landmarks (MediaPipe-compatible 21 points) as NDJSON over TCP.
/// Protocol (one JSON object per line):
///   {"t":1234.5,"ok":true,"frames":12,"hands":[{"side":"Right","conf":0.92,"pts":[[x,y,c], ... 21]}]}
/// Coordinates: normalized image space, origin top-left, x→right, y→down (unmirrored).
/// Godot applies selfie mirror via HandMath.landmarks_to_sample(mirror_x: true).

let defaultPort: UInt16 = 17452

// MediaPipe / project joint order
let jointOrder: [VNHumanHandPoseObservation.JointName] = [
    .wrist,
    .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
    .indexMCP, .indexPIP, .indexDIP, .indexTip,
    .middleMCP, .middlePIP, .middleDIP, .middleTip,
    .ringMCP, .ringPIP, .ringDIP, .ringTip,
    .littleMCP, .littlePIP, .littleDIP, .littleTip,
]

final class HandPipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "wowbody.hand.session")
    private let visionQueue = DispatchQueue(label: "wowbody.hand.vision", qos: .userInitiated)
    private let lock = NSLock()
    private var latestJSONLine: String = #"{"t":0,"ok":true,"frames":0,"hands":[]}"# + "\n"
    private var frameIndex: Int = 0
    private var lastLogFrames: Int = 0
    private var isProcessing = false

    func start() throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let sem = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .video) { ok in
                granted = ok
                sem.signal()
            }
            _ = sem.wait(timeout: .now() + 30)
            if !granted {
                throw PipelineError.cameraDenied
            }
        default:
            throw PipelineError.cameraDenied
        }

        guard let device = Self.pickCamera() else {
            throw PipelineError.noCamera
        }

        let sem = DispatchSemaphore(value: 0)
        var configError: Error?
        sessionQueue.async {
            do {
                try self.configureSession(device: device)
            } catch {
                configError = error
            }
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 10)
        if let configError {
            throw configError
        }

        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
            fputs(
                "[macos_hand_server] camera running: \(device.localizedName) isRunning=\(self.session.isRunning)\n",
                stderr
            )
        }
    }

    private func configureSession(device: AVCaptureDevice) throws {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        } else {
            session.sessionPreset = .medium
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw PipelineError.noCamera
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        ]
        output.setSampleBufferDelegate(self, queue: visionQueue)
        guard session.canAddOutput(output) else {
            throw PipelineError.noCamera
        }
        session.addOutput(output)

        if let conn = output.connection(with: .video) {
            if conn.isVideoMirroringSupported {
                conn.automaticallyAdjustsVideoMirroring = false
                conn.isVideoMirrored = false
            }
            conn.isEnabled = true
        }

        session.commitConfiguration()
    }

    func currentLine() -> String {
        lock.lock()
        defer { lock.unlock() }
        return latestJSONLine
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Drop if still processing previous frame (keep latency low).
        if isProcessing { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        isProcessing = true
        defer { isProcessing = false }

        frameIndex += 1
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        // Mac webcam buffers are typically upright landscape.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            let observations = request.results ?? []
            let hands: [[String: Any]] = observations.compactMap { encodeHand($0) }
            let t = Date().timeIntervalSince1970 * 1000.0
            let payload: [String: Any] = [
                "t": t,
                "ok": true,
                "frames": frameIndex,
                "hands": hands,
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
               var line = String(data: data, encoding: .utf8)
            {
                line.append("\n")
                lock.lock()
                latestJSONLine = line
                lock.unlock()
            }
            if frameIndex - lastLogFrames >= 60 {
                lastLogFrames = frameIndex
                fputs("[macos_hand_server] frames=\(frameIndex) hands=\(hands.count)\n", stderr)
            }
        } catch {
            fputs("[macos_hand_server] vision error: \(error)\n", stderr)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // ignore drops
    }

    private func encodeHand(_ obs: VNHumanHandPoseObservation) -> [String: Any]? {
        let points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]
        do {
            points = try obs.recognizedPoints(.all)
        } catch {
            return nil
        }

        var pts: [[Double]] = []
        pts.reserveCapacity(21)
        var confSum = 0.0
        var confCount = 0.0
        for name in jointOrder {
            if let p = points[name], p.confidence > 0.05 {
                // Vision normalized coords: origin lower-left → flip Y for top-left.
                let x = Double(p.location.x)
                let y = Double(1.0 - p.location.y)
                let c = Double(p.confidence)
                pts.append([
                    min(1.0, max(0.0, x)),
                    min(1.0, max(0.0, y)),
                    c,
                ])
                confSum += c
                confCount += 1
            } else {
                // conf=0 → Godot skips draw / fills from palm (never use fake screen corner).
                pts.append([-1.0, -1.0, 0.0])
            }
        }
        if confCount < 6 {
            return nil
        }

        let side: String
        if #available(macOS 14.0, *) {
            switch obs.chirality {
            case .left: side = "Left"
            case .right: side = "Right"
            default: side = "Unknown"
            }
        } else {
            side = "Unknown"
        }

        return [
            "side": side,
            "conf": confSum / max(confCount, 1.0),
            "pts": pts,
        ]
    }

    private static func pickCamera() -> AVCaptureDevice? {
        var types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
        ]
        if #available(macOS 14.0, *) {
            types.append(.continuityCamera)
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        let devices = discovery.devices
        if let front = devices.first(where: { $0.position == .front }) {
            return front
        }
        return devices.first ?? AVCaptureDevice.default(for: .video)
    }
}

enum PipelineError: Error {
    case noCamera
    case cameraDenied
}

final class BroadcastServer {
    private let port: UInt16
    private let pipeline: HandPipeline
    private var listener: NWListener?
    private let clientQueue = DispatchQueue(label: "wowbody.hand.clients")
    private var clients: [NWConnection] = []
    private var pushTimer: DispatchSourceTimer?

    init(port: UInt16, pipeline: HandPipeline) {
        self.port = port
        self.pipeline = pipeline
    }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener?.newConnectionHandler = { [weak self] conn in
            self?.accept(conn)
        }
        listener?.stateUpdateHandler = { state in
            if case let .failed(err) = state {
                fputs("[macos_hand_server] listener failed: \(err)\n", stderr)
            }
        }
        listener?.start(queue: .global(qos: .userInitiated))
        fputs("[macos_hand_server] listening on 127.0.0.1:\(port)\n", stderr)

        let timer = DispatchSource.makeTimerSource(queue: clientQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(33))
        timer.setEventHandler { [weak self] in
            self?.pushFrame()
        }
        timer.resume()
        pushTimer = timer
    }

    private func accept(_ conn: NWConnection) {
        conn.start(queue: clientQueue)
        clientQueue.async {
            self.clients.append(conn)
            fputs("[macos_hand_server] client connected (n=\(self.clients.count))\n", stderr)
            let hello = #"{"t":0,"ok":true,"hello":true,"frames":0,"hands":[]}"# + "\n"
            conn.send(content: hello.data(using: .utf8), completion: .contentProcessed { _ in })
        }
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.drop(conn)
            default:
                break
            }
        }
    }

    private func drop(_ conn: NWConnection) {
        clientQueue.async {
            self.clients.removeAll { $0 === conn }
            conn.cancel()
            fputs("[macos_hand_server] client gone (n=\(self.clients.count))\n", stderr)
        }
    }

    private func pushFrame() {
        let line = pipeline.currentLine()
        guard let data = line.data(using: .utf8) else { return }
        let snapshot = clients
        for conn in snapshot {
            conn.send(content: data, completion: .contentProcessed { err in
                if err != nil {
                    self.drop(conn)
                }
            })
        }
    }
}

// MARK: - main

let args = CommandLine.arguments
var port = defaultPort
if let idx = args.firstIndex(of: "--port"), idx + 1 < args.count, let p = UInt16(args[idx + 1]) {
    port = p
}

fputs("[macos_hand_server] starting Vision hand pose (port \(port))\n", stderr)

let pipeline = HandPipeline()
do {
    try pipeline.start()
} catch PipelineError.cameraDenied {
    fputs(
        "[macos_hand_server] ERROR: camera permission denied. Enable in System Settings → Privacy → Camera.\n",
        stderr
    )
    exit(2)
} catch {
    fputs("[macos_hand_server] ERROR: \(error)\n", stderr)
    exit(1)
}

let server = BroadcastServer(port: port, pipeline: pipeline)
do {
    try server.start()
} catch {
    fputs("[macos_hand_server] ERROR bind: \(error)\n", stderr)
    exit(1)
}

RunLoop.main.run()
