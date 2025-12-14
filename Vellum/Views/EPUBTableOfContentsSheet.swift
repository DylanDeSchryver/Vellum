import SwiftUI

struct EPUBTableOfContentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var renderer: DocumentRenderer
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(renderer.chapters.enumerated()), id: \.element.id) { index, chapter in
                    Button {
                        renderer.goToChapter(index)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title)
                                    .font(.body)
                                    .foregroundStyle(index == renderer.currentChapterIndex ? Color.accentColor : Color.primary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            if index == renderer.currentChapterIndex {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.caption)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Table of Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EPUBTableOfContentsSheet(renderer: DocumentRenderer())
}
