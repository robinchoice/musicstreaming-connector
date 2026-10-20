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
            let expected = ["appleMusic", "youtubeMusic", "spotify", "deezer"].filter { $0 != source }
            precondition(ShareModel.targets(for: input) == expected, "Unexpected targets for \(input)")
        }
        print("Share targets: \(cases.count) cases passed")
    }
}
