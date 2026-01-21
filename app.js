/**
 * Winamp 2026 Core Logic
 * Focus: Pure file playback, temporary queue, high-end visuals.
 */

class WinampPlayer {
    constructor() {
        this.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        this.analyser = this.audioCtx.createAnalyser();
        this.gainNode = this.audioCtx.createGain();
        
        // Audio Graph: Source -> Analyser -> Gain -> Destination
        this.analyser.connect(this.gainNode);
        this.gainNode.connect(this.audioCtx.destination);
        
        this.analyser.fftSize = 256;
        this.bufferLength = this.analyser.frequencyBinCount;
        this.dataArray = new Uint8Array(this.bufferLength);

        this.playlist = [];
        this.currentIndex = -1;
        this.isPlaying = false;
        this.audioElement = new Audio();
        this.source = null;

        // Connect audio element to Web Audio API
        this.source = this.audioCtx.createMediaElementSource(this.audioElement);
        this.source.connect(this.analyser);

        this.initDOM();
        this.initEvents();
        this.animate();
    }

    initDOM() {
        this.canvas = document.getElementById('visualizer');
        this.ctx = this.canvas.getContext('2d');
        this.playBtn = document.getElementById('play-btn');
        this.pauseBtn = document.getElementById('pause-btn');
        this.stopBtn = document.getElementById('stop-btn');
        this.prevBtn = document.getElementById('prev-btn');
        this.nextBtn = document.getElementById('next-btn');
        this.progressBar = document.getElementById('progress-bar');
        this.volumeSlider = document.getElementById('volume-slider');
        this.playlistContainer = document.getElementById('playlist-container');
        this.trackNameDisplay = document.getElementById('track-name');
        this.timeDisplay = document.getElementById('time-display');
        this.statusDisplay = document.getElementById('player-status');
        this.fileInput = document.getElementById('file-input');
        this.addBtn = document.getElementById('add-btn');
        this.clearBtn = document.getElementById('clear-btn');
        this.dropZone = document.getElementById('drop-zone');

        // Initial canvas size
        this.resizeCanvas();
        window.addEventListener('resize', () => this.resizeCanvas());
    }

    resizeCanvas() {
        this.canvas.width = this.canvas.clientWidth;
        this.canvas.height = this.canvas.clientHeight;
    }

    initEvents() {
        this.playBtn.addEventListener('click', () => this.play());
        this.pauseBtn.addEventListener('click', () => this.pause());
        this.stopBtn.addEventListener('click', () => this.stop());
        this.prevBtn.addEventListener('click', () => this.prev());
        this.nextBtn.addEventListener('click', () => this.next());
        
        this.volumeSlider.addEventListener('input', (e) => {
            this.audioElement.volume = e.target.value;
        });

        this.progressBar.addEventListener('input', (e) => {
            if (this.audioElement.duration) {
                this.audioElement.currentTime = (e.target.value / 100) * this.audioElement.duration;
            }
        });

        this.audioElement.addEventListener('timeupdate', () => this.updateProgress());
        this.audioElement.addEventListener('ended', () => this.next());

        // File handling
        this.addBtn.addEventListener('click', () => this.fileInput.click());
        this.fileInput.addEventListener('change', (e) => this.handleFiles(e.target.files));

        this.clearBtn.addEventListener('click', () => this.clearPlaylist());

        // Drag & Drop
        this.dropZone.addEventListener('dragover', (e) => {
            e.preventDefault();
            this.dropZone.classList.add('drag-over');
        });

        this.dropZone.addEventListener('dragleave', () => {
            this.dropZone.classList.remove('drag-over');
        });

        this.dropZone.addEventListener('drop', (e) => {
            e.preventDefault();
            this.dropZone.classList.remove('drag-over');
            this.handleFiles(e.dataTransfer.files);
        });
    }

