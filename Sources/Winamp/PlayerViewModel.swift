import Foundation
import AVFoundation
import Combine

struct Track: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var playlist: [Track] = []
    @Published var currentIndex: Int = -1
    @Published var isPlaying: Bool = false
    @Published var isShuffle: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Float = 0.8 {
        didSet { player?.volume = volume }
    }
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    init() {}
    
    func addFiles(urls: [URL]) {
        let newTracks = urls.map { url in
            Track(url: url, name: url.deletingPathExtension().lastPathComponent)
        }
        playlist.append(contentsOf: newTracks)
        
        if currentIndex == -1 && !playlist.isEmpty {
            loadTrack(at: 0)
        }
    }
    
    func loadTrack(at index: Int) {
        guard index >= 0 && index < playlist.count else { return }
        currentIndex = index
        let track = playlist[index]
        
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        
        player = AVPlayer(url: track.url)
        player?.volume = volume
        
        // Duration
        let asset = AVAsset(url: track.url)
        Task {
            if let durationValue = try? await asset.load(.duration) {
                let d = CMTimeGetSeconds(durationValue)
                await MainActor.run {
                    self.duration = d
                }
            }
        }
        
        // Time observation
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            let t = CMTimeGetSeconds(time)
            Task { @MainActor in
                self?.currentTime = t
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.next()
            }
        }
        
        if isPlaying {
            player?.play()
        }
    }
    
    func togglePlay() {
        if isPlaying {
            player?.pause()
        } else {
            if currentIndex == -1 && !playlist.isEmpty {
                loadTrack(at: 0)
            }
            player?.play()
        }
        isPlaying.toggle()
    }
    
    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        isPlaying = false
    }
    
    func next() {
        guard !playlist.isEmpty else { return }
        if isShuffle && playlist.count > 1 {
            var nextIndex: Int
            repeat {
                nextIndex = Int.random(in: 0..<playlist.count)
            } while nextIndex == currentIndex
            loadTrack(at: nextIndex)
        } else {
            let nextIndex = (currentIndex + 1) % playlist.count
            loadTrack(at: nextIndex)
        }
    }
    
    func prev() {
        guard !playlist.isEmpty else { return }
        let prevIndex = (currentIndex - 1 + playlist.count) % playlist.count
        loadTrack(at: prevIndex)
    }
    
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
    }
    
    func clearPlaylist() {
        stop()
        playlist.removeAll()
        currentIndex = -1
        currentTime = 0
        duration = 0
    }
}
