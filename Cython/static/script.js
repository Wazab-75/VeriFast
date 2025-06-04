// Store current view parameters
const currentView = {
    zoom: 1.0,
    center_x: -0.5,
    center_y: 0
};

let isGenerating = false;
let isInitialized = false;
let lastClickTime = 0;
let currentVersion = 'software'; // Default to software version

// Update value displays for range inputs
document.querySelectorAll('input[type="range"]').forEach(input => {
    const display = input.nextElementSibling;
    input.addEventListener('input', () => {
        display.textContent = input.value;
    });
});

function handleVersionChange() {
    const versionSelect = document.getElementById('versionSelect');
    const generateButton = document.getElementById('generateButton');
    const iterationsInput = document.getElementById('iterations');
    const mandelbrotImage = document.getElementById('mandelbrotImage');
    const juliaImage = document.getElementById('juliaImage');
    const loadingMessage = document.querySelector('.mandelbrot-widget .loading-message');
    const computationTime = document.getElementById('computationTime');
    const juliaComputationTime = document.getElementById('juliaComputationTime');
    
    currentVersion = versionSelect.value;
    
    // Reset images and messages
    mandelbrotImage.style.display = 'none';
    juliaImage.style.display = 'none';
    loadingMessage.style.display = 'flex';
    loadingMessage.textContent = 'Click "Generate Fractal" to start';
    computationTime.textContent = '';
    juliaComputationTime.textContent = '';
    
    if (currentVersion === 'hardware') {
        if (!FPGA_AVAILABLE) {
            // Disable hardware mode if FPGA is not available
            versionSelect.value = 'software';
            currentVersion = 'software';
            loadingMessage.textContent = 'FPGA not available - Hardware mode disabled';
            return;
        }
        
        // Disable iterations control in hardware mode
        iterationsInput.disabled = true;
        iterationsInput.value = 100; // Fixed value for hardware
        document.querySelector('.value-display').textContent = '100';
        
        // Enable generate button for hardware mode
        generateButton.disabled = false;
        generateButton.textContent = 'Generate Fractal';
    } else {
        // Enable iterations control in software mode
        iterationsInput.disabled = false;
        generateButton.disabled = false;
        generateButton.textContent = 'Generate Fractal';
    }
}

// Generate Mandelbrot fractal with current parameters
async function generateFractal(keepPrevious = false) {
    if (isGenerating) return;
    isGenerating = true;

    const generateButton = document.getElementById('generateButton');
    const downloadButton = document.getElementById('downloadButton');
    const mandelbrotImg = document.getElementById('mandelbrotImage');
    const loadingMessage = document.querySelector('.mandelbrot-widget .loading-message');
    const timeDisplay = document.getElementById('computationTime');

    generateButton.disabled = true;
    downloadButton.disabled = true;
    
    if (!keepPrevious) {
        mandelbrotImg.style.display = 'none';
        loadingMessage.style.display = 'flex';
    } else {
        // Create a temporary image for the new view
        const tempImg = document.createElement('img');
        tempImg.style.position = 'absolute';
        tempImg.style.top = '0';
        tempImg.style.left = '0';
        tempImg.style.width = '100%';
        tempImg.style.height = '100%';
        tempImg.style.opacity = '0';
        tempImg.style.transition = 'opacity 0.3s ease-in-out';
        mandelbrotImg.parentElement.appendChild(tempImg);
    }

    try {
        const startTime = performance.now();
        const response = await fetch('/generate', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                width: 800,
                height: 600,
                max_iter: parseInt(document.getElementById('iterations').value),
                zoom: currentView.zoom,
                center_x: currentView.center_x,
                center_y: currentView.center_y,
                cmap: document.getElementById('colorScheme').value,
                version: currentVersion // Add version to the request
            })
        });

        if (!response.ok) throw new Error(await response.text());

        const blob = await response.blob();
        if (blob.size === 0) throw new Error('Received empty image');

        const endTime = performance.now();
        const computationTime = (endTime - startTime) / 1000; // Convert to seconds
        timeDisplay.textContent = `Computation time: ${computationTime.toFixed(3)}s`;

        if (keepPrevious) {
            const tempImg = mandelbrotImg.parentElement.lastElementChild;
            tempImg.src = URL.createObjectURL(blob);
            tempImg.onload = () => {
                tempImg.style.opacity = '1';
                setTimeout(() => {
                    mandelbrotImg.src = tempImg.src;
                    mandelbrotImg.style.display = 'block';
                    tempImg.remove();
                }, 200); // 200ms delay for transition
            };
        } else {
            mandelbrotImg.src = URL.createObjectURL(blob);
            mandelbrotImg.style.display = 'block';
        }
        
        loadingMessage.style.display = 'none';
        downloadButton.disabled = false;
        generateButton.disabled = false;
        isInitialized = true;
    } catch (error) {
        console.error('Error:', error);
        generateButton.disabled = false;
        downloadButton.disabled = true;
        loadingMessage.textContent = `Generation failed: ${error.message}`;
        loadingMessage.style.display = 'flex';
        timeDisplay.textContent = 'Computation failed';
    } finally {
        isGenerating = false;
    }
}

