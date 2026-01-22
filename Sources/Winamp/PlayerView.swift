import SwiftUI
import AppKit

struct WinampColors {
    static let bg = Color(red: 45/255, green: 45/255, blue: 68/255)
    static let innerBg = Color.black
    static let text = Color.green
    static let dimText = Color(red: 0, green: 0.3, blue: 0)
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .underWindowBackground
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct PlayerView: View {
    @StateObject var vm = PlayerViewModel()
    
    var body: some View {
        ZStack {
            VisualEffectView()
                .ignoresSafeArea()
            
            Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Title Bar / Drag Area
                HStack {
                    Text("WINAMP")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.leading, 8)
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: { NSApplication.shared.keyWindow?.miniaturize(nil) }) {
                            Text("_").font(.system(size: 10))
                        }.buttonStyle(PlainButtonStyle())
                        
                        Button(action: { NSApplication.shared.terminate(nil) }) {
                            Text("X").font(.system(size: 10))
                        }.buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 8)
                    }
                }
                .frame(height: 20)
                .background(Color.blue.opacity(0.3))
                .gesture(DragGesture().onChanged { value in
                    NSApplication.shared.keyWindow?.performDrag(with: NSApplication.shared.currentEvent!)
                })

                // Main Player Area
                VStack(spacing: 12) {
                    // LCD Display Area - Responsive Width
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.isPlaying ? "▶" : "||")
                                .font(.system(size: 10))
                                .foregroundColor(WinampColors.text)
                            
                            Text(formatTime(vm.currentTime))
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(WinampColors.text)
                        }
                        .frame(width: 80)
                        .padding(5)
                        .background(WinampColors.innerBg)
                        .border(Color.gray, width: 1)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vm.currentTrack?.name.uppercased() ?? "WINAMP 2026")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(WinampColors.text)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack {
                                Text("192 kbps")
                                Text("44 kHz")
                                Spacer()
                                Text("stereo").foregroundColor(.green)
                            }
                            .font(.system(size: 9))
                            .foregroundColor(WinampColors.text.opacity(0.7))
                            
                            // Real animated spectrum bars - Adaptive count
                            GeometryReader { geo in
                                HStack(alignment: .bottom, spacing: 1) {
                                    let barCount = Int(geo.size.width / 3)
                                    ForEach(0..<max(1, barCount), id: \.self) { i in
                                        Rectangle()
                                            .fill(WinampColors.text)
                                            .frame(width: 2, height: i < vm.spectrum.count ? CGFloat(vm.spectrum[i]) : CGFloat.random(in: 2...12))
                                    }
                                }
                            }
                            .frame(height: 15)
                        }
                    }
                    .padding(10)
                    .background(WinampColors.innerBg)
                    .border(Color.gray.opacity(0.3), width: 1)
                    
                    // Progress Slider
                    VStack(spacing: 4) {
                        Slider(value: $vm.currentTime, in: 0...(vm.duration > 0 ? vm.duration : 1), onEditingChanged: { editing in
                            vm.isScrubbing = editing
                            if !editing {
                                vm.seek(to: vm.currentTime)
                            }
                        })
                        .accentColor(.green)
                    }
                    
                    // Transport Controls - Responsive spacing
                    HStack(spacing: 5) {
                        transportButton(label: "|<<") { vm.prev() }
                        
                        Button(action: { vm.togglePlay() }) {
                            Text(vm.isPlaying ? "PAUSE" : "PLAY")
                                .font(.system(size: 10, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 18)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.white)
                                .border(Color.white.opacity(0.1), width: 1)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .keyboardShortcut(.space, modifiers: [])
                        
                        transportButton(label: ">>|") { vm.next() }
                        
                        Button(action: { vm.isShuffle.toggle() }) {
                            Text("SHUFFLE")
                                .font(.system(size: 8))
                                .padding(4)
                                .background(vm.isShuffle ? Color.green.opacity(0.2) : Color.black)
                                .foregroundColor(vm.isShuffle ? .green : .gray)
                                .border(vm.isShuffle ? Color.green.opacity(0.5) : Color.gray.opacity(0.3), width: 1)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(12)
                .background(WinampColors.bg.opacity(0.9))
                
                // Playlist Area - Responsive Height and Width
                VStack(spacing: 0) {
                    // Search Field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        TextField("Search tracks...", text: $vm.searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    .padding(5)
                    .background(Color.black.opacity(0.5))
                    .border(Color.gray.opacity(0.3), width: 1)

                    HStack {
                        Text("WINAMP PLAYLIST")
                            .font(.system(size: 10, weight: .bold))
                        Spacer()
                        Text("\(vm.filteredPlaylist.count) TRACKS")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.4))
                    
                    List {
                        if vm.filteredPlaylist.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: vm.searchText.isEmpty ? "plus.circle" : "questionmark.circle")
                                    .font(.title)
                                Text(vm.searchText.isEmpty ? "DRAG & DROP MP3s HERE" : "NO MATCHES FOUND")
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            .foregroundColor(.green.opacity(0.5))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 40)
                            .listRowBackground(Color.black)
                        } else {
                            ForEach(Array(vm.filteredPlaylist.enumerated()), id: \.element.id) { index, track in
                                HStack {
                                    Text("\(index + 1). \(track.name)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(vm.currentIndexInFiltered == index ? .white : .green)
                                    Spacer()
                                }
                                .padding(.vertical, 1)
                                .contentShape(Rectangle()) // Make the whole row clickable
                                .onTapGesture {
                                    vm.loadTrack(at: index)
                                    if !vm.isPlaying { vm.togglePlay() }
                                }
                                .contextMenu {
                                    Button("Copy Path") {
                                        let pasteboard = NSPasteboard.general
                                        pasteboard.clearContents()
                                        pasteboard.setString(track.url.path, forType: .string)
                                    }
                                    
                                    Button("Reveal in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([track.url])
                                    }
                                }
                                .listRowBackground(vm.currentIndexInFiltered == index ? Color.blue.opacity(0.4) : Color.black)
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
                        Button("ADD") { vm.addFiles(urls: []) }
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
            .border(Color.white.opacity(0.1), width: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
    }
    
    private func transportButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 18)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.white)
                .border(Color.white.opacity(0.1), width: 1)
        }
        .buttonStyle(PlainButtonStyle())
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
