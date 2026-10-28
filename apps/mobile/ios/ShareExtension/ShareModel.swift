import Foundation
import Combine

struct SongSource: Decodable {
    let kind: String
    let platform: String
    let title: String
    let artist: String
    let url: String
    let artworkUrl: String?
}

struct SongLink: Decodable {
    let url: String
    let found: Bool
}

struct Song: Decodable {
    let source: SongSource
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
    let me: Friend?
}

private struct APIError: Decodable {
    let error: String
}

// Every text the extension shows, in German and English like lib/core/messages.dart in the app
struct ShareTexts {
    let code: String
    let searching: String
    let retry: String
    let close: String
    let done: String
    let handy: String
    let guide: String
    let toWhom: String
    let friendsTip: String
    let everyone: String
    let hintEveryone: String
    let hintSeveral: String
    let share: String
    let copy: String
    let copied: String
    let searchOnly: String
    let source: String
    let found: String
    let allServices: String
    let others: String
    let sharedWith: String
    let missingServer: String
    let unreachable: String
    let unreadable: String

    static let de = ShareTexts(
        code: "de",
        searching: "Links für alle Dienste suchen …",
        retry: "Erneut versuchen",
        close: "Schließen",
        done: "Fertig",
        handy: "Songgate griffbereit",
        guide: "Im Teilen-Menü: Mehr → Bearbeiten → Plus bei Songgate. Ziehe Songgate über den Griff nach oben und tippe auf Fertig.",
        toWhom: "An wen?",
        friendsTip: "Tipp: In der Songgate-App speicherst du Freunde mit ihrem Dienst. Dann bekommt jeder den Link für seinen Player.",
        everyone: "Alle",
        hintEveryone: "Ein Link für alle. Jede und jeder wählt den eigenen Dienst, ideal für Gruppenchats.",
        hintSeveral: "Eine Zeile pro Dienst, für alle anderen der Link für alle.",
        share: "Teilen",
        copy: "Kopieren",
        copied: "Kopiert ✓",
        searchOnly: "Nur Suche",
        source: "Quelle",
        found: "Gefunden",
        allServices: "Alle Dienste",
        others: "Andere",
        sharedWith: "Geteilt mit",
        missingServer: "Die Server-Adresse fehlt in dieser App-Version.",
        unreachable: "Der Dienst ist gerade nicht erreichbar. Prüfe deine Verbindung und versuche es erneut.",
        unreadable: "Der geteilte Link konnte nicht gelesen werden. Teile einen Song oder ein Album aus YouTube Music, Apple Music, Spotify oder Deezer erneut."
    )

    static let en = ShareTexts(
        code: "en",
        searching: "Looking for links on every service …",
        retry: "Try again",
        close: "Close",
        done: "Done",
        handy: "Keep Songgate handy",
        guide: "In the share menu: More → Edit → plus next to Songgate. Drag Songgate up by its handle and tap Done.",
        toWhom: "Who’s it for?",
        friendsTip: "Tip: save friends with their service in the Songgate app. Then everyone gets the link for their own player.",
        everyone: "Everyone",
        hintEveryone: "One link for everyone. Each person picks their own service, ideal for group chats.",
        hintSeveral: "One line per service, and the link for everyone for all the others.",
        share: "Share",
        copy: "Copy",
        copied: "Copied ✓",
        searchOnly: "Search only",
        source: "Source",
        found: "Found",
        allServices: "All services",
        others: "Others",
        sharedWith: "Shared with",
        missingServer: "This version of the app is missing the server address.",
        unreachable: "The service can’t be reached right now. Check your connection and try again.",
        unreadable: "The shared link couldn’t be read. Share a song or album from YouTube Music, Apple Music, Spotify or Deezer again."
    )

    func kindFrom(_ album: Bool, _ service: String) -> String {
        let kind = album ? "Album" : "Song"
        return code == "en" ? "\(kind) from \(service)" : "\(kind) aus \(service)"
    }