// Generate Julia set from click coordinates
async function generateJuliaFromClick(cx, cy) {
    if (isGenerating) return;
    isGenerating = true;

    const juliaContainer = document.getElementById('juliaContainer');
    const currentImage = juliaContainer.querySelector('img');
    const juliaTimeDisplay = document.getElementById('juliaComputationTime');
    
    try {
        const startTime = performance.now();
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
                center_x: cx,
                center_y: cy,
                cmap: document.getElementById('colorScheme').value
            })
        });

        if (!response.ok) throw new Error(await response.text());

        const blob = await response.blob();
        if (blob.size === 0) throw new Error('Empty Julia image');

        const endTime = performance.now();
        const computationTime = (endTime - startTime) / 1000; // Convert to seconds
        juliaTimeDisplay.textContent = `Computation time: ${computationTime.toFixed(3)}s`;

        // Create new image element
        const newImage = new Image();
        newImage.className = 'julia-image';
        newImage.alt = 'Julia Set';
        
        // Start transition immediately
        if (currentImage) {
            currentImage.style.opacity = '0';
            setTimeout(() => currentImage.remove(), 300);
        }
        juliaContainer.appendChild(newImage);
        newImage.style.opacity = '1';

        // Load the image after starting the transition
        newImage.src = URL.createObjectURL(blob);
    } catch (error) {
        console.error('Julia generation failed:', error);
        juliaTimeDisplay.textContent = 'Computation failed';
    } finally {
        isGenerating = false;
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

// Handle image click for zoom and Julia
document.getElementById('mandelbrotImage').addEventListener('mousedown', async (event) => {
    if (isGenerating || !isInitialized) return;
    
    const img = event.target;
    const { c_real, c_imag } = getComplexFromMouse(event, img);

    // Update Mandelbrot zoom
    currentView.center_x = c_real;
    currentView.center_y = c_imag;
    currentView.zoom *= 3;

    await generateFractal(true); // Keep previous image during zoom
    await generateJuliaFromClick(c_real, c_imag);
});

// Live Julia on mouse move
let debounceTimer = null;
document.getElementById('mandelbrotImage').addEventListener('mousemove', (event) => {
    if (!isInitialized) return;
    
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
        const img = event.target;
        const { c_real, c_imag } = getComplexFromMouse(event, img);
        generateJuliaFromClick(c_real, c_imag);
    }, 150);
});

// Handle generate button
document.getElementById('generateButton').addEventListener('click', () => generateFractal(false));

// Handle download button
const downloadButton = document.getElementById('downloadButton');
const qualityDropdown = document.getElementById('qualityDropdown');

downloadButton.addEventListener('click', () => {
    qualityDropdown.classList.toggle('show');
});

// Handle quality selection
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

document.addEventListener('DOMContentLoaded', function() {
    // Get DOM elements
    const mandelbrotImage = document.getElementById('mandelbrotImage');
    const juliaImage = document.getElementById('juliaImage');
    const generateButton = document.getElementById('generateButton');
    const qualityButton = document.getElementById('qualityButton');
    const qualityDropdown = document.getElementById('qualityDropdown');
    const qualityOptions = document.querySelectorAll('.quality-option');
    const loadingMessage = document.getElementById('loadingMessage');
    const computationTime = document.getElementById('computationTime');
    const fpgaStatus = document.getElementById('fpgaStatus');

    // Get all input elements
    const inputs = document.querySelectorAll('input[type="range"], select');
    let debounceTimer;

    // Function to generate Mandelbrot
    async function generateMandelbrot() {
        try {
            loadingMessage.style.display = 'flex';
            computationTime.textContent = '';

            const params = {
                version: 'hardware',
                width: 640,
                height: 480,
                max_iter: parseInt(document.getElementById('iterations').value),
                zoom: parseFloat(document.getElementById('zoom').value),
                center_x: parseFloat(document.getElementById('centerX').value),
                center_y: parseFloat(document.getElementById('centerY').value),
                cmap: document.getElementById('colormap').value
            };

            const response = await fetch('/generate', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(params)
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const blob = await response.blob();
            const imageUrl = URL.createObjectURL(blob);
            mandelbrotImage.src = imageUrl;
            mandelbrotImage.onload = () => {
                loadingMessage.style.display = 'none';
                URL.revokeObjectURL(imageUrl);
            };
        } catch (error) {
            console.error('Error:', error);
            loadingMessage.textContent = 'Error generating image. Please try again.';
        }
    }

    // Function to generate Julia
    async function generateJulia() {
        try {
            const params = {
                version: 'hardware',
                width: 640,
                height: 480,
                max_iter: parseInt(document.getElementById('iterations').value),
                zoom: parseFloat(document.getElementById('zoom').value),
                center_x: parseFloat(document.getElementById('centerX').value),
                center_y: parseFloat(document.getElementById('centerY').value),
                cmap: document.getElementById('colormap').value
            };

            const response = await fetch('/generate_julia', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(params)
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const blob = await response.blob();
            const imageUrl = URL.createObjectURL(blob);
            juliaImage.src = imageUrl;
            juliaImage.onload = () => {
                URL.revokeObjectURL(imageUrl);
            };
        } catch (error) {
            console.error('Error:', error);
        }
    }

    // Function to handle input changes with debounce
    function handleInputChange() {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            generateMandelbrot();
            generateJulia();
        }, 500); // 500ms debounce
    }

    // Add event listeners to all inputs
    inputs.forEach(input => {
        input.addEventListener('input', handleInputChange);
    });

    // Quality dropdown functionality
    qualityButton.addEventListener('click', function() {
        qualityDropdown.classList.toggle('show');
    });

    qualityOptions.forEach(option => {
        option.addEventListener('click', function() {
            const quality = this.getAttribute('data-quality');
            qualityButton.textContent = this.textContent;
            qualityDropdown.classList.remove('show');
            handleInputChange();
        });
    });

    // Close dropdown when clicking outside
    document.addEventListener('click', function(event) {
        if (!event.target.matches('#qualityButton')) {
            qualityDropdown.classList.remove('show');
        }
    });

    // Initial generation
    generateMandelbrot();
    generateJulia();
});
