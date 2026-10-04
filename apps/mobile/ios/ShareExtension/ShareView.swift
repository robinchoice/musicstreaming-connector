import SwiftUI
import UIKit

struct ShareView: View {
    @ObservedObject var model: ShareModel
    let finish: () -> Void
    @State private var shareItem: SharedLink?
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
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    }
                    .safeAreaInset(edge: .bottom) {
                        actions(candidate.url, share: "Als \(model.targetName)-Link teilen", copy: "Link kopieren", hint: "Prüfe die gewünschte Aufnahme vor dem Teilen.")
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
            ActivitySheet(url: item.url) { completed in
                shareItem = nil
                if completed { finish() }
            }
        }
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

    private func actions(_ link: String, share: String, copy: String, hint: String) -> some View {
        VStack(spacing: 10) {
            Button {
                if let url = URL(string: link) { shareItem = SharedLink(url: url) }
            } label: {
                Label(share, systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button(copied ? "Link kopiert ✓" : copy) {
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

private struct SharedLink: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let url: URL
    let completion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            DispatchQueue.main.async { completion(completed) }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
