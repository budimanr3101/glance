import SwiftUI

struct FileShelfView: View {
    let presentation: FileShelfPresentation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: presentation.itemCount == 1 ? "doc.fill" : "doc.on.doc.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private var title: String {
        switch presentation.state {
        case .staged:
            return presentation.itemCount == 1 ? "File staged" : "\(presentation.itemCount) files staged"
        case .pasteTarget:
            return presentation.itemCount == 1 ? "Ready to move" : "\(presentation.itemCount) files ready"
        }
    }

    private var subtitle: String {
        switch presentation.state {
        case .staged:
            return presentation.fileNames.prefix(2).joined(separator: "  •  ")
        case .pasteTarget(let destination):
            return "Destination: \(destination)"
        }
    }
}
