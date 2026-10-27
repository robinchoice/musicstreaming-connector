import SwiftUI
import UIKit
import CoreText

// Colours of the app, see lib/core/brand.dart
private enum Brand {
    static let background = Color(hex: 0x0E0D12)
    static let raised = Color(hex: 0x201F25)
    static let text = Color(hex: 0xF2F0EA)
    static let muted = Color(hex: 0x9A98A3)
    static let ink = Color(hex: 0x17171A)
    static let hairline = Color.white.opacity(0.07)
    static let hairlineStrong = Color.white.opacity(0.14)
    static func displayFont(size: CGFloat) -> Font {
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute as String: "BricolageGrotesque-96ptExtraBold",
            kCTFontVariationAttribute as String: [0x77647468: 80.0, 0x77676874: 780.0]
        ] as CFDictionary)
        return Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
    }
    // The band 3.85 to 4.55 on glow, only for the main action and picked items
    static let accent = Color(hex: 0x64CC9E)
    static let gradient = LinearGradient(
        colors: [Color(hex: 0x80CD84), accent, Color(hex: 0x57C6BB)],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    init(hue: Double, saturation: Double, lightness: Double) {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let x = chroma * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let (r, g, b): (Double, Double, Double) = switch Int(hue / 60) % 6 {
        case 0: (chroma, x, 0)
        case 1: (x, chroma, 0)
        case 2: (0, chroma, x)
        case 3: (0, x, chroma)
        case 4: (x, 0, chroma)
        default: (chroma, 0, x)
        }
        let m = lightness - chroma / 2
        self.init(red: r + m, green: g + m, blue: b + m)
    }
}

// Simple Icons (CC0) like assets/logos, converted to absolute M, L, H, V, C and Z
// with svgpath: svgpath(d).abs().unarc().unshort().round(3)
struct ServiceLogo: View {
    let platform: String
    var size: CGFloat = 24

