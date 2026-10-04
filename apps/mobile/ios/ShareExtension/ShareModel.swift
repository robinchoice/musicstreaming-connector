import Foundation
import Combine

struct SourceTrack: Decodable {
    let title: String
    let artist: String
    let url: String
}

struct SongCandidate: Decodable {
    let title: String
    let url: String
    let artworkUrl: String?
    let album: String?
    let durationSeconds: Int?
}

struct Conversion: Decodable {
    let target: String
    let source: SourceTrack
    let candidates: [SongCandidate]
}

private struct APIError: Decodable {
    let error: String
    let code: String?
    let searchUrl: String?
}

@MainActor
final class ShareModel: ObservableObject {
    static let platforms = ["appleMusic": "Apple Music", "youtubeMusic": "YouTube Music", "spotify": "Spotify"]
    private let preferences = UserDefaults(suiteName: "group.org.musiclink.prototype")
    @Published var target = "appleMusic"
    var targetName: String { Self.platforms[conversion?.target ?? target] ?? target }
    var targets: [String] { Self.targets(for: input ?? "") }
    private let country: String = {
        let region = Locale.current.region?.identifier ?? ""
        return ["DE", "AT", "CH", "US", "GB"].contains(region) ? region : "DE"
    }()

    init() {
        if let saved = preferences?.string(forKey: "target"), Self.platforms[saved] != nil { target = saved }
    }

    static func targets(for input: String) -> [String] {
        if input.contains("music.apple.com/") { return ["youtubeMusic"] }
        if input.contains("youtube.com/") || input.contains("youtu.be/") { return ["appleMusic", "spotify"] }
        return ["appleMusic", "youtubeMusic", "spotify"]
    }

    func targetChanged() {
        preferences?.set(target, forKey: "target")
        retry()
    }

    @Published private(set) var conversion: Conversion?
    @Published private(set) var error: String?
    @Published private(set) var searchUrl: String?
    @Published private(set) var isLoading = true
    @Published private(set) var canRetry = false
    @Published var selection: String?

    private var request: Task<Void, Never>?
    private var input: String?
    private var isClosed = false

    private var apiURL: URL? {
        let defines = Bundle.main.object(forInfoDictionaryKey: "MusicLinkDartDefines") as? String ?? ""
        for encoded in defines.split(separator: ",") {
            guard let data = Data(base64Encoded: String(encoded)),
                  let value = String(data: data, encoding: .utf8),
                  value.hasPrefix("API_URL=") else { continue }
            guard let url = URL(string: String(value.dropFirst(8))), url.host != nil else { return nil }
            #if DEBUG
            guard ["http", "https"].contains(url.scheme ?? "") else { return nil }
            #else
            guard url.scheme == "https" else { return nil }
            #endif
            return url
        }
        #if DEBUG
        return URL(string: "http://localhost:3000")
        #else
        return nil
        #endif
    }

    func resolve(_ input: String) {
        guard !isClosed else { return }
        if self.input == nil {
            let targets = Self.targets(for: input)
            if !targets.contains(target) { target = targets[0] }
        }
        self.input = input
        request?.cancel()
        conversion = nil
        selection = nil
        error = nil
        searchUrl = nil
        canRetry = false
        isLoading = true
        guard let apiURL else {
            isLoading = false
            error = "Die Server-Adresse fehlt in dieser App-Version."
            return
        }
        let target = self.target
        let country = self.country
        request = Task { [weak self] in
            do {
                var request = URLRequest(url: apiURL.appendingPathComponent("api/v1/convert"))
                request.httpMethod = "POST"
                request.timeoutInterval = 25
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(["input": input, "target": target, "country": country])
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let self, !self.isClosed, !Task.isCancelled else { return }
                self.isLoading = false
                guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                if response.statusCode >= 400 {
                    let failure = try JSONDecoder().decode(APIError.self, from: data)
                    self.error = failure.error
                    self.searchUrl = failure.searchUrl
                    self.canRetry = response.statusCode == 429 || response.statusCode >= 500
                } else {
                    let conversion = try JSONDecoder().decode(Conversion.self, from: data)
                    self.conversion = conversion
                    self.selection = conversion.candidates.first?.url
                }
            } catch {
                guard let self, !self.isClosed, !Task.isCancelled else { return }
                self.isLoading = false
                self.error = "Der Dienst ist gerade nicht erreichbar. Prüfe deine Verbindung und versuche es erneut."
                self.canRetry = true
            }
        }
    }

    func failToReadInput() {
        isLoading = false
        error = "Der geteilte Link konnte nicht gelesen werden. Teile einen Song aus YouTube Music oder Apple Music erneut."
    }

    func retry() {
        if let input { resolve(input) }
    }

    func close() {
        isClosed = true
        request?.cancel()
    }

    deinit {
        request?.cancel()
    }
}
