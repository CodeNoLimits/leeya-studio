// MainView.swift — single-window experience after onboarding.
//   1. Drop-zone (or NSOpenPanel) for one long video.
//   2. Big "Cut & Upload" button.
//   3. Live progress strip + scrolling log.
//   4. On completion: list of clickable YouTube URLs.
//
// Style stays muted: white surface, near-black ink, accent red for CTA.
// Hebrew RTL primary text + English fallback for clarity.

import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

struct MainView: View {
    @Binding var needsOnboarding: Bool

    // Form state
    @State private var pickedVideo: URL? = nil
    @State private var pickedDuration: String = ""
    @State private var pickedSize: String = ""

    // Run state
    @State private var isRunning = false
    @State private var progressLabel: String = ""
    @State private var progressFraction: Double? = nil
    @State private var logLines: [String] = []
    @State private var uploadedURLs: [String] = []
    @State private var finalError: String? = nil

    // Drag/drop highlight
    @State private var dragHighlight = false

    var body: some View {
        VStack(spacing: 0) {

            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    dropZone
                    if pickedVideo != nil { videoMeta }
                    runButton
                    progressStrip
                    logView
                    if !uploadedURLs.isEmpty { resultsList }
                }
                .padding(24)
            }
        }
        .frame(width: 700, height: 760)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "scissors")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("Leeya Studio")
                    .font(.system(size: 18, weight: .bold))
                Text("v1.0").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
            }
            Spacer()
            if let chan = Keychain.get(.youtubeChannel), !chan.isEmpty {
                Text(chan).font(.system(size: 11)).foregroundColor(.secondary)
                Image(systemName: "play.tv").foregroundColor(.green)
            }
            Menu {
                Button("Reset onboarding") { resetOnboarding() }
                Button("Open output folder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: PythonRunner.shared.shortsDir))
                }
            } label: { Image(systemName: "gearshape") }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Color(.windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Drop zone

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(dragHighlight ? .accentColor : .secondary)
            Text("גררי וידאו ארוך לכאן · Drop a long video")
                .font(.system(size: 14, weight: .medium))
            Text("או לחצי כדי לבחור ב־Finder · Or click to choose")
                .font(.system(size: 11)).foregroundColor(.secondary)
            Text("MP4 / MOV / MKV · עד 5GB").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .background(dragHighlight ? Color.accentColor.opacity(0.08) : Color.gray.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(dragHighlight ? Color.accentColor : Color.gray.opacity(0.3),
                              style: StrokeStyle(lineWidth: 2, dash: [6,4]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { openPanel() }
        .onDrop(of: [.fileURL], isTargeted: $dragHighlight) { providers in
            providers.first?.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async { self.acceptVideo(url) }
                }
            }
            return true
        }
    }

    private var videoMeta: some View {
        HStack {
            Image(systemName: "film")
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(pickedVideo?.lastPathComponent ?? "")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Text(pickedDuration).font(.system(size: 11, design: .monospaced))
                    Text(pickedSize).font(.system(size: 11, design: .monospaced))
                }
                .foregroundColor(.secondary)
            }
            Spacer()
            Button("שני · Change") { openPanel() }.buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Run button + progress

    private var runButton: some View {
        Button(action: runPipeline) {
            HStack(spacing: 10) {
                if isRunning { ProgressView().controlSize(.small).tint(.white) }
                Text(isRunning
                     ? "מעבדת… · Cutting + uploading"
                     : "✂️  חתוך והעלה · Cut & Upload (15–30 min)")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(canRun ? Color.accentColor : Color.gray.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(!canRun)
    }

    private var progressStrip: some View {
        Group {
            if isRunning || progressLabel != "" {
                VStack(alignment: .leading, spacing: 6) {
                    if let fraction = progressFraction {
                        ProgressView(value: fraction)
                    } else {
                        ProgressView()
                    }
                    Text(progressLabel).font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
        }
    }

    private var logView: some View {
        Group {
            if !logLines.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(logLines.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.system(size: 10, design: .monospaced))
                                .foregroundColor(line.hasPrefix("❌") ? .red :
                                                  line.hasPrefix("⚠️") ? .orange : .secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .frame(height: 200)
                .background(Color.black.opacity(0.04))
                .cornerRadius(6)
            }
        }
    }

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✅  Uploaded \(uploadedURLs.count) shorts")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.green)
            ForEach(uploadedURLs, id: \.self) { url in
                if let u = URL(string: url) {
                    Link(url, destination: u).font(.system(size: 11, design: .monospaced))
                }
            }
            HStack {
                Button("פתחי YouTube Studio") {
                    NSWorkspace.shared.open(URL(string: "https://studio.youtube.com/")!)
                }.buttonStyle(.bordered)
                Button("Open output folder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: PythonRunner.shared.shortsDir))
                }.buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
    }

    private var canRun: Bool { pickedVideo != nil && !isRunning }

    // MARK: - Actions

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .quickTimeMovie, .mpeg4Movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { acceptVideo(url) }
    }

    private func acceptVideo(_ url: URL) {
        pickedVideo = url
        let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        if let size = attrs[.size] as? Int64 {
            pickedSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        // Lazy-load duration via async API (macOS 13+); show "—" until ready.
        pickedDuration = "—"
        Task {
            let asset = AVURLAsset(url: url)
            if let cm = try? await asset.load(.duration) {
                let secs = CMTimeGetSeconds(cm)
                if secs.isFinite, secs > 0 {
                    let h = Int(secs) / 3600, m = (Int(secs) % 3600) / 60, s = Int(secs) % 60
                    let str = h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                                    : String(format: "%d:%02d", m, s)
                    await MainActor.run { self.pickedDuration = str }
                }
            }
        }
    }

    private func runPipeline() {
        guard let video = pickedVideo else { return }
        isRunning = true
        progressFraction = nil
        progressLabel = "מתחילה…"
        logLines.removeAll()
        uploadedURLs.removeAll()
        finalError = nil

        let args = [
            "--video", video.path,
            "--shorts", "5",
            "--lang", "EN",
            "--upload",
            "--privacy", "unlisted",
        ]

        PythonRunner.shared.runStreaming(
            scriptName: "orchestrator.py",
            args: args,
            onEvent: { evt in
                handle(evt)
            },
            onLog: { line in
                logLines.append(line)
                if logLines.count > 500 { logLines.removeFirst(100) }
            },
            onDone: { code in
                isRunning = false
                if code == 0 {
                    progressLabel = "✓ הסתיים · Done"
                    progressFraction = 1.0
                } else {
                    progressLabel = "❌ נכשל · Failed (code \(code))"
                    finalError = "Pipeline exited with code \(code)"
                }
            }
        )
    }

    private func handle(_ evt: PyEvent) {
        switch evt.event {
        case "started":
            progressLabel = "התחלה · Started"
        case "progress":
            if let label = evt.label { progressLabel = label }
            if let cur = evt.current, let tot = evt.total, tot > 0 {
                progressFraction = cur / tot
            }
        case "upload_done":
            if let url = evt.url { uploadedURLs.append(url) }
        case "error":
            finalError = evt.error
            logLines.append("❌ " + (evt.error ?? "unknown"))
        case "done":
            progressFraction = 1.0
            progressLabel = "✓ הכל הועלה · All uploaded"
        default:
            if let label = evt.label { progressLabel = label }
        }
    }

    private func resetOnboarding() {
        Keychain.wipe()
        needsOnboarding = true
    }
}

