document.addEventListener('DOMContentLoaded', () => {
    const visualizer = document.getElementById('visualizer');
    const playPauseBtn = document.getElementById('play-pause');
    const trackTitle = document.getElementById('track-title');
    const progressBar = document.getElementById('progress-bar');
    
    let isPlaying = false;
    let barCount = 32;
    let bars = [];

    // Initialize Visualizer Bars
    function initVisualizer() {
        visualizer.innerHTML = '';
        bars = [];
        for (let i = 0; i < barCount; i++) {
            const bar = document.createElement('div');
            bar.className = 'vis-bar';
            bar.style.height = '2px';
            visualizer.appendChild(bar);
            bars.push(bar);
        }
    }

    // Animate Visualizer (Simulated FFT)
    function animateVisualizer() {
        if (!isPlaying) {
            bars.forEach(bar => bar.style.height = '2px');
            return;
        }

        bars.forEach((bar, i) => {
            // Simulated frequency mapping
            const targetHeight = Math.random() * 35 + 2;
            bar.style.height = `${targetHeight}px`;
        });

        requestAnimationFrame(animateVisualizer);
    }

    // Play/Pause Toggle
    playPauseBtn.addEventListener('click', () => {
        isPlaying = !isPlaying;
        playPauseBtn.textContent = isPlaying ? 'PAUSE' : 'PLAY';
        playPauseBtn.classList.toggle('active', isPlaying);
        
        if (isPlaying) {
            animateVisualizer();
        }
    });

    // Handle Drag & Drop
    const container = document.getElementById('winamp-container');
    
    container.addEventListener('dragover', (e) => {
        e.preventDefault();
        container.style.boxShadow = '0 0 40px rgba(0, 136, 255, 0.4)';
    });

    container.addEventListener('dragleave', () => {
        container.style.boxShadow = '';
    });

    container.addEventListener('drop', (e) => {
        e.preventDefault();
        container.style.boxShadow = '';
        const files = Array.from(e.dataTransfer.files);
        if (files.length > 0) {
            trackTitle.textContent = `Loaded: ${files[0].name}`;
            isPlaying = true;
            playPauseBtn.textContent = 'PAUSE';
            playPauseBtn.classList.add('active');
            animateVisualizer();
        }
    });

    initVisualizer();
});
