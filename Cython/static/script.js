// Store current view parameters
const currentView = {
    zoom: 1.0,
    center_x: -0.5,
    center_y: 0
};

let debounceTimer = null;

// Update value displays for range inputs
document.querySelectorAll('input[type="range"]').forEach(input => {
    const display = input.nextElementSibling;
    input.addEventListener('input', () => {
        display.textContent = input.value;
    });
});

// Generate Mandelbrot fractal with current parameters
async function generateFractal() {
    const generateButton = document.getElementById('generateButton');
    const downloadButton = document.getElementById('downloadButton');
    const mandelbrotImg = document.getElementById('mandelbrotImage');
    const loadingMessage = document.querySelector('.mandelbrot-widget .loading-message');

    generateButton.disabled = true;
    downloadButton.disabled = true;
    mandelbrotImg.style.display = 'none';
    loadingMessage.style.display = 'flex';

    try {
        const response = await fetch('/generate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                width: 800,
                height: 600,
                max_iter: parseInt(document.getElementById('iterations').value),
                zoom: currentView.zoom,
                center_x: currentView.center_x,
                center_y: currentView.center_y,
                cmap: document.getElementById('colorScheme').value
            })
        });

        if (!response.ok) throw new Error(await response.text());

        const blob = await response.blob();
        if (blob.size === 0) throw new Error('Received empty image');

        mandelbrotImg.src = URL.createObjectURL(blob);
        mandelbrotImg.style.display = 'block';
        loadingMessage.style.display = 'none';
        downloadButton.disabled = false;
        generateButton.disabled = false;
    } catch (error) {
        console.error('Error:', error);
        generateButton.disabled = false;
        downloadButton.disabled = true;
        loadingMessage.textContent = `Generation failed: ${error.message}`;
        loadingMessage.style.display = 'flex';
    }
}

// Generate Julia fractal from Mandelbrot cursor
async function generateJuliaFromCursor(c_real, c_imag) {
    const juliaImg = document.getElementById('juliaImage');
    const juliaLoading = document.getElementById('juliaLoading');
    const label = document.getElementById('juliaLabel');

    juliaImg.style.display = 'none';
    juliaLoading.textContent = 'Generating Julia Set...';
    juliaLoading.style.display = 'flex';
    label.textContent = `c = ${c_real.toFixed(4)} + ${c_imag.toFixed(4)}i`;

    try {
        const response = await fetch('/generate_julia', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                width: 400,
                height: 300,
                max_iter: parseInt(document.getElementById('iterations').value),
                zoom: 1.5,
                zx: 0.0,
                zy: 0.0,
                center_x: c_real,
                center_y: c_imag,
                cmap: document.getElementById('colorScheme').value
            })
        });

        if (!response.ok) throw new Error(await response.text());

        const blob = await response.blob();
        if (blob.size === 0) throw new Error('Empty Julia image');

        juliaImg.src = URL.createObjectURL(blob);
        juliaImg.style.display = 'block';
        juliaLoading.style.display = 'none';
    } catch (error) {
        console.error('Julia generation failed:', error);
        juliaLoading.textContent = `Julia generation failed: ${error.message}`;
    }
}

// Convert mouse position to complex coordinates
function getComplexFromMouse(event, img) {
    const rect = img.getBoundingClientRect();
    const x = (event.clientX - rect.left) / rect.width;
    const y = (event.clientY - rect.top) / rect.height;

    const scale_x = 3.5 / currentView.zoom;
    const scale_y = 2.0 / currentView.zoom;

    const c_real = currentView.center_x - scale_x / 2 + scale_x * x;
    const c_imag = currentView.center_y - scale_y / 2 + scale_y * y;

    return { c_real, c_imag };
}

// Live Julia on mouse move
document.getElementById('mandelbrotImage').addEventListener('mousemove', (event) => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
        const img = event.target;
        const { c_real, c_imag } = getComplexFromMouse(event, img);
        generateJuliaFromCursor(c_real, c_imag);
    }, 150); // adjust for responsiveness vs. server load
});

// Zoom + Julia on click
document.getElementById('mandelbrotImage').addEventListener('click', async (event) => {
    const img = event.target;
    const { c_real, c_imag } = getComplexFromMouse(event, img);

    currentView.center_x = c_real;
    currentView.center_y = c_imag;
    currentView.zoom *= 2;

    await generateFractal();
    await generateJuliaFromCursor(c_real, c_imag);
});

// Generate button
document.getElementById('generateButton').addEventListener('click', generateFractal);

// Download quality
const downloadButton = document.getElementById('downloadButton');
const qualityDropdown = document.getElementById('qualityDropdown');

downloadButton.addEventListener('click', () => {
    qualityDropdown.classList.toggle('show');
});

document.querySelectorAll('.quality-option').forEach(option => {
    option.addEventListener('click', async () => {
        const quality = option.dataset.quality;
        const dimensions = {
            low: [800, 600],
            medium: [1600, 1200],
            high: [3200, 2400],
            ultra: [6400, 4800]
        }[quality];

        try {
            const response = await fetch('/generate', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    width: dimensions[0],
                    height: dimensions[1],
                    max_iter: parseInt(document.getElementById('iterations').value),
                    zoom: currentView.zoom,
                    center_x: currentView.center_x,
                    center_y: currentView.center_y,
                    cmap: document.getElementById('colorScheme').value
                })
            });

            if (response.ok) {
                const blob = await response.blob();
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `mandelbrot_${quality}.png`;
                document.body.appendChild(a);
                a.click();
                window.URL.revokeObjectURL(url);
                a.remove();
            }
        } catch (error) {
            console.error('Download failed:', error);
        }
        qualityDropdown.classList.remove('show');
    });
});

// Close dropdown when clicking outside
document.addEventListener('click', (event) => {
    if (!event.target.closest('.button-container')) {
        qualityDropdown.classList.remove('show');
    }
});
