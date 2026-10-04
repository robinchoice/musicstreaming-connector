import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let model = ShareModel()
    private var readTask: Task<Void, Never>?
    private var finished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareView(model: model) { [weak self] in self?.finish() })
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
        preferredContentSize = CGSize(width: 420, height: 580)

        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        readTask = Task { [weak self] in
            var inputs: [String] = []
            for provider in providers {
                guard !Task.isCancelled else { return }
                let type: String
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    type = UTType.url.identifier
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    type = UTType.plainText.identifier
                } else {
                    continue
                }
                let text: String? = await withCheckedContinuation { continuation in
                    provider.loadItem(forTypeIdentifier: type, options: nil) { value, _ in
                        let text = (value as? URL)?.absoluteString ?? (value as? String)
                        continuation.resume(returning: text)
                    }
                }
                if let text { inputs.append(text) }
            }
            guard !Task.isCancelled, let self, !self.finished else { return }
            if inputs.isEmpty {
                self.model.failToReadInput()
            } else {
                self.model.resolve(inputs.joined(separator: "\n"))
            }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        readTask?.cancel()
        model.close()
        extensionContext?.completeRequest(returningItems: nil)
    }

    deinit {
        readTask?.cancel()
    }
}
