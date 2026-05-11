// WizardView.swift — first-launch onboarding for Leeya.
// Single screen, scrollable form. RTL-aware Hebrew labels with English/French
// fallback. Three keys to capture: Google YouTube OAuth, Gemini, ElevenLabs.
// On submit, writes everything to Keychain and switches to MainView.

import SwiftUI

struct WizardView: View {
    /// Owner sets this to `false` once onboarding is done — flips the root view.
    @Binding var needsOnboarding: Bool

    // Form state
    @State private var geminiKey: String = ""
    @State private var elevenLabsKey: String = ""
    @State private var showSecrets: Bool = false

    // OAuth state
    @State private var googleStatus: GoogleStatus = .notSignedIn
    @State private var googleChannel: String = ""
    @State private var oauthErr: String? = nil
    @State private var oauthLog: String = ""

    @State private var saving = false

    enum GoogleStatus { case notSignedIn, inProgress, signedIn, failed }

    /// David's shared keys are NOT embedded in this binary or source.
    /// The "Use David's key" buttons fetch them at runtime from the
    /// authenticated bridge endpoint, so we can rotate without rebuilding.
    private let bridgeBase = "https://leeya-studio-bridge.vercel.app"
    private let leeyaVoiceId = "uu373LLRwhL27vnWt98R"

    @State private var fetchingDavidKey = false
    @State private var fetchingElevenKey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                header

                Divider()

                googleBlock

                Divider()

                geminiBlock

                Divider()

                elevenLabsBlock

                Divider()

