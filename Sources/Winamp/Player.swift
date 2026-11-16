import AppKit
import AVFoundation
import MediaPlayer
import SwiftUI
import UniformTypeIdentifiers

struct Track: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var title: String { url.deletingPathExtension().lastPathComponent }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case nameAscending = "Nombre (A → Z)"
    case nameDescending = "Nombre (Z → A)"
    case newestFirst = "Más nuevos primero"
    case oldestFirst = "Más viejos primero"

    var id: String { rawValue }
}

enum RepeatMode: String {
    case off, all, one

    var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}

@MainActor
final class Player: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = Player()

    @Published private(set) var tracks: [Track] = []
    @Published private(set) var currentID: UUID?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var shuffle = false { didSet { rebuildOrder(); save() } }
    @Published var repeatMode: RepeatMode = .off { didSet { save() } }

    /// Cover art of the current track, plus colors derived from it for the UI.
    @Published private(set) var artwork: NSImage?
    @Published private(set) var backdrop: Color = Player.defaultBackdrop
    @Published private(set) var accent: Color = .white

    static let defaultBackdrop = Color(white: 0.22)

    private var audio: AVAudioPlayer?
    private var artworkTask: Task<Void, Never>?
    private var order: [UUID] = []  // play order while shuffle is on
    private var restoring = false

    private static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "flac", "caf"]
    private static let playlistExtensions: Set<String> = ["m3u", "m3u8"]

    var current: Track? { tracks.first { $0.id == currentID } }

    private var sequence: [UUID] { shuffle ? order : tracks.map(\.id) }

    private override init() {
        super.init()
        restore()
        setupRemoteCommands()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - Playback

    func togglePlay() {
        guard let audio else {
            if let first = sequence.first { _ = load(first, autoplay: true) }
            return
        }
        if isPlaying { audio.pause() } else { audio.play() }
        isPlaying.toggle()
        updateNowPlaying()
    }

    /// Play a track the user picked explicitly.
    func play(_ id: UUID) {
        guard load(id, autoplay: true) else { return }
        if shuffle { rebuildOrder() }
    }

    func next() { advance(1, wrap: true) }

    func previous() {
        if currentTime > 3 { seek(to: 0) } else { advance(-1, wrap: true) }
    }

    func seek(to seconds: Double) {
        guard let audio else { return }
        audio.currentTime = min(max(0, seconds), audio.duration)
        currentTime = audio.currentTime
        updateNowPlaying()
    }

    private func load(_ id: UUID, autoplay: Bool) -> Bool {
        guard let track = tracks.first(where: { $0.id == id }),
              let player = try? AVAudioPlayer(contentsOf: track.url) else { return false }
        audio?.stop()
        audio = player
        player.delegate = self
        player.prepareToPlay()
        currentID = id
        duration = player.duration
        currentTime = 0
        if autoplay { player.play() }
        isPlaying = autoplay
        updateNowPlaying()
        loadArtwork(for: track)
        save()
        return true
    }

    /// Move through the play order, skipping files that can't be opened.
    private func advance(_ delta: Int, wrap: Bool) {
        let seq = sequence
        guard !seq.isEmpty else { return }
        var i = currentID.flatMap { seq.firstIndex(of: $0) } ?? (delta > 0 ? -1 : 0)
        for _ in 0..<seq.count {
            i += delta
            if i < 0 || i >= seq.count {
                guard wrap else { break }
                i = (i + seq.count) % seq.count
            }
            if load(seq[i], autoplay: true) { return }
        }
        // Reached the end (or nothing playable): stay on the current track, stopped.
        audio?.pause()
        audio?.currentTime = 0
        currentTime = 0
        isPlaying = false
        updateNowPlaying()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard player === self.audio else { return }
            if self.repeatMode == .one {
                player.currentTime = 0
                player.play()
            } else {
                self.advance(1, wrap: self.repeatMode == .all)
            }
        }
    }

    private func tick() {
        guard isPlaying, let audio else { return }
        currentTime = audio.currentTime
    }

    private func rebuildOrder() {
        var ids = tracks.map(\.id).filter { $0 != currentID }.shuffled()
        if let currentID, tracks.contains(where: { $0.id == currentID }) { ids.insert(currentID, at: 0) }
        order = ids
    }

    // MARK: - Playlist

    func add(_ urls: [URL], playFirst: Bool = false) {
        var known = Set(tracks.map { $0.url.standardizedFileURL.path })
        let new = urls.flatMap(expand).filter { known.insert($0.standardizedFileURL.path).inserted }.map(Track.init)
        guard !new.isEmpty else { return }
        tracks.append(contentsOf: new)
        rebuildOrder()
        save()
        if playFirst { play(new[0].id) }
    }

    func remove(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        if let currentID, ids.contains(currentID) { unload() }
        tracks.removeAll { ids.contains($0.id) }
        rebuildOrder()
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        tracks.move(fromOffsets: source, toOffset: destination)
        save()
    }

    /// One-off reorder of the playlist; manual drag reordering still works afterwards.
    func sort(_ order: SortOrder) {
        switch order {
        case .nameAscending, .nameDescending:
            tracks.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            if order == .nameDescending { tracks.reverse() }
        case .newestFirst, .oldestFirst:
            let dates = Dictionary(uniqueKeysWithValues: tracks.map { track in
                (track.id, (try? track.url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
            })
            tracks.sort { dates[$0.id]! < dates[$1.id]! }
            if order == .newestFirst { tracks.reverse() }
        }
        save()
    }

    func clear() { remove(Set(tracks.map(\.id))) }

    private func unload() {
        audio?.stop()
        audio = nil
        currentID = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        artworkTask?.cancel()
        setArtwork(nil)
        updateNowPlaying()
    }

    // MARK: - Artwork

    private func loadArtwork(for track: Track) {
        artworkTask?.cancel()
        artworkTask = Task {
            let image = await Self.findArtwork(for: track.url)
            guard !Task.isCancelled, currentID == track.id else { return }
            setArtwork(image)
            updateNowPlaying()
        }
    }

    private func setArtwork(_ image: NSImage?) {
        artwork = image
        let colors = image.flatMap(Self.colors)
        backdrop = colors?.backdrop ?? Self.defaultBackdrop
        accent = colors?.accent ?? .white
    }

    /// Embedded cover first, then a cover image sitting next to the file.
    nonisolated private static func findArtwork(for url: URL) async -> NSImage? {
        if let items = try? await AVURLAsset(url: url).load(.commonMetadata),
           let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierArtwork).first,
           let data = try? await item.load(.dataValue),
           let image = NSImage(data: data) {
            return image
        }
        let folder = url.deletingLastPathComponent()
        for name in ["cover", "folder", "front", "Cover", "Folder", "Front"] {
            for ext in ["jpg", "jpeg", "png"] {
                if let image = NSImage(contentsOf: folder.appendingPathComponent("\(name).\(ext)")) { return image }
            }
        }
        return nil
    }

    /// Picks the cover's dominant vivid color: a dark version for the window, a light one for highlights.
    nonisolated private static func colors(from image: NSImage) -> (backdrop: Color, accent: Color)? {
        let n = 24
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: n * 4, bitsPerPixel: 32),
            let context = NSGraphicsContext(bitmapImageRep: rep)
        else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: n, height: n))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.bitmapData else { return nil }

        // Average weighted towards saturated, bright pixels so the result isn't muddy.
        var r = 0.0, g = 0.0, b = 0.0, total = 0.0
        for i in 0..<(n * n) {
            let pr = Double(data[i * 4]) / 255, pg = Double(data[i * 4 + 1]) / 255, pb = Double(data[i * 4 + 2]) / 255
            let hi = max(pr, pg, pb), lo = min(pr, pg, pb)
            let weight = (hi - lo) + 0.05
            r += pr * weight; g += pg * weight; b += pb * weight; total += weight
        }
        guard total > 0 else { return nil }
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        NSColor(deviceRed: r / total, green: g / total, blue: b / total, alpha: 1)
            .getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        return (
            Color(hue: hue, saturation: min(sat, 0.75), brightness: min(max(bri, 0.3), 0.5)),
            Color(hue: hue, saturation: min(sat, 0.35), brightness: 1)
        )
    }

    nonisolated private static func mediaArtwork(_ image: NSImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    /// Turn a dropped/opened URL into audio files: folders are walked, playlists are read.
    private func expand(_ url: URL) -> [URL] {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return [] }
        if isDir.boolValue {
            let files = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])?
                .compactMap { $0 as? URL } ?? []
            return files
                .filter { Self.audioExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        }
        let ext = url.pathExtension.lowercased()
        if Self.playlistExtensions.contains(ext) { return readPlaylist(url) }
        return Self.audioExtensions.contains(ext) ? [url] : []
    }

    private func readPlaylist(_ url: URL) -> [URL] {
        guard let text = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1))
        else { return [] }
        let base = url.deletingLastPathComponent()
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .compactMap { line -> URL? in
                if line.hasPrefix("file://") { return URL(string: line) }
                if line.contains("://") { return nil }
                return URL(fileURLWithPath: line, relativeTo: base).standardizedFileURL
            }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: - Panels

    func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio] + Self.playlistExtensions.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK { add(panel.urls) }
    }

    func exportPanel() {
        guard !tracks.isEmpty else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Playlist.m3u8"
        if let type = UTType(filenameExtension: "m3u8") { panel.allowedContentTypes = [type] }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = (["#EXTM3U"] + tracks.map(\.url.path)).joined(separator: "\n") + "\n"
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // MARK: - Persistence

    private func save() {
        guard !restoring else { return }
        let defaults = UserDefaults.standard
        defaults.set(tracks.map(\.url.path), forKey: "tracks")
        defaults.set(current?.url.path, forKey: "current")
        defaults.set(shuffle, forKey: "shuffle")
        defaults.set(repeatMode.rawValue, forKey: "repeat")
    }

    private func restore() {
        restoring = true
        defer { restoring = false }
        let defaults = UserDefaults.standard
        tracks = (defaults.stringArray(forKey: "tracks") ?? []).map { Track(url: URL(fileURLWithPath: $0)) }
        shuffle = defaults.bool(forKey: "shuffle")
        repeatMode = RepeatMode(rawValue: defaults.string(forKey: "repeat") ?? "") ?? .off
        if let path = defaults.string(forKey: "current"), let track = tracks.first(where: { $0.url.path == path }) {
            _ = load(track.id, autoplay: false)
        }
        rebuildOrder()
    }

    // MARK: - Media keys / Now Playing

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self, !self.isPlaying else { return .commandFailed }
            self.togglePlay()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.isPlaying else { return .commandFailed }
            self.togglePlay()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlay()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }

    private func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard let track = current else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: audio?.currentTime ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let artwork { info[MPMediaItemPropertyArtwork] = Self.mediaArtwork(artwork) }
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused
    }
}
