import SwiftUI

struct WinampColors {
    static let bg = Color(red: 45/255, green: 45/255, blue: 68/255)
    static let innerBg = Color.black
    static let text = Color.green
    static let dimText = Color(red: 0, green: 0.3, blue: 0)
}

struct PlayerView: View {
    @StateObject var vm = PlayerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Player Area
            VStack(spacing: 10) {
                // LCD Display Area
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.isPlaying ? "▶" : "■")
                            .font(.system(size: 10))
                            .foregroundColor(WinampColors.text)
                        
                        Text(formatTime(vm.currentTime))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(WinampColors.text)
                    }
                    .frame(width: 80)
                    .padding(5)
                    .background(WinampColors.innerBg)
                    .border(Color.gray, width: 1)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(vm.currentIndex >= 0 ? "\(vm.currentIndex + 1). \(vm.playlist[vm.currentIndex].name.uppercased())" : "WINAMP 2026")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(WinampColors.text)
                            .lineLimit(1)
                        
                        HStack {
                            Text("192 kbps")
                            Text("44 kHz")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(WinampColors.text.opacity(0.7))
                        
                        // Fake visualizer bars
                        HStack(alignment: .bottom, spacing: 1) {
                            ForEach(0..<20) { _ in
                                Rectangle()
                                    .fill(WinampColors.text)
                                    .frame(width: 3, height: CGFloat.random(in: 2...15))
                            }
                        }
                    }
                }
                .padding(10)
                .background(WinampColors.innerBg)
                .cornerRadius(4)
                
                // Sliders
                VStack(spacing: 5) {
                    Slider(value: $vm.currentTime, in: 0...(vm.duration > 0 ? vm.duration : 1)) { _ in
                        vm.seek(to: vm.currentTime)
                    }
                    .accentColor(.gray)
                    
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10))
                        Slider(value: Binding(get: { Double(vm.volume) }, set: { vm.volume = Float($0) }), in: 0...1)
                            .accentColor(.gray)
                    }
                }
                
                // Transport Controls
                HStack(spacing: 2) {
                    ForEach(["|<<", "▶", "||", "■", ">>|"], id: \.self) { label in
                        Button(action: {
                            handleTransport(label)
                        }) {
                            Text(label)
                                .font(.system(size: 10, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 20)
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .border(Color.gray.opacity(0.5), width: 1)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Button(action: { vm.isShuffle.toggle() }) {
                        Text("SHUFFLE")
                            .font(.system(size: 8))
                            .padding(4)
                            .background(vm.isShuffle ? Color.green.opacity(0.3) : Color.black)
                            .foregroundColor(vm.isShuffle ? .green : .gray)
                            .border(vm.isShuffle ? Color.green : Color.gray, width: 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(15)
            .background(WinampColors.bg)
            
            // Playlist Area
            VStack(spacing: 0) {
                HStack {
                    Text("WINAMP PLAYLIST")
                        .font(.system(size: 10, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.5))
                
                List {
                    if vm.playlist.isEmpty {
                        Text("DRAG & DROP MP3s HERE")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.green.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.black)
                    } else {
                        ForEach(Array(vm.playlist.enumerated()), id: \.element.id) { index, track in
                            HStack {
                                Text("\(index + 1). \(track.name)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(vm.currentIndex == index ? .white : .green)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                            .onTapGesture {
                                vm.loadTrack(at: index)
                                vm.togglePlay()
                            }
                            .listRowBackground(vm.currentIndex == index ? Color.blue.opacity(0.5) : Color.black)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .background(Color.black)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                    return true
                }
                
                HStack {
                    Button("ADD") { /* Local file picker would go here */ }
                    Button("CLR") { vm.clearPlaylist() }
                    Spacer()
                    Text("\(formatTime(vm.currentTime)) / \(formatTime(vm.duration))")
                        .font(.system(size: 10))
                }
                .padding(5)
                .background(Color(white: 0.1))
                .font(.system(size: 8))
            }
            .frame(minHeight: 150)
        }
        .frame(width: 275)
        .preferredColorScheme(.dark)
    }
    
    private func handleTransport(_ label: String) {
        switch label {
        case "|<<": vm.prev()
        case "▶": if !vm.isPlaying { vm.togglePlay() }
        case "||": if vm.isPlaying { vm.togglePlay() }
        case "■": vm.stop()
        case ">>|": vm.next()
        default: break
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url {
                    DispatchQueue.main.async {
                        vm.addFiles(urls: [url])
                    }
                }
            }
        }
    }
}
