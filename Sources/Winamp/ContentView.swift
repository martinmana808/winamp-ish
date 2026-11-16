import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var player: Player
    @State private var selection = Set<UUID>()
    @State private var scrub: Double?

    var body: some View {
        VStack(spacing: 0) {
            header.padding(16)
            Divider()
            playlist
            Divider()
            footer
        }
        .frame(minWidth: 300, minHeight: 520)
        .background {
            LinearGradient(colors: [player.backdrop, Color(white: 0.07)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .tint(player.accent)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.6), value: player.backdrop)
        .dropDestination(for: URL.self) { urls, _ in
            player.add(urls)
            return true
        }
    }

    // MARK: - Now playing + controls

    private var header: some View {
        VStack(spacing: 12) {
            artwork

            Text(player.current?.title ?? "Nada sonando")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(player.current == nil ? .secondary : .primary)

            VStack(spacing: 2) {
                Slider(
                    value: Binding(get: { scrub ?? player.currentTime }, set: { scrub = $0 }),
                    in: 0...max(player.duration, 1)
                ) { editing in
                    if !editing, let target = scrub {
                        player.seek(to: target)
                        scrub = nil
                    }
                }
                .controlSize(.small)
                .disabled(player.current == nil)

                HStack {
                    Text(timeString(scrub ?? player.currentTime))
                    Spacer()
                    Text(timeString(player.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                iconButton("shuffle", help: "Aleatorio", active: player.shuffle) { player.shuffle.toggle() }
                iconButton("backward.fill", help: "Anterior", size: 18) { player.previous() }
                iconButton(player.isPlaying ? "pause.fill" : "play.fill", help: "Reproducir / Pausar", size: 30) {
                    player.togglePlay()
                }
                .frame(width: 34)
                .keyboardShortcut(.space, modifiers: [])
                iconButton("forward.fill", help: "Siguiente", size: 18) { player.next() }
                iconButton(
                    player.repeatMode == .one ? "repeat.1" : "repeat",
                    help: repeatHelp,
                    active: player.repeatMode != .off
                ) { player.repeatMode = player.repeatMode.next }
            }
        }
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08))
            if let image = player.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(width: 200, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        .padding(.bottom, 4)
    }

    private var repeatHelp: String {
        switch player.repeatMode {
        case .off: "Repetir: no"
        case .all: "Repetir: toda la lista"
        case .one: "Repetir: este tema"
        }
    }

    private func iconButton(
        _ symbol: String, help: String, size: CGFloat = 14, active: Bool? = nil, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(active == true ? AnyShapeStyle(.tint) : AnyShapeStyle(active == false ? .secondary : .primary))
                .frame(minWidth: 24, minHeight: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Playlist

    private var playlist: some View {
        List(selection: $selection) {
            ForEach(player.tracks) { track in
                let isCurrent = track.id == player.currentID
                HStack(spacing: 6) {
                    Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .opacity(isCurrent ? 1 : 0)
                        .frame(width: 16)
                    Text(track.title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .fontWeight(isCurrent ? .semibold : .regular)
                }
            }
            .onMove { player.move(from: $0, to: $1) }
        }
        .scrollContentBackground(.hidden)
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let first = player.tracks.first(where: { ids.contains($0.id) }) {
                Button("Reproducir") { player.play(first.id) }
                Button("Mostrar en Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        player.tracks.filter { ids.contains($0.id) }.map(\.url))
                }
                Divider()
                Button("Quitar de la lista") {
                    player.remove(ids)
                    selection.subtract(ids)
                }
            }
        } primaryAction: { ids in
            if let first = player.tracks.first(where: { ids.contains($0.id) }) { player.play(first.id) }
        }
        .onDeleteCommand {
            player.remove(selection)
            selection = []
        }
        .overlay {
            if player.tracks.isEmpty {
                ContentUnavailableView(
                    "Arrastrá música acá",
                    systemImage: "music.note.list",
                    description: Text("Archivos, carpetas o una playlist .m3u"))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button { player.openPanel() } label: { Image(systemName: "plus") }
                .help("Agregar música…")
            Button { player.exportPanel() } label: { Image(systemName: "square.and.arrow.up") }
                .help("Exportar playlist…")
                .disabled(player.tracks.isEmpty)
            Menu {
                ForEach(SortOrder.allCases) { order in
                    Button(order.rawValue) { player.sort(order) }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Ordenar playlist")
            .disabled(player.tracks.count < 2)
            Spacer()
            Text(player.tracks.count == 1 ? "1 tema" : "\(player.tracks.count) temas")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