    func hintOne(_ service: String, _ withName: Bool) -> String {
        code == "en"
            ? "Direct link for \(service)\(withName ? ", plus the link for everyone with your name" : "")."
            : "Direktlink für \(service)\(withName ? ", dazu der Link für alle mit deinem Namen" : "")."
    }

    // The language chosen in the app, else the first device language we speak, else German
    static func pick(saved: String?, preferred: [String]) -> ShareTexts {
        for code in [saved].compactMap({ $0 }) + preferred.map({ String($0.prefix(2)).lowercased() }) {
            if code == "de" { return .de }
            if code == "en" { return .en }
        }
        return .de
    }
}

@MainActor
final class ShareModel: ObservableObject {
    static let platforms = ["appleMusic": "Apple Music", "youtubeMusic": "YouTube Music", "spotify": "Spotify", "deezer": "Deezer"]
    static let serviceOrder = ["spotify", "appleMusic", "youtubeMusic", "deezer"]
    private let preferences = UserDefaults(suiteName: "group.org.musiclink.prototype")
    private let country: String = {
        let region = Locale.current.region?.identifier ?? ""
        return ["DE", "AT", "CH", "US", "GB"].contains(region) ? region : "DE"
    }()

    let friends: [Friend]
    let groups: [FriendGroup]
    let me: Friend?
    let t: ShareTexts
    @Published private(set) var song: Song?
    @Published private(set) var error: String?
    @Published private(set) var isLoading = true
    @Published private(set) var canRetry = false
    // Picking friends picks their services, the tiles change the services on their own
    @Published private(set) var chosen: [String] = []
    @Published private(set) var services: [String] = []

    private var request: Task<Void, Never>?
    private(set) var input: String?
    private var isClosed = false

    init() {
        let social = preferences?.string(forKey: "social")
            .flatMap { try? JSONDecoder().decode(Social.self, from: Data($0.utf8)) }
        friends = (social?.friends ?? []).filter { !$0.name.isEmpty && Self.platforms[$0.platform] != nil }
        groups = social?.groups ?? []
        me = social?.me.flatMap { Self.platforms[$0.platform] == nil ? nil : $0 }
        t = ShareTexts.pick(saved: preferences?.string(forKey: "locale"), preferred: Locale.preferredLanguages)
    }

    func pick(_ names: [String]) {
        chosen = names
        services = Self.serviceOrder.filter { platform in
            friends.contains { names.contains($0.name) && $0.platform == platform }
        }
    }

    func toggle(_ name: String) {
        pick(chosen.contains(name) ? chosen.filter { $0 != name } : chosen + [name])
    }

    func isGroupChosen(_ group: FriendGroup) -> Bool {
        Set(group.members) == Set(chosen) && !chosen.isEmpty
    }

    func toggle(group: FriendGroup) {
        pick(isGroupChosen(group) ? [] : group.members.filter { member in friends.contains { $0.name == member } })
    }

    func toggle(service: String) {
        let next = services.contains(service) ? services.filter { $0 != service } : services + [service]
        services = Self.serviceOrder.filter(next.contains)
        // No service left means everyone again
        if services.isEmpty { chosen = [] }
    }

    // Small text on a tile, the same as _tileDetail in the app
    func detail(_ platform: String) -> String {
        guard let song, song.links[platform]?.found == true else { return t.searchOnly }
        let names = friends.filter { chosen.contains($0.name) && $0.platform == platform }.map(\.name)
        if !names.isEmpty { return names.joined(separator: ", ") }
        return platform == song.source.platform ? t.source : t.found
    }

    var message: String? {
        guard let song, let apiURL else { return nil }
        let origin = apiURL.absoluteString.hasSuffix("/") ? String(apiURL.absoluteString.dropLast()) : apiURL.absoluteString
        return Self.friendsMessage(song, friends: friends.filter { chosen.contains($0.name) }, origin: origin, from: me, services: services, t: t)
    }

