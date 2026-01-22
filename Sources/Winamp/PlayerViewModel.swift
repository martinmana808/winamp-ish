import Foundation
import AVFoundation
import Combine
import Accelerate
import MediaPlayer

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
    @Published var spectrum: [Float] = Array(repeating: 0, count: 64)
    
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
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var timeObserverTimer: AnyCancellable?
    private let fftSize = 1024
    
    init() {
        setupAudioEngine()
        setupRemoteCommandCenter()
    }
    
    private func setupAudioEngine() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        
        // Setup Tap for FFT
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, when in
            self?.processAudioBuffer(buffer)
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isPlaying, let channelData = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        if frames < fftSize { return }
        
        // FFT Implementation using Accelerate
        let log2n = UInt(log2(Double(fftSize)))
        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        
        var realP = [Float](repeating: 0, count: fftSize / 2)
        var imagP = [Float](repeating: 0, count: fftSize / 2)
        
        realP.withUnsafeMutableBufferPointer { realPtr in
            imagP.withUnsafeMutableBufferPointer { imagPtr in
                var output = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                
                let window = [Float](repeating: 1.0, count: fftSize)
                var windowedBuffer = [Float](repeating: 0, count: fftSize)
                vDSP_vmul(channelData, 1, window, 1, &windowedBuffer, 1, vDSP_Length(fftSize))
                
                windowedBuffer.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                    let complexPtr = ptr.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(complexPtr.baseAddress!, 2, &output, 1, vDSP_Length(fftSize / 2))
                }
                
                vDSP_fft_zrip(fftSetup, &output, 1, log2n, FFTDirection(FFT_FORWARD))
                
                var magnitudes = [Float](repeating: 0, count: fftSize / 2)
                vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
                
                vDSP_destroy_fftsetup(fftSetup)
                
                // Map magnitudes to 64 spectrum bars
                let barCount = 64
                let binsPerBar = (fftSize / 2) / barCount
                var newSpectrum = [Float](repeating: 0, count: barCount)
                
                for i in 0..<barCount {
                    let start = i * binsPerBar
                    let end = (i + 1) * binsPerBar
                    let average = magnitudes[start..<end].reduce(0, +) / Float(binsPerBar)
                    // Scale and cap for UI
                    let scaled = min(15, max(2, sqrt(average) * 200)) // Increased gain for better visibility
                    newSpectrum[i] = scaled
                }
                
                Task { @MainActor in
                    self.spectrum = newSpectrum
                }
            }
        }
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying { self.togglePlay(); return .success }
            return .commandFailed
        }
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying { self.togglePlay(); return .success }
            return .commandFailed
        }
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.togglePlay(); return .success
        }
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next(); return .success
        }
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.prev(); return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.name
        info[MPMediaItemPropertyArtist] = "Winamp"
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
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
        
        playerNode.stop()
        isPlaying = false
        
        do {
            audioFile = try AVAudioFile(forReading: track.url)
            duration = Double(audioFile!.length) / audioFile!.fileFormat.sampleRate
            
            if !engine.isRunning { try engine.start() }
            
            scheduleFile()
            updateNowPlayingInfo()
            
            if isPlaying {
                playerNode.play()
            }
            
            startTimeObserver()
        } catch {
            print("Audio Load Error: \(error)")
        }
    }
    
    private func scheduleFile() {
        guard let file = audioFile else { return }
        playerNode.scheduleFile(file, at: nil) { [weak self] in
            Task { @MainActor in
                if let self = self, self.isPlaying {
                    self.next()
                }
            }
        }
    }
    
    private func startTimeObserver() {
        timeObserverTimer?.cancel()
        timeObserverTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self, self.isPlaying, !self.isScrubbing else { return }
            if let nodeTime = self.playerNode.lastRenderTime,
               let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                self.currentTime = Double(playerTime.sampleTime) / playerTime.sampleRate
                self.updateNowPlayingInfo()
            }
        }
    }
    
    func togglePlay() {
        if isPlaying {
            playerNode.pause()
        } else {
            if !engine.isRunning { try? engine.start() }
            playerNode.play()
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
    }
    
    func stop() {
        playerNode.stop()
        isPlaying = false
        currentTime = 0
        spectrum = Array(repeating: 0, count: 64)
        updateNowPlayingInfo()
    }
    
    func next() {
        guard !filteredPlaylist.isEmpty else { return }
        var nextIndex: Int
        if isShuffle && filteredPlaylist.count > 1 {
            repeat { nextIndex = Int.random(in: 0..<filteredPlaylist.count) } while nextIndex == currentIndexInFiltered
        } else {
            nextIndex = (currentIndexInFiltered + 1) % filteredPlaylist.count
        }
        loadTrack(at: nextIndex)
    }
    
    func prev() {
        guard !filteredPlaylist.isEmpty else { return }
        var prevIndex: Int
        if isShuffle && filteredPlaylist.count > 1 {
            repeat { prevIndex = Int.random(in: 0..<filteredPlaylist.count) } while prevIndex == currentIndexInFiltered
        } else {
            prevIndex = (currentIndexInFiltered - 1 + filteredPlaylist.count) % filteredPlaylist.count
        }
        loadTrack(at: prevIndex)
    }
    
    func seek(to seconds: Double) {
        guard let file = audioFile else { return }
        let sampleRate = file.fileFormat.sampleRate
        let startSample = AVAudioFramePosition(seconds * sampleRate)
        let framesToPlay = AVAudioFrameCount(file.length - startSample)
        
        if framesToPlay > 0 {
            playerNode.stop()
            playerNode.scheduleSegment(file, startingFrame: startSample, frameCount: framesToPlay, at: nil, completionHandler: nil)
            if isPlaying { playerNode.play() }
            currentTime = seconds
            updateNowPlayingInfo()
        }
    }
    
    func clearPlaylist() {
        stop()
        playlist.removeAll()
        currentIndexInFiltered = -1
        currentTime = 0
        duration = 0
        updateNowPlayingInfo()
    }
}
