import Foundation

@main
struct ShareTargetsTests {
    @MainActor
    static func main() {
        let cases: [(String, String?)] = [
            ("https://spotify.link/6tpneu0iVIb", "spotify"),
            ("Hör mal: https://spotify.link/6tpneu0iVIb", "spotify"),
            ("https://open.spotify.com/track/2Foc5Q5nqNiosCNqttzHof", "spotify"),
            ("https://music.apple.com/de/song/945575419", "appleMusic"),
            ("https://music.youtube.com/watch?v=UijW9hGpnzc", "youtubeMusic"),
            ("https://youtu.be/UijW9hGpnzc", "youtubeMusic"),
            ("https://www.deezer.com/track/67238735", "deezer"),
            ("", nil),
        ]
        for (input, source) in cases {
            precondition(ShareModel.sourceOf(input) == source, "Unexpected source for \(input)")
        }
        let shared = ShareModel.shareURL("https://songgate.app/s/yt/x", from: Friend(name: "Robin Ö+", platform: "youtubeMusic"))
        precondition(shared == "https://songgate.app/s/yt/x?from=Robin%20%C3%96%2B&service=youtube", "Unexpected share URL \(shared)")
        precondition(ShareModel.shareURL("https://songgate.app/s/yt/x", from: nil) == "https://songgate.app/s/yt/x")

        // The same messages as friendsMessage in packages/shared
        let json = """
        {"source":{"kind":"song","platform":"youtubeMusic","title":"Hey Jude","artist":"The Beatles","url":"https://music.youtube.com/watch?v=x","artworkUrl":null},
         "sharePath":"/s/yt/x",
         "links":{"spotify":{"url":"https://sp/x","found":true},"appleMusic":{"url":"https://am/x","found":true},
                  "youtubeMusic":{"url":"https://yt/x","found":true},"deezer":{"url":"https://dz/x","found":false}}}
        """
        let song = try! JSONDecoder().decode(Song.self, from: Data(json.utf8))
        let lisa = Friend(name: "Lisa", platform: "spotify")
        let me = Friend(name: "Robin", platform: "youtubeMusic")
        let messages: [(String, String)] = [
            (ShareModel.friendsMessage(song, friends: [], origin: "https://songgate.app", from: nil, services: []),
             "🎵 Hey Jude – The Beatles\nhttps://songgate.app/s/yt/x"),
            (ShareModel.friendsMessage(song, friends: [lisa], origin: "https://songgate.app", from: nil, services: ["spotify"]),
             "🎵 Hey Jude – The Beatles\nhttps://sp/x"),
            (ShareModel.friendsMessage(song, friends: [lisa], origin: "https://songgate.app", from: me, services: ["spotify"]),
             "🎵 Hey Jude – The Beatles\nhttps://sp/x\nAlle Dienste: https://songgate.app/s/yt/x?from=Robin&service=youtube"),
            (ShareModel.friendsMessage(song, friends: [lisa], origin: "https://songgate.app", from: nil, services: ["spotify", "appleMusic"]),
             "🎵 Hey Jude – The Beatles\nSpotify (Lisa): https://sp/x\nApple Music: https://am/x\nAndere: https://songgate.app/s/yt/x"),
        ]
        for (message, expected) in messages {
            precondition(message == expected, "Unexpected message \(message)")
        }
        print("Share targets: \(cases.count + messages.count) cases passed")
    }
}