    // Same as friendsMessage in packages/shared: no service gives the share page only,
    // one its link, several one line each plus the share page for everyone else.
    static func friendsMessage(_ song: Song, friends: [Friend], origin: String, from: Friend?, services: [String], t: ShareTexts = .de) -> String {
        let head = "\(song.source.kind == "album" ? "💿" : "🎵") \(song.source.title) – \(song.source.artist)"
        let everyone = shareURL(origin + song.sharePath, from: from)
        // Every message ends with where it was made, so recipients find Songgate too
        let footer = "\n\n\(t.sharedWith) \(origin.replacingOccurrences(of: "^https?://", with: "", options: .regularExpression))"
        guard let first = services.first else { return [head, everyone].joined(separator: "\n") + footer }
        if services.count == 1 {
            return ([head, song.links[first]?.url ?? ""] + (from == nil ? [] : ["\(t.allServices): \(everyone)"])).joined(separator: "\n") + footer
        }
        let lines = services.map { platform in
            let names = friends.filter { $0.platform == platform }.map(\.name).joined(separator: ", ")
            return "\(platforms[platform] ?? platform)\(names.isEmpty ? "" : " (\(names))"): \(song.links[platform]?.url ?? "")"
        }
        return ([head] + lines + ["\(t.others): \(everyone)"]).joined(separator: "\n") + footer
    }

    // A share page may name its sender, same as shareUrl in packages/shared
    static let inviteSlugs = ["appleMusic": "apple", "youtubeMusic": "youtube", "spotify": "spotify", "deezer": "deezer"]
    static func shareURL(_ url: String, from: Friend?) -> String {
        guard let from, let slug = inviteSlugs[from.platform], var components = URLComponents(string: url) else { return url }
        components.queryItems = [URLQueryItem(name: "from", value: from.name), URLQueryItem(name: "service", value: slug)]
        // URLComponents keeps "+", which the web reads as a space
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.string ?? url
    }

    // The service a shared link comes from, before the API has looked at it
    static func sourceOf(_ input: String) -> String? {
        input.contains("music.apple.com/") ? "appleMusic"
            : input.contains("youtube.com/") || input.contains("youtu.be/") ? "youtubeMusic"
            : input.contains("open.spotify.com/") || input.contains("spotify.link/") ? "spotify"
            : input.contains("deezer.com/") ? "deezer" : nil
    }

    // Lets the API ask outdated builds to update (status 426), see apps/api/src/app.ts
    // and to answer errors in our language
    private static func identify(_ request: inout URLRequest, language: String) {
        request.setValue(language, forHTTPHeaderField: "Accept-Language")
        request.setValue("ios", forHTTPHeaderField: "X-App-Platform")
        request.setValue(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String, forHTTPHeaderField: "X-App-Build")
    }

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
        self.input = input
        request?.cancel()
        song = nil
        error = nil
        canRetry = false
        isLoading = true
        guard let apiURL else {
            isLoading = false
            error = t.missingServer
            return
        }
        let country = self.country
        let language = t.code
        request = Task { [weak self] in
            do {
                var components = URLComponents(url: apiURL.appendingPathComponent("api/v1/song"), resolvingAgainstBaseURL: false)
                components?.queryItems = [URLQueryItem(name: "input", value: input), URLQueryItem(name: "country", value: country)]
                guard let url = components?.url else { throw URLError(.badURL) }
                var request = URLRequest(url: url)
                request.timeoutInterval = 25
                Self.identify(&request, language: language)
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let self, !self.isClosed, !Task.isCancelled else { return }
                self.isLoading = false
                guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                if response.statusCode >= 400 {
                    self.error = try JSONDecoder().decode(APIError.self, from: data).error
                    self.canRetry = response.statusCode == 429 || response.statusCode >= 500
                } else {
                    self.song = try JSONDecoder().decode(Song.self, from: data)
                }
            } catch {
                guard let self, !self.isClosed, !Task.isCancelled else { return }
                self.isLoading = false
                self.error = self.t.unreachable
                self.canRetry = true
            }
        }
    }

    func failToReadInput() {
        isLoading = false
        error = t.unreadable
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
