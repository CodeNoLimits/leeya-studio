// PythonRunner.swift — locates bundled Python 3.11, sets PYTHONPATH/PATH for
// embedded leecut + ffmpeg + whisper, then runs scripts and streams JSONL
// status events back to SwiftUI views.

import Foundation
import AppKit

/// One status event emitted by an orchestrator script.
/// Wire format = newline-delimited JSON, e.g.
///   {"event":"progress","step":"transcribe","current":1,"total":10,"label":"Transcribing audio…"}
struct PyEvent: Decodable {
    let event: String
    var step: String?
    var current: Double?
    var total: Double?
    var label: String?
    var file: String?
    var url: String?
    var detail: String?
    var error: String?
}

/// Tool that runs a Python script bundled inside Leeya Studio.app.
/// Inherits keychain-loaded API keys + bundled binary paths through env vars.
final class PythonRunner {
    static let shared = PythonRunner()
    private init() {}

    private var task: Process?

    // MARK: - Resource lookup

    /// Path to the bundled Python 3.11 interpreter, e.g.
    /// /Applications/Leeya Studio.app/Contents/Resources/python/bin/python3
    private var pythonExe: String {
        guard let res = Bundle.main.resourcePath else { fatalError("No bundle resources") }
        return "\(res)/python/bin/python3"
    }

    /// Directory holding the bundled site-packages (google-api-client, etc.)
    private var sitePackages: String {
        guard let res = Bundle.main.resourcePath else { fatalError() }
        return "\(res)/site-packages"
    }

    /// Directory containing leecut.* + orchestrator.py + upload_single_video.py + oauth_login.py
    private var pyScriptsDir: String {
        guard let res = Bundle.main.resourcePath else { fatalError() }
        return "\(res)/scripts"
    }

    /// Path to bundled ffmpeg static binary
    private var ffmpegBin: String {
        guard let res = Bundle.main.resourcePath else { fatalError() }
        return "\(res)/bin/ffmpeg"
    }

    /// Path to bundled OAuth client_secret.json
    var clientSecretPath: String {
        guard let res = Bundle.main.resourcePath else { fatalError() }
        return "\(res)/client_secret.json"
    }

    /// Persistent app-support directory for tokens, output videos, logs.
    var appSupportDir: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LeeyaStudio", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// Where the YouTube OAuth refresh token is cached.
    var youtubeTokenPath: String {
        appSupportDir.appendingPathComponent("youtube_token.json").path
    }

    /// Where pipeline intermediate state lives.
    var pipelineDir: String {
        let p = appSupportDir.appendingPathComponent("pipeline", isDirectory: true)
        try? FileManager.default.createDirectory(at: p, withIntermediateDirectories: true)
        return p.path
    }

    /// Where final shorts (.mp4) land.
    var shortsDir: String {
        let p = appSupportDir.appendingPathComponent("shorts", isDirectory: true)
        try? FileManager.default.createDirectory(at: p, withIntermediateDirectories: true)
        return p.path
    }

    // MARK: - Env composition

    /// Build the environment variables for a Python child process.
    /// - Loads all relevant keys from Keychain into env vars
    /// - Sets PYTHONPATH so `import leecut` works from the bundle
    /// - Prepends ./bin to PATH so subprocess ffmpeg calls resolve to bundle
    private func childEnv() -> [String: String] {
        var env = ProcessInfo.processInfo.environment

        // Bundled resources
        let resPath = Bundle.main.resourcePath!
        env["PYTHONPATH"] = "\(sitePackages):\(pyScriptsDir):\(pyScriptsDir)/leecut"
        // PATH must include python/bin (for mlx_whisper CLI) + Resources/bin (for ffmpeg)
        env["PATH"] = "\(resPath)/bin:\(resPath)/python/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
        env["PYTHONUNBUFFERED"] = "1"  // critical: force line-buffered stdout for streaming
        env["PYTHONDONTWRITEBYTECODE"] = "1"

        // leecut bundled overrides
        env["LEEYA_FFMPEG"] = ffmpegBin
        env["LEEYA_PIPELINE_DIR"] = pipelineDir
        env["LEEYA_SHORTS_DIR"] = shortsDir
        env["LEEYA_WHISPER_MODEL"] = "mlx-community/whisper-tiny-mlx"  // ~150 MB first-run download

        // Secrets — pulled from Keychain
        if let g = Keychain.get(.geminiKey) { env["GEMINI_API_KEY"] = g }
        if let e = Keychain.get(.elevenLabsKey) { env["ELEVENLABS_API_KEY"] = e }
        if let v = Keychain.get(.voiceId) ?? "uu373LLRwhL27vnWt98R" as String? {
            env["ELEVENLABS_VOICE_ID"] = v
        }

        // YouTube
        env["YOUTUBE_TOKEN_PATH"] = youtubeTokenPath
        env["YOUTUBE_CLIENT_SECRET"] = clientSecretPath

        return env
    }

    // MARK: - Public API

    /// Run an arbitrary script with one shot: returns final exit code + accumulated lines.
    /// Used for short OAuth login (~10s) where we don't need live streaming.
    @discardableResult
    func runOneShot(scriptName: String, args: [String] = []) async -> (exit: Int32, stdout: String, stderr: String) {
        await withCheckedContinuation { (cont: CheckedContinuation<(Int32, String, String), Never>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: pythonExe)
            p.arguments = ["\(pyScriptsDir)/\(scriptName)"] + args
            p.environment = childEnv()
            let outPipe = Pipe(), errPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe

            p.terminationHandler = { proc in
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let outStr = String(data: outData, encoding: .utf8) ?? ""
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                cont.resume(returning: (proc.terminationStatus, outStr, errStr))
            }

            do {
                try p.run()
            } catch {
                cont.resume(returning: (-1, "", "Failed to launch: \(error)"))
            }
        }
    }

    /// Stream a long-running script: parses each stdout line as JSON event,
    /// invokes `onEvent` on the main queue, and `onDone` with the final exit code.
    func runStreaming(
        scriptName: String,
        args: [String] = [],
        onEvent: @escaping (PyEvent) -> Void,
        onLog:   @escaping (String) -> Void,
        onDone:  @escaping (Int32) -> Void
    ) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: pythonExe)
        p.arguments = ["\(pyScriptsDir)/\(scriptName)"] + args
        p.environment = childEnv()
        let outPipe = Pipe(), errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe

        var carry = Data()
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            carry.append(data)
            while let nl = carry.firstIndex(of: 0x0A) {
                let lineData = carry.subdata(in: 0..<nl)
                carry.removeSubrange(0...nl)
                guard let line = String(data: lineData, encoding: .utf8) else { continue }
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                if trimmed.hasPrefix("{") {
                    if let evt = try? JSONDecoder().decode(PyEvent.self, from: Data(trimmed.utf8)) {
                        DispatchQueue.main.async { onEvent(evt) }
                        continue
                    }
                }
                DispatchQueue.main.async { onLog(trimmed) }
            }
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            for line in s.split(separator: "\n") {
                DispatchQueue.main.async { onLog("⚠️ " + String(line)) }
            }
        }
        p.terminationHandler = { proc in
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { onDone(proc.terminationStatus) }
        }

        do {
            try p.run()
            self.task = p
        } catch {
            DispatchQueue.main.async {
                onLog("❌ Failed to launch python: \(error)")
                onDone(-1)
            }
        }
    }

    func cancel() {
        task?.terminate()
        task = nil
    }
}
