import Foundation
import AVFoundation
import Combine
import Accelerate

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
    @Published var searchText: String = ""
    @Published var currentIndexInFiltered: Int = -1
    @Published var isPlaying: Bool = false
    @Published var isShuffle: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    
    // Set volume to always 1.0 per user request
    let volume: Float = 1.0
    
    // Flag to prevent timer updates while user is scrubbing
    var isScrubbing: Bool = false
    
    var filteredPlaylist: [Track] {
        if searchText.isEmpty {
            return playlist
        } else {
            return playlist.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    // Current track based on the filtered list
    var currentTrack: Track? {
        guard currentIndexInFiltered >= 0 && currentIndexInFiltered < filteredPlaylist.count else { return nil }
        return filteredPlaylist[currentIndexInFiltered]
    }
    
    @Published var spectrum: [Float] = Array(repeating: 0, count: 20)
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var visualizerTimer: AnyCancellable?
    
    init() {}
    
    func addFiles(urls: [URL]) {
        let newTracks = urls.map { url in
            Track(url: url, name: url.deletingPathExtension().lastPathComponent)
        }
        playlist.append(contentsOf: newTracks)
        
        if currentIndexInFiltered == -1 && !filteredPlaylist.isEmpty {
            loadTrack(at: 0)
        }
    }
    
    func loadTrack(at index: Int) {
        guard index >= 0 && index < filteredPlaylist.count else { return }
        currentIndexInFiltered = index
        let track = filteredPlaylist[index]
        
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        
        player = AVPlayer(url: track.url)
        player?.volume = volume
        
        // Duration logic
        let asset = AVAsset(url: track.url)
        Task {
            if let durationValue = try? await asset.load(.duration) {
                let d = CMTimeGetSeconds(durationValue)
                await MainActor.run { self.duration = d }
            }
        }
        
        // Time observation
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            let t = CMTimeGetSeconds(time)
            Task { @MainActor in 
                if let self = self, !self.isScrubbing {
                    self.currentTime = t 
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.next() }
        }
        
        if isPlaying {
            player?.play()
        }
        
        startVisualizerTimer()
    }
    
    private func startVisualizerTimer() {
        visualizerTimer?.cancel()
        visualizerTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self, self.isPlaying else { 
                self?.spectrum = Array(repeating: 0, count: 20)
                return 
            }
            self.spectrum = (0..<20).map { _ in Float.random(in: 2...15) }
        }
    }
    
    func togglePlay() {
        if isPlaying {
            player?.pause()
        } else {
            if currentIndexInFiltered == -1 && !filteredPlaylist.isEmpty {
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
        spectrum = Array(repeating: 0, count: 20)
    }
    
    func next() {
        guard !filteredPlaylist.isEmpty else { return }
        var nextIndex: Int
        if isShuffle && filteredPlaylist.count > 1 {
            repeat {
                nextIndex = Int.random(in: 0..<filteredPlaylist.count)
            } while nextIndex == currentIndexInFiltered
        } else {
            nextIndex = (currentIndexInFiltered + 1) % filteredPlaylist.count
        }
        loadTrack(at: nextIndex)
    }
    
    func prev() {
        guard !filteredPlaylist.isEmpty else { return }
        var prevIndex: Int
        if isShuffle && filteredPlaylist.count > 1 {
            repeat {
                prevIndex = Int.random(in: 0..<filteredPlaylist.count)
            } while prevIndex == currentIndexInFiltered
        } else {
            prevIndex = (currentIndexInFiltered - 1 + filteredPlaylist.count) % filteredPlaylist.count
        }
        loadTrack(at: prevIndex)
    }
    
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
    }
    
    func clearPlaylist() {
        stop()
        playlist.removeAll()
        currentIndexInFiltered = -1
        currentTime = 0
        duration = 0
    }
}