    private static let colors: [String: UInt32] = ["appleMusic": 0xFA243C, "youtubeMusic": 0xFF0033, "spotify": 0x1ED760, "deezer": 0xA238FF]
    private static let paths: [String: String] = [
        "appleMusic": "M23.994 6.124C24.002 5.387 23.921 4.652 23.754 3.934 23.437 2.624 22.692 1.624 21.574 0.891 21.004 0.525 20.365 0.278 19.697 0.165 19.18 0.076 18.657 0.026 18.133 0.015 18.093 0.012 18.05 0.005 18.009 0.002H5.986C5.834 0.012 5.683 0.019 5.531 0.028 4.784 0.071 4.041 0.151 3.338 0.428 2.002 0.958 1.038 1.88 0.473 3.208 0.281 3.656 0.181 4.133 0.11 4.616 0.054 5.008 0.022 5.401 0.01 5.796 0.01 5.828 0.003 5.858 0 5.889V18.112C0.01 18.252 0.017 18.395 0.027 18.536 0.077 19.351 0.181 20.16 0.524 20.909 1.174 22.329 2.262 23.262 3.758 23.71 4.178 23.837 4.614 23.897 5.051 23.938 5.606 23.991 6.161 23.998 6.718 23.998H17.748C18.273 23.998 18.797 23.964 19.318 23.898 20.14 23.792 20.914 23.548 21.613 23.088 22.442 22.552 23.096 21.785 23.493 20.881 23.679 20.461 23.786 20.011 23.863 19.557 23.976 18.882 24.001 18.199 24 17.517 23.998 13.717 24 9.922 23.997 6.124ZM17.571 10.114V15.826C17.571 16.243 17.513 16.653 17.327 17.032 17.037 17.622 16.567 17.994 15.939 18.172 15.589 18.272 15.233 18.329 14.869 18.345 13.919 18.39 13.096 17.745 12.926 16.809 12.779 15.978 13.204 15.152 13.964 14.787 14.287 14.627 14.634 14.537 14.982 14.463 15.36 14.381 15.74 14.31 16.116 14.223 16.39 14.16 16.573 13.993 16.626 13.707 16.64 13.644 16.646 13.579 16.646 13.514 16.646 11.699 16.646 9.884 16.644 8.071 16.643 8.008 16.635 7.946 16.618 7.886 16.578 7.736 16.468 7.643 16.314 7.652 16.154 7.662 15.996 7.687 15.839 7.718 15.079 7.868 14.319 8.021 13.559 8.174L11.234 8.644 9.86 8.922C9.844 8.925 9.828 8.932 9.812 8.935 9.535 9.012 9.435 9.138 9.422 9.425 9.42 9.467 9.422 9.511 9.422 9.555 9.42 12.157 9.422 14.759 9.419 17.36 9.419 17.78 9.372 18.196 9.204 18.587 8.926 19.227 8.434 19.627 7.77 19.82 7.42 19.92 7.06 19.98 6.695 19.992 5.735 20.028 4.94 19.392 4.775 18.448 4.635 17.636 5.005 16.763 5.929 16.373 6.286 16.223 6.659 16.141 7.037 16.063 7.324 16.003 7.612 15.947 7.897 15.886 8.28 15.803 8.48 15.563 8.497 15.172V15.022C8.497 12.062 8.497 9.1 8.499 6.14 8.499 6.017 8.512 5.89 8.541 5.77 8.611 5.485 8.814 5.322 9.087 5.252 9.342 5.186 9.602 5.14 9.861 5.087 10.594 4.937 11.327 4.791 12.061 4.643L14.331 4.183C15.001 4.049 15.671 3.913 16.341 3.78 16.561 3.737 16.783 3.692 17.004 3.674 17.314 3.649 17.527 3.844 17.558 4.156 17.566 4.229 17.57 4.304 17.57 4.379 17.572 6.289 17.572 8.201 17.57 10.111Z",
        "youtubeMusic": "M12 0C5.376 0 0 5.376 0 12 0 18.624 5.376 24 12 24 18.624 24 24 18.624 24 12 24 5.376 18.624 0 12 0ZM12 19.104C8.076 19.104 4.896 15.924 4.896 12 4.896 8.076 8.076 4.896 12 4.896 15.924 4.896 19.104 8.076 19.104 12 19.104 15.924 15.924 19.104 12 19.104ZM12 5.772C8.568 5.772 5.772 8.568 5.772 12 5.772 15.432 8.568 18.228 12 18.228 15.432 18.228 18.228 15.432 18.228 12 18.228 8.568 15.432 5.772 12 5.772ZM9.684 15.54V8.46L15.816 12 9.684 15.54Z",
        "spotify": "M12 0C5.4 0 0 5.4 0 12 0 18.6 5.4 24 12 24 18.6 24 24 18.6 24 12 24 5.4 18.66 0 12 0ZM17.521 17.34C17.281 17.699 16.861 17.82 16.5 17.58 13.68 15.84 10.14 15.479 5.939 16.439 5.521 16.561 5.16 16.26 5.04 15.9 4.92 15.479 5.22 15.12 5.58 15 10.14 13.979 14.1 14.4 17.22 16.32 17.64 16.5 17.699 16.979 17.521 17.34ZM18.961 14.04C18.66 14.46 18.12 14.64 17.699 14.34 14.46 12.36 9.54 11.76 5.76 12.96 5.281 13.08 4.74 12.84 4.62 12.36 4.5 11.88 4.74 11.339 5.22 11.219 9.6 9.9 15 10.561 18.72 12.84 19.081 13.021 19.26 13.62 18.961 14.04ZM19.081 10.68C15.24 8.4 8.82 8.16 5.16 9.301 4.56 9.48 3.96 9.12 3.78 8.58 3.6 7.979 3.96 7.38 4.5 7.199 8.76 5.939 15.78 6.179 20.221 8.82 20.76 9.12 20.94 9.84 20.64 10.38 20.341 10.801 19.62 10.979 19.081 10.68Z",
        "deezer": "M0.693 10.024C1.074 10.024 1.386 8.768 1.386 7.217 1.386 5.667 1.074 4.41 0.693 4.41 0.312 4.41 0 5.666 0 7.217 0 8.768 0.312 10.025 0.693 10.025ZM21.038 1.56C20.674 1.56 20.354 2.365 20.128 3.656 19.765 1.446 19.184 0 18.526 0 17.746 0 17.062 2.036 16.742 5 16.43 2.842 15.954 1.464 15.417 1.464 14.672 1.464 14.031 4.168 13.797 7.936 13.355 6.004 12.714 4.791 12.004 4.791 11.294 4.791 10.654 6.004 10.211 7.936 9.969 4.176 9.337 1.473 8.583 1.473 8.046 1.473 7.57 2.851 7.258 5.008 6.938 2.036 6.262 0 5.474 0 4.816 0 4.227 1.447 3.872 3.665 3.655 2.374 3.326 1.56 2.962 1.56 2.287 1.56 1.741 4.367 1.741 7.832 1.741 11.298 2.287 14.105 2.962 14.105 3.239 14.105 3.499 13.629 3.698 12.832 4.018 15.76 4.694 17.77 5.474 17.77 6.08 17.77 6.617 16.566 6.981 14.66 7.232 18.282 7.856 20.855 8.583 20.855 9.043 20.855 9.458 19.832 9.77 18.178 10.142 21.6 11 24 12.004 24 13.009 24 13.867 21.6 14.239 18.178 14.551 19.832 14.966 20.855 15.425 20.855 16.153 20.855 16.777 18.282 17.028 14.66 17.392 16.566 17.928 17.77 18.535 17.77 19.315 17.77 19.99 15.76 20.31 12.832 20.518 13.629 20.77 14.105 21.047 14.105 21.722 14.105 22.267 11.298 22.267 7.832 22.259 4.375 21.714 1.56 21.037 1.56ZM23.307 10.024C23.688 10.024 24 8.768 24 7.217 24 5.667 23.688 4.41 23.307 4.41 22.926 4.41 22.614 5.666 22.614 7.217 22.614 8.768 22.926 10.025 23.307 10.025Z",
    ]

