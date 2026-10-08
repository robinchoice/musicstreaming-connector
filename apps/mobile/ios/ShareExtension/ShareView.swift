import SwiftUI
import UIKit

struct ShareView: View {
    @ObservedObject var model: ShareModel
    let finish: () -> Void
    @State private var shareItem: SharedItem?
    @State private var copied = false
    @State private var showingGuide = false
    private let accent = Color(red: 66 / 255, green: 99 / 255, blue: 63 / 255)

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("\(model.targetName)-Treffer suchen …")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .combine)
                } else if let error = model.error {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(error)
                            .multilineTextAlignment(.center)
                        if model.canRetry {
                            Button("Erneut versuchen", action: model.retry)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaInset(edge: .bottom) {
                        if let link = model.searchUrl {
                            actions(link, share: "Suche auf \(model.targetName) teilen", copy: "Suchlink kopieren", hint: "Teile stattdessen eine Suche nach dem Song.")
                        }
                    }
                } else if let conversion = model.conversion,
                          let candidate = conversion.candidates.first(where: { $0.url == model.selection }) {
                    ScrollView {
                        VStack(spacing: 14) {
                            artwork(candidate, size: 148)
                                .padding(.top, 20)
                            Text(candidate.title)
                                .font(.title2.weight(.semibold))
                                .multilineTextAlignment(.center)
                            Text(conversion.source.artist)
                                .foregroundStyle(.secondary)
                            Text(model.targetName)
                                .font(.subheadline)
                                .foregroundStyle(accent)
                            if let album = candidate.album {
                                Text(album).font(.caption).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            if let seconds = candidate.durationSeconds {
                                Text("\(seconds / 60):\(String(format: "%02d", seconds % 60))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if conversion.candidates.count > 1 {
                                DisclosureGroup("Andere Fassungen (\(conversion.candidates.count - 1))") {
                                    ForEach(conversion.candidates.filter { $0.url != candidate.url }, id: \.url) { other in
                                        Button {
                                            model.selection = other.url
                                            copied = false
                                        } label: {
                                            candidateRow(other)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.top, 12)
                            }
                            if model.friends.isEmpty {
                                Text("Tipp: In der MusicLink-App speicherst du Freunde mit ihrem Dienst und teilst an mehrere auf einmal.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 12)
                            } else {
                                friendsSection
                                    .padding(.top, 12)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    }
                    .safeAreaInset(edge: .bottom) {
                        if model.chosen.isEmpty {
                            actions(candidate.url, share: "Als \(model.targetName)-Link teilen", copy: "Link kopieren", hint: "Prüfe die gewünschte Aufnahme vor dem Teilen.")
                        } else if let message = model.message {
                            actions(message, share: "An \(model.chosen.joined(separator: ", ")) teilen", copy: "Nachricht kopieren", hint: "Jeder tippt auf die Zeile mit seinem Dienst.", isText: true)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Teilen als", selection: Binding(get: { model.target }, set: { model.target = $0; model.targetChanged(); copied = false })) {
                    ForEach(model.targets, id: \.self) { target in
                        Text(ShareModel.platforms[target] ?? target).tag(target)
                    }
                }
                .pickerStyle(.menu)
                .disabled(model.isLoading)
                .padding(.horizontal)
            }
            .background(Color(red: 251 / 255, green: 252 / 255, blue: 247 / 255))
            .navigationTitle("MusicLink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingGuide = true } label: {
                        Image(systemName: "star")
                    }
                    .accessibilityLabel("MusicLink griffbereit")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen", action: finish)
                }
            }
        }
        .tint(accent)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showingGuide) {
            NavigationStack {
                Form {
                    Text("Im Teilen-Menü: Mehr → Bearbeiten → Plus bei MusicLink. Ziehe MusicLink über den Griff nach oben und tippe auf Fertig.")
                }
                .navigationTitle("MusicLink griffbereit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { showingGuide = false }
                    }
                }
            }
            .tint(accent)
        }
        .popover(item: $shareItem) { item in
            ActivitySheet(items: item.items) { completed in
                shareItem = nil
                if completed { finish() }
            }
        }
    }

    private static func serviceColor(_ platform: String) -> Color {
        switch platform {
        case "appleMusic": return Color(red: 250 / 255, green: 45 / 255, blue: 72 / 255)
        case "youtubeMusic": return Color(red: 1, green: 0, blue: 51 / 255)
        case "spotify": return Color(red: 29 / 255, green: 185 / 255, blue: 84 / 255)
        default: return Color(red: 162 / 255, green: 56 / 255, blue: 1)
        }
    }

    // Tap friends to pick them, tap a group to pick all its members
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Für wen?")
                .font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(model.friends, id: \.self) { friend in
                        let chosen = model.chosen.contains(friend.name)
                        Button {
                            model.toggle(friend.name)
                            copied = false
                        } label: {
                            VStack(spacing: 4) {
                                ZStack(alignment: .bottomTrailing) {
                                    Circle()
                                        .fill(accent.opacity(0.15))
                                        .frame(width: 50, height: 50)
                                        .overlay(Text(String(friend.name.prefix(1)).uppercased()).font(.headline).foregroundStyle(accent))
                                        .overlay(Circle().stroke(chosen ? accent : Color.clear, lineWidth: 2.5))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Self.serviceColor(friend.platform))
                                        .frame(width: 16, height: 16)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: 2))
                                }
                                Text(friend.name)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(width: 60)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(friend.name), \(ShareModel.platforms[friend.platform] ?? friend.platform)")
                        .accessibilityAddTraits(chosen ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
            if !model.groups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.groups, id: \.self) { group in
                            Button(group.name) {
                                model.toggle(group: group)
                                copied = false
                            }
                            .buttonStyle(.bordered)
                            .tint(model.isGroupChosen(group) ? accent : Color.secondary)
                        }
                    }
                }
            }
            if model.isLoadingMessage {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let message = model.message {
                Text(message)
                    .font(.footnote)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            } else if model.messageFailed {
                Text("Die Links für deine Freunde konnten nicht geladen werden. Versuche es erneut.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func candidateRow(_ candidate: SongCandidate) -> some View {
        HStack(spacing: 12) {
            artwork(candidate, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.title)
                if let album = candidate.album { Text(album).font(.caption).foregroundStyle(.secondary) }
                if let seconds = candidate.durationSeconds {
                    Text("\(seconds / 60):\(String(format: "%02d", seconds % 60))").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private func artwork(_ candidate: SongCandidate, size: CGFloat) -> some View {
        AsyncImage(url: candidate.artworkUrl.flatMap(URL.init(string:))) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "music.note")
                .font(.title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)
    }

    private func actions(_ link: String, share: String, copy: String, hint: String, isText: Bool = false) -> some View {
        VStack(spacing: 10) {
            Button {
                if isText {
                    shareItem = SharedItem(items: [link])
                } else if let url = URL(string: link) {
                    shareItem = SharedItem(items: [url])
                }
            } label: {
                Label(share, systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button(copied ? (isText ? "Nachricht kopiert ✓" : "Link kopiert ✓") : copy) {
                UIPasteboard.general.string = link
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { finish() }
            }
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.regularMaterial)
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
