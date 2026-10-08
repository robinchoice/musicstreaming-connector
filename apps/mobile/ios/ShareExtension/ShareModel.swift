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

struct SongLink: Decodable {
    let url: String
    let found: Bool
}

struct Song: Decodable {
    let source: SourceTrack
    let sharePath: String
    let links: [String: SongLink]
}

// Written by the app (Flutter) as JSON into the app group, see lib/features/friends/social.dart
struct Friend: Codable, Hashable {
    let name: String
    let platform: String
}

struct FriendGroup: Codable, Hashable {
    let name: String
    let members: [String]
}

private struct Social: Decodable {
    let friends: [Friend]?
    let groups: [FriendGroup]?
}

private struct APIError: Decodable {
    let error: String
    let code: String?
    let searchUrl: String?
}

@MainActor
final class ShareModel: ObservableObject {
    static let platforms = ["appleMusic": "Apple Music", "youtubeMusic": "YouTube Music", "spotify": "Spotify", "deezer": "Deezer"]
    private let preferences = UserDefaults(suiteName: "group.org.musiclink.prototype")
    @Published var target = "appleMusic"
    var targetName: String { Self.platforms[conversion?.target ?? target] ?? target }
    var targets: [String] { Self.targets(for: input ?? "") }
    private let country: String = {
        let region = Locale.current.region?.identifier ?? ""
        return ["DE", "AT", "CH", "US", "GB"].contains(region) ? region : "DE"
    }()

    let friends: [Friend]
    let groups: [FriendGroup]
    @Published private(set) var chosen: [String] = []
    @Published private(set) var message: String?
    @Published private(set) var isLoadingMessage = false
    @Published private(set) var messageFailed = false
    private var song: Song?
    private var songRequest: Task<Void, Never>?

    init() {
        if let saved = preferences?.string(forKey: "target"), Self.platforms[saved] != nil { target = saved }
        let social = preferences?.string(forKey: "social")
            .flatMap { try? JSONDecoder().decode(Social.self, from: Data($0.utf8)) }
        friends = (social?.friends ?? []).filter { Self.platforms[$0.platform] != nil }
        groups = social?.groups ?? []
    }

    func toggle(_ name: String) {
        choose(chosen.contains(name) ? chosen.filter { $0 != name } : chosen + [name])
    }

    func isGroupChosen(_ group: FriendGroup) -> Bool {
        Set(group.members) == Set(chosen) && !chosen.isEmpty
    }

    func toggle(group: FriendGroup) {
        choose(isGroupChosen(group) ? [] : group.members.filter { member in friends.contains { $0.name == member } })
    }

    private func choose(_ names: [String]) {
        chosen = names
        message = nil
        messageFailed = false
        guard !names.isEmpty else { return }
        if song != nil { buildMessage(); return }
        guard let apiURL, let input, songRequest == nil else { return }
        isLoadingMessage = true
        let country = self.country
        songRequest = Task { [weak self] in
            var components = URLComponents(url: apiURL.appendingPathComponent("api/v1/song"), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "input", value: input), URLQueryItem(name: "country", value: country)]
            var song: Song?
            if let url = components?.url {
                var request = URLRequest(url: url)
                request.timeoutInterval = 25
                if let result = try? await URLSession.shared.data(for: request),
                   (result.1 as? HTTPURLResponse)?.statusCode == 200 {
                    song = try? JSONDecoder().decode(Song.self, from: result.0)
                }
            }
            guard let self, !self.isClosed, !Task.isCancelled else { return }
            self.songRequest = nil
            self.isLoadingMessage = false
            self.song = song
            if song == nil {
                self.chosen = []
                self.messageFailed = true
            }
            self.buildMessage()
        }
    }

    // One link if everyone uses the same service, otherwise one line per service plus the share page
    private func buildMessage() {
        guard let song, let apiURL else { return }
        let picked = friends.filter { chosen.contains($0.name) }
        guard !picked.isEmpty else { message = nil; return }
        let head = "🎵 \(song.source.title) – \(song.source.artist)"
        var services: [String] = []
        for friend in picked where !services.contains(friend.platform) { services.append(friend.platform) }
        if services.count == 1 {
            message = "\(head)\n\(song.links[services[0]]?.url ?? "")"
            return
        }
        var lines = [head]
        for service in services {
            let names = picked.filter { $0.platform == service }.map(\.name).joined(separator: ", ")
            lines.append("\(Self.platforms[service] ?? service) (\(names)): \(song.links[service]?.url ?? "")")
        }
        let origin = apiURL.absoluteString.hasSuffix("/") ? String(apiURL.absoluteString.dropLast()) : apiURL.absoluteString
        lines.append("Andere: \(origin)\(song.sharePath)")
        message = lines.joined(separator: "\n")
    }

    static func targets(for input: String) -> [String] {
        let source = input.contains("music.apple.com/") ? "appleMusic"
            : input.contains("youtube.com/") || input.contains("youtu.be/") ? "youtubeMusic"
            : input.contains("open.spotify.com/") ? "spotify"
            : input.contains("deezer.com/") ? "deezer" : nil
        return ["appleMusic", "youtubeMusic", "spotify", "deezer"].filter { $0 != source }
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
        songRequest?.cancel()
        songRequest = nil
        song = nil
        chosen = []
        message = nil
        isLoadingMessage = false
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
        songRequest?.cancel()
    }

    deinit {
        request?.cancel()
        songRequest?.cancel()
    }
}