    private static let parsedPaths = paths.mapValues(LogoShape.parse)

    var body: some View {
        LogoShape(logo: Self.parsedPaths[platform] ?? Path())
            .fill(Color(hex: Self.colors[platform] ?? 0x9A98A3))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct LogoShape: Shape {
    let logo: Path

    func path(in rect: CGRect) -> Path {
        logo.applying(CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: rect.width / 24, y: rect.height / 24))
    }

    static func parse(_ d: String) -> Path {
        // Commands and numbers; a minus or a second dot starts a new number
        var tokens: [String] = []
        var digits = ""
        func flush() {
            if !digits.isEmpty { tokens.append(digits) }
            digits = ""
        }
        for character in d {
            if character.isLetter {
                flush()
                tokens.append(String(character))
            } else if character == " " || character == "," {
                flush()
            } else {
                if character == "-" || (character == "." && digits.contains(".")) { flush() }
                digits.append(character)
            }
        }
        flush()
        var path = Path()
        var command = "M"
        var index = 0
        var current = CGPoint.zero
        func number() -> CGFloat {
            defer { index += 1 }
            return CGFloat(Double(tokens[index]) ?? 0)
        }
        func point() -> CGPoint { CGPoint(x: number(), y: number()) }
        while index < tokens.count {
            if let letter = tokens[index].first, letter.isLetter {
                command = tokens[index]
                index += 1
                if command == "Z" { path.closeSubpath(); continue }
            }
            switch command {
            case "M":
                current = point()
                path.move(to: current)
                command = "L"
            case "L": current = point(); path.addLine(to: current)
            case "H": current.x = number(); path.addLine(to: current)
            case "V": current.y = number(); path.addLine(to: current)
            case "C":
                let control1 = point(), control2 = point()
                current = point()
                path.addCurve(to: current, control1: control1, control2: control2)
            default: index += 1
            }
        }
        return path
    }
}

// Initial on a steady colour per name with the friend's service as a badge, the same as in the app
private struct FriendAvatar: View {
    let friend: Friend
    var size: CGFloat = 28