                footer
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 640, height: 680)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Leeya Studio")
                .font(.system(size: 32, weight: .bold))
            Text("ברוכה הבאה. שלוש דקות הגדרה ואת מעלה shorts לבד.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("Welcome — three minutes of setup and you'll be uploading shorts on your own.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private var googleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("חשבון YouTube", systemImage: "play.tv.fill")
                .font(.system(size: 18, weight: .semibold))
            Text("לחצי כדי להתחבר לחשבון Google שלך. הסרטונים יעלו ישירות לערוץ שלך כ־Unlisted (לא ציבוריים) — את תפרסמי ידנית כשתרצי.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(action: signInGoogle) {
                    HStack(spacing: 8) {
                        Image(systemName: googleStatus == .signedIn ? "checkmark.circle.fill" : "person.crop.circle.badge.plus")
                        Text(googleStatus == .signedIn ? "מחוברת · \(googleChannel)" : "Sign in with Google")
                    }
                    .frame(minWidth: 220)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(googleStatus == .signedIn ? Color.green.opacity(0.16) : Color.accentColor.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(googleStatus == .inProgress)

                if googleStatus == .inProgress {
                    ProgressView().controlSize(.small)
                    Text("פותחת דפדפן…").font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
            if let err = oauthErr {
                Text(err).font(.system(size: 11)).foregroundColor(.red)
            }
            if !oauthLog.isEmpty {
                Text(oauthLog).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                    .lineLimit(3).truncationMode(.head)
            }
        }
    }

    @State private var geminiTestResult: GeminiTestResult = .untested
    enum GeminiTestResult { case untested, testing, ok, quota, badKey }

    private var geminiBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("מפתח Gemini (תרגום + ניתוח)", systemImage: "sparkles")
                .font(.system(size: 18, weight: .semibold))
            Text("נדרש. כדאי שתיצרי אחד **חינם משלך** ב־aistudio.google.com/app/apikey — את מקבלת 20 בקשות ביום (מספיק לסרטון אחד). אם הגעת למקסימום, חזרי מחר בבוקר.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if showSecrets {
                    TextField("AIzaSy…", text: $geminiKey)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                } else {
                    SecureField("AIzaSy…", text: $geminiKey)
                        .textFieldStyle(.roundedBorder)
                }
                Toggle("", isOn: $showSecrets).labelsHidden().toggleStyle(.checkbox)
                    .help("הצגת/הסתרת המפתח")
            }
            HStack(spacing: 10) {
                Button(fetchingDavidKey ? "טוענת…" : "Use David's key") {
                    fetchDavidKey(kind: "gemini")
                }
                .buttonStyle(.bordered)
                .disabled(fetchingDavidKey)
                Button(geminiTestResult == .testing ? "בודקת…" : "בדיקה · Test") { testGeminiKey() }
                    .buttonStyle(.bordered)
                    .disabled(geminiKey.isEmpty || geminiTestResult == .testing)
                Link("aistudio.google.com →", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                    .font(.system(size: 11))
            }
            switch geminiTestResult {
            case .untested: EmptyView()
            case .testing:  Text("שולחת בקשת בדיקה…").font(.system(size: 11)).foregroundColor(.secondary)
            case .ok:       Text("✅ מפתח עובד · ready").font(.system(size: 11)).foregroundColor(.green)
            case .quota:    Text("⚠️ הגעת למכסה היומית. נסי מחר או צרי מפתח חדש").font(.system(size: 11)).foregroundColor(.orange)
            case .badKey:   Text("❌ מפתח לא תקין").font(.system(size: 11)).foregroundColor(.red)
            }
        }
    }

    private func fetchDavidKey(kind: String) {
        if kind == "gemini" { fetchingDavidKey = true } else { fetchingElevenKey = true }
        let endpoint = "\(bridgeBase)/api/david-key?kind=\(kind)"
        Task.detached {
            let url = URL(string: endpoint)!
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let key = (json?["key"] as? String) ?? ""
                await MainActor.run {
                    if kind == "gemini" {
                        geminiKey = key
                        geminiTestResult = .untested
                        fetchingDavidKey = false
                    } else {
                        elevenLabsKey = key
                        fetchingElevenKey = false
                    }
                }
            } catch {
                await MainActor.run {
                    if kind == "gemini" { fetchingDavidKey = false } else { fetchingElevenKey = false }
                }
            }
        }
    }

    private func testGeminiKey() {
        let key = geminiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        geminiTestResult = .testing
        Task.detached {
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = #"{"contents":[{"parts":[{"text":"OK"}]}]}"#.data(using: .utf8)
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run {
                    switch code {
                    case 200: geminiTestResult = .ok
                    case 429: geminiTestResult = .quota
                    case 400, 401, 403: geminiTestResult = .badKey
                    default: geminiTestResult = .badKey
                    }
                }
            } catch {
                await MainActor.run { geminiTestResult = .badKey }
            }
        }
    }

    private var elevenLabsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("מפתח ElevenLabs · אופציונלי", systemImage: "waveform")
                .font(.system(size: 18, weight: .semibold))
            Text("רק אם את רוצה Voice-Over באנגלית עם הקול שלך משובט. אפשר לדלג — Gemini TTS חינם ייקח את התפקיד.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if showSecrets {
                    TextField("sk_…", text: $elevenLabsKey)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                } else {
                    SecureField("sk_…", text: $elevenLabsKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
            HStack(spacing: 10) {
                Button(fetchingElevenKey ? "טוענת…" : "Use David's key (קול שלך משובט)") {
                    fetchDavidKey(kind: "elevenlabs")
                }
                .buttonStyle(.bordered)
                .disabled(fetchingElevenKey)
                Button("דלגי") { elevenLabsKey = "" }
                    .buttonStyle(.bordered)
                Link("elevenlabs.io →", destination: URL(string: "https://elevenlabs.io/app/settings/api-keys")!)
                    .font(.system(size: 11))
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(action: saveAndContinue) {
                HStack(spacing: 8) {
                    if saving { ProgressView().controlSize(.small) }
                    Text(saving ? "שומרת…" : "התחילי · Start")
                }
                .padding(.horizontal, 22).padding(.vertical, 11)
                .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || saving)
        }
    }

    private var canSubmit: Bool {
        googleStatus == .signedIn && !geminiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    private func signInGoogle() {
        oauthErr = nil
        oauthLog = ""
        googleStatus = .inProgress

        Task {
            // oauth_login.py prints final {channel_id, channel_title} JSON line on success.
            let result = await PythonRunner.shared.runOneShot(scriptName: "oauth_login.py")

            await MainActor.run {
                if result.exit == 0 {
                    let lines = result.stdout.split(separator: "\n").map(String.init)
                    if let json = lines.last(where: { $0.hasPrefix("{") }),
                       let data = json.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let title = dict["channel_title"] as? String ?? "—"
                        googleChannel = title
                        Keychain.set(title, for: .youtubeChannel)
                        Keychain.set(PythonRunner.shared.youtubeTokenPath, for: .youtubeToken)
                        googleStatus = .signedIn
                    } else {
                        oauthErr = "החיבור הצליח אבל לא קיבלתי פרטי ערוץ"
                        oauthLog = result.stdout.suffix(400).description
                        googleStatus = .failed
                    }
                } else {
                    oauthErr = "החיבור נכשל. נסי שוב או פני לדוד."
                    oauthLog = (result.stderr.isEmpty ? result.stdout : result.stderr).suffix(400).description
                    googleStatus = .failed
                }
            }
        }
    }

    private func saveAndContinue() {
        saving = true
        Keychain.set(geminiKey.trimmingCharacters(in: .whitespaces), for: .geminiKey)
        if !elevenLabsKey.trimmingCharacters(in: .whitespaces).isEmpty {
            Keychain.set(elevenLabsKey.trimmingCharacters(in: .whitespaces), for: .elevenLabsKey)
            Keychain.set(leeyaVoiceId, for: .voiceId)
        }
        // Tiny delay so the user sees the spinner — feels less abrupt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            needsOnboarding = false
        }
    }
}