    handleFiles(files) {
        const audioFiles = Array.from(files).filter(file => file.type.startsWith('audio/'));
        
        audioFiles.forEach(file => {
            const track = {
                file: file,
                name: file.name.replace(/\.[^/.]+$/, ""),
                url: URL.createObjectURL(file)
            };
            this.playlist.push(track);
        });

        this.renderPlaylist();
        
        if (this.currentIndex === -1 && this.playlist.length > 0) {
            this.loadTrack(0);
        }
    }

    renderPlaylist() {
        if (this.playlist.length === 0) {
            this.playlistContainer.innerHTML = '<div class="empty-msg">DROP MP3 FILES HERE</div>';
            return;
        }

        this.playlistContainer.innerHTML = '';
        this.playlist.forEach((track, index) => {
            const item = document.createElement('div');
            item.className = `track-item ${index === this.currentIndex ? 'active' : ''}`;
            item.innerHTML = `
                <span class="track-name">${index + 1}. ${track.name}</span>
            `;
            item.addEventListener('click', () => this.loadTrack(index, true));
            this.playlistContainer.appendChild(item);
        });
    }

    loadTrack(index, autoPlay = false) {
        if (index < 0 || index >= this.playlist.length) return;

        this.currentIndex = index;
        const track = this.playlist[index];
        
        this.audioElement.src = track.url;
        this.trackNameDisplay.textContent = track.name.toUpperCase();
        this.renderPlaylist();

        if (autoPlay) {
            this.play();
        }
    }

    play() {
        if (this.playlist.length === 0) {
            this.fileInput.click();
            return;
        }
        
        if (this.currentIndex === -1) {
            this.loadTrack(0);
        }

        if (this.audioCtx.state === 'suspended') {
            this.audioCtx.resume();
        }

        this.audioElement.play();
        this.isPlaying = true;
        this.statusDisplay.textContent = 'PLAYING';
    }

    pause() {
        this.audioElement.pause();
        this.isPlaying = false;
        this.statusDisplay.textContent = 'PAUSED';
    }

    stop() {
        this.audioElement.pause();
        this.audioElement.currentTime = 0;
        this.isPlaying = false;
        this.statusDisplay.textContent = 'STOPPED';
    }

    prev() {
        let index = this.currentIndex - 1;
        if (index < 0) index = this.playlist.length - 1;
        this.loadTrack(index, true);
    }

    next() {
        let index = this.currentIndex + 1;
        if (index >= this.playlist.length) index = 0;
        this.loadTrack(index, true);
    }

    updateProgress() {
        const current = this.audioElement.currentTime;
        const total = this.audioElement.duration;
        if (total) {
            this.progressBar.value = (current / total) * 100;
            this.timeDisplay.textContent = this.formatTime(current);
        }
    }

    formatTime(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = Math.floor(seconds % 60);
        return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    }

    clearPlaylist() {
        this.stop();
        this.playlist.forEach(track => URL.revokeObjectURL(track.url));
        this.playlist = [];
        this.currentIndex = -1;
        this.trackNameDisplay.textContent = 'NO FILE LOADED';
        this.timeDisplay.textContent = '00:00';
        this.renderPlaylist();
    }

    animate() {
        requestAnimationFrame(() => this.animate());
        
        this.analyser.getByteFrequencyData(this.dataArray);
        
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        
        const barWidth = (this.canvas.width / this.bufferLength) * 2.5;
        let barHeight;
        let x = 0;

        for (let i = 0; i < this.bufferLength; i++) {
            barHeight = (this.dataArray[i] / 255) * this.canvas.height;

            const gradient = this.ctx.createLinearGradient(0, this.canvas.height, 0, 0);
            gradient.addColorStop(0, '#00f2ff');
            gradient.addColorStop(1, '#ffbc00');

            this.ctx.fillStyle = gradient;
            this.ctx.fillRect(x, this.canvas.height - barHeight, barWidth - 1, barHeight);

            x += barWidth;
        }
    }
}

// Initialize player when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.player = new WinampPlayer();
});