    var body: some View {
        let hue = Double(friend.name.utf16.reduce(7) { ($0 * 31 + Int($1)) % 360 })
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color(hue: hue, saturation: 0.35, lightness: 0.30))
                .frame(width: size, height: size)
                .overlay(
                    Text(String(friend.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(Color(hue: hue, saturation: 0.6, lightness: 0.88))
                )
                .padding([.trailing, .bottom], 3)
            ServiceLogo(platform: friend.platform, size: (size * 0.38).rounded())
                .padding(2)
                .background(Circle().fill(Brand.background))
        }
        .accessibilityHidden(true)
    }
}

// A rounded chip, its border turns into the gradient when picked
private struct PickChip<Leading: View>: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    var leadingPadding: CGFloat = 5
    @ViewBuilder var leading: Leading

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                leading
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.text)
                    .lineLimit(1)
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, 14)
            .frame(minHeight: 38)
            .background(Capsule().fill(selected ? Brand.raised : Color.white.opacity(0.03)))
            .overlay(
                Capsule().strokeBorder(selected ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Brand.hairlineStrong), lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ShareView: View {
    @ObservedObject var model: ShareModel
    let finish: () -> Void
    @State private var shareItem: SharedItem?
    @State private var copied = false
    @State private var showingGuide = false
    @ScaledMetric(relativeTo: .title2) private var titleSize: CGFloat = 22
    @ScaledMetric(relativeTo: .headline) private var brandSize: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var sectionSize: CGFloat = 15

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.background.ignoresSafeArea()
                if let song = model.song {
                    AsyncImage(url: song.source.artworkUrl.flatMap(URL.init(string:))) { phase in
                        ZStack {
                            backdrop(phase.image)
                            result(song, image: phase.image)
                        }
                    }
                } else if model.isLoading {
                    VStack(spacing: 16) {
                        if let source = model.input.flatMap({ ShareModel.sourceOf($0) }) {
                            ServiceLogo(platform: source, size: 36)
                        }
                        ProgressView()
                        Text(model.t.searching)
                            .foregroundStyle(Brand.muted)
                    }
                    .accessibilityElement(children: .combine)
                } else if let error = model.error {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(Brand.muted)
                        Text(error)
                            .multilineTextAlignment(.center)
                        if model.canRetry {
                            Button(model.t.retry, action: model.retry)
                                .buttonStyle(MainButtonStyle())
                        }
                    }
                    .padding(24)
                }
            }
            .foregroundStyle(Brand.text)
            .navigationTitle("Songgate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Brand.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Songgate")
                        .font(Brand.displayFont(size: brandSize))
                        .tracking(-0.035 * brandSize)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingGuide = true } label: {
                        Image(systemName: "star")
                    }
                    .accessibilityLabel(model.t.handy)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.t.close, action: finish)
                }
            }
        }
        .tint(Brand.accent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingGuide) {
            NavigationStack {
                Form {
                    Text(model.t.guide)
                }
                .navigationTitle(model.t.handy)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(model.t.handy)
                            .font(Brand.displayFont(size: brandSize))
                            .tracking(-0.035 * brandSize)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(model.t.done) { showingGuide = false }
                    }
                }
            }
            .tint(Brand.accent)
            .preferredColorScheme(.dark)
        }
        .popover(item: $shareItem) { item in
            ActivitySheet(items: item.items) { completed in
                shareItem = nil
                if completed { finish() }
            }
        }
    }

    // The cover, blurred far behind the result, tints the page
    private func backdrop(_ image: Image?) -> some View {
        Color.clear
            .frame(height: 360)
            .overlay {
                if let image {
                    image.resizable().scaledToFill()
                }
            }
            .clipped()
            .blur(radius: 60)
            .opacity(0.26)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func result(_ song: Song, image: Image?) -> some View {
        let message = model.message
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                            .foregroundStyle(Brand.muted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Brand.raised)
                    }
                }
                .frame(width: 148, height: 148)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                .accessibilityHidden(true)
                Text(model.t.kindFrom(song.source.kind == "album", ShareModel.platforms[song.source.platform] ?? song.source.platform))
                    .font(.subheadline)
                    .foregroundStyle(Brand.muted)
                    .padding(.top, 16)
                Text(song.source.title)
                    .font(Brand.displayFont(size: titleSize))
                    .tracking(-0.035 * titleSize)
                    .padding(.top, 4)
                Text(song.source.artist)
                    .foregroundStyle(Brand.text.opacity(0.8))
                    .padding(.top, 2)
                friendsSection
                    .padding(.top, 20)
                tiles(song)
                    .padding(.top, 16)
                if let message {
                    messageBox(message)
                        .padding(.top, 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            if let message {
                actions(message)
            }
        }
    }

    // "An wen?": everyone, a group or friends. Picking people picks their services.
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t.toWhom)
                .font(Brand.displayFont(size: sectionSize))
                .tracking(-0.035 * sectionSize)
            if model.friends.isEmpty {
                Text(model.t.friendsTip)
                    .font(.caption)
                    .foregroundStyle(Brand.muted)
            } else {
                let anyGroup = model.groups.contains { model.isGroupChosen($0) }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        PickChip(label: model.t.everyone, selected: model.services.isEmpty, action: { model.pick([]); copied = false }, leadingPadding: 14) { EmptyView() }
                        ForEach(model.groups, id: \.self) { group in
                            PickChip(label: group.name, selected: model.isGroupChosen(group), action: { model.toggle(group: group); copied = false }) {
                                Text("\(group.members.count)")
                                    .font(.caption)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Brand.raised))
                                    .accessibilityHidden(true)
                            }
                        }
                        ForEach(model.friends, id: \.self) { friend in
                            PickChip(label: friend.name, selected: model.chosen.contains(friend.name) && !anyGroup, action: { model.toggle(friend.name); copied = false }) {
                                FriendAvatar(friend: friend)
                            }
                            .accessibilityLabel("\(friend.name), \(ShareModel.platforms[friend.platform] ?? friend.platform)")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // All four services, tapping one adds or removes its link from the message
    private func tiles(_ song: Song) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(ShareModel.serviceOrder, id: \.self) { platform in
                let selected = model.services.contains(platform)
                let name = ShareModel.platforms[platform] ?? platform
                Button {
                    model.toggle(service: platform)
                    copied = false
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        ServiceLogo(platform: platform, size: 26)
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .padding(.trailing, 18)
                        Text(model.detail(platform))
                            .font(.caption)
                            .foregroundStyle(Brand.muted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Brand.raised : Color.white.opacity(0.03)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(selected ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Brand.hairlineStrong), lineWidth: selected ? 1.5 : 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Brand.accent)
                                .padding(10)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(name), \(model.detail(platform))")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var hint: String {
        guard let first = model.services.first else { return model.t.hintEveryone }
        if model.services.count > 1 { return model.t.hintSeveral }
        return model.t.hintOne(ShareModel.platforms[first] ?? first, model.me != nil)
    }

    private func messageBox(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hint)
                .font(.caption)
                .foregroundStyle(Brand.muted)
            Text(message)
                .font(.footnote)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.25)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Brand.hairline))
    }

    private func actions(_ message: String) -> some View {
        HStack(spacing: 8) {
            Button {
                shareItem = SharedItem(items: [message])
            } label: {
                Label(model.t.share, systemImage: "square.and.arrow.up")
            }
            .buttonStyle(MainButtonStyle())
            Button {
                UIPasteboard.general.string = message
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { finish() }
            } label: {
                Label(copied ? model.t.copied : model.t.copy, systemImage: "doc.on.doc")
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Brand.background.opacity(0.92))
    }
}

// Pill buttons like the app: the gradient only on the main action
private struct MainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Brand.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 18)
            .background(Capsule().fill(Brand.gradient))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Brand.text)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 18)
            .contentShape(Capsule())
            .overlay(Capsule().strokeBorder(Brand.hairlineStrong))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

private struct SharedItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    let completion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            DispatchQueue.main.async { completion(completed) }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
