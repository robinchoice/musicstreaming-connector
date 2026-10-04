import SwiftUI
import UIKit

struct ShareView: View {
    @ObservedObject var model: ShareModel
    let finish: () -> Void
    @State private var shareItem: SharedLink?
    @State private var copied = false

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
                } else if let conversion = model.conversion {
                    List {
                        Section("Dein Song") {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversion.source.title).font(.headline)
                                Text(conversion.source.artist).foregroundStyle(.secondary)
                            }
                        }
                        Section {
                            ForEach(conversion.candidates, id: \.url) { candidate in
                                Button {
                                    model.selection = candidate.url
                                    copied = false
                                } label: {
                                    candidateRow(candidate)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(model.selection == candidate.url ? .isSelected : [])
                            }
                        } header: {
                            Text("\(model.targetName) · \(conversion.candidates.count) Vorschläge")
                        } footer: {
                            Text("Prüfe die gewünschte Aufnahme vor dem Teilen. Bei mehreren Vorschlägen wähle den passenden Treffer.")
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        actions
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 6) {
                    Picker("Zieldienst", selection: Binding(get: { model.target }, set: { model.target = $0; model.settingsChanged(targetChanged: true); copied = false })) {
                        Text("Apple Music").tag("appleMusic")
                        Text("YouTube Music").tag("youtubeMusic")
                        Text("Spotify").tag("spotify")
                    }
                    Picker("Apple-Katalog", selection: Binding(get: { model.country }, set: { model.country = $0; model.settingsChanged(); copied = false })) {
                        Text("Deutschland").tag("DE")
                        Text("Österreich").tag("AT")
                        Text("Schweiz").tag("CH")
                        Text("USA").tag("US")
                        Text("Großbritannien").tag("GB")
                    }
                }
                .pickerStyle(.menu)
                .disabled(model.isLoading)
                .padding(.horizontal)
                .background(.regularMaterial)
            }
            .navigationTitle("MusicLink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen", action: finish)
                }
            }
        }
        .tint(.indigo)
        .popover(item: $shareItem) { item in
            ActivitySheet(url: item.url) { completed in
                shareItem = nil
                if completed { finish() }
            }
        }
    }

    private func candidateRow(_ candidate: SongCandidate) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: candidate.artworkUrl.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "music.note")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.title)
                if let album = candidate.album { Text(album).font(.caption).foregroundStyle(.secondary) }
                if let seconds = candidate.durationSeconds {
                    Text("\(seconds / 60):\(String(format: "%02d", seconds % 60))").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: model.selection == candidate.url ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(model.selection == candidate.url ? Color.indigo : Color.secondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                if let selection = model.selection, let url = URL(string: selection) {
                    shareItem = SharedLink(url: url)
                }
            } label: {
                Label("Weiterteilen", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.selection == nil)
            Button(copied ? "Link kopiert" : "Link kopieren") {
                if let selection = model.selection {
                    UIPasteboard.general.string = selection
                    copied = true
                }
            }
            .disabled(model.selection == nil)
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
