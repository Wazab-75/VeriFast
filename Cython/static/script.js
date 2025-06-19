// Store current view parameters
const currentView = {
    zoom: 1.0,
    center_x: -0.5,
    center_y: 0
};

// Function to update zoom ratio display
function updateZoomRatio() {
    const zoomRatio = document.getElementById('zoomRatio');
    zoomRatio.textContent = `${currentView.zoom.toFixed(1)}x`;
}

// Add coordinate display
const coordDisplay = document.createElement('div');
coordDisplay.style.cssText = 'position: absolute; top: 10px; right: 10px; background: rgba(0,0,0,0.7); color: white; padding: 5px; border-radius: 4px; font-family: monospace;';
document.getElementById('mandelbrotContainer').appendChild(coordDisplay);

// Update coordinates on mouse move
document.getElementById('mandelbrotImage').addEventListener('mousemove', (event) => {
    if (!isInitialized) return;
    const { c_real, c_imag } = getComplexFromMouse(event, event.target);
    coordDisplay.textContent = `${c_real.toFixed(4)} + ${c_imag.toFixed(4)}i`;
});

// Clear coordinates when mouse leaves
document.getElementById('mandelbrotImage').addEventListener('mouseleave', () => {
    coordDisplay.textContent = '';
});

// Function to reset zoom and view to original parameters
function resetZoom() {
    currentView.zoom = 1.0;
    currentView.center_x = -0.5;
    currentView.center_y = 0;
    updateZoomRatio();
    generateFractal(false);
}

let isGenerating = false;
let isInitialized = false;

document.getElementById('resetZoomButton').addEventListener('click', resetZoom);

// Update value displays for range inputs
document.querySelectorAll('input[type="range"]').forEach(input => {
    const display = input.nextElementSibling;
    input.addEventListener('input', () => {
        display.textContent = input.value;
    });
});

let currentVersion = 'software'; // Default to software version

// Resolution selectors
const softwareResSelect = document.getElementById('softwareResolution');
const hardwareResSelect = document.getElementById('hardwareResolution');

// Map resolutions to dimensions
const resolutionMap = {
    low: [640, 480],
    medium: [1024, 768],
    high: [3200, 2400],
    ultra: [6400, 4800]
};

function updateResolutionSelectorVisibility() {
    if (currentVersion === 'hardware') {
        softwareResSelect.parentElement.style.display = 'none';
        hardwareResSelect.parentElement.style.display = 'inline-block';
    } else {
        softwareResSelect.parentElement.style.display = 'inline-block';
        hardwareResSelect.parentElement.style.display = 'none';
    }
}

// Handle version change
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
    updateResolutionSelectorVisibility();

    // Reset images and messages
    mandelbrotImage.style.display = 'none';
    juliaImage.style.display = 'none';
    loadingMessage.style.display = 'flex';
    loadingMessage.textContent = 'Click "Generate Fractal" to start';
    computationTime.textContent = '';
    juliaComputationTime.textContent = '';
    
    if (currentVersion === 'hardware' && !FPGA_AVAILABLE) {
        versionSelect.value = 'software';
        currentVersion = 'software';
        loadingMessage.textContent = 'FPGA not available - Hardware mode disabled';
        updateResolutionSelectorVisibility();
        return;
    } 

    // Enable iterations control in software mode
    iterationsInput.disabled = false;
    generateButton.disabled = false;
    generateButton.textContent = 'Generate Fractal';
}

document.getElementById('versionSelect').addEventListener('change', handleVersionChange);

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
        tempImg.style.transition = 'opacity 0.1s ease-in-out';
        mandelbrotImg.parentElement.appendChild(tempImg);
    }

    // Choose resolution based on current version and selection
    let selectedRes = currentVersion === 'hardware' ? 
        hardwareResSelect.value : softwareResSelect.value;
    let dimensions = resolutionMap[selectedRes] || [640, 480];

    const startTime = performance.now();
    const requestStartTime = performance.now();
    
    try {
        const response = await fetch('/generate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                version: currentVersion,
                width: dimensions[0],
                height: dimensions[1],
                max_iter: parseInt(document.getElementById('iterations').value),
                zoom: currentView.zoom,
                center_x: currentView.center_x,
                center_y: currentView.center_y,
                cmap: document.getElementById('colorScheme').value
            })
        });

        const requestEndTime = performance.now();
        const requestDelay = (requestEndTime - requestStartTime) / 1000;

        if (!response.ok) throw new Error(await response.text());
        const blob = await response.blob();
        if (blob.size === 0) throw new Error('Received empty image');

        const endTime = performance.now();
        const totalTime = (endTime - startTime) / 1000;
        const websiteDelay = totalTime - requestDelay;

        // Add to performance data
        performanceData.push({
            type: 'mandelbrot',
            version: currentVersion,
            resolution: `${dimensions[0]}x${dimensions[1]}`,
            computation_time: parseFloat(response.headers.get('X-Computation-Time') || '0'),
            request_delay: requestDelay,
            website_delay: websiteDelay
        });

        // Update computation time display
        timeDisplay.textContent = `Computation time: ${(parseFloat(response.headers.get('X-Computation-Time') || '0')).toFixed(3)}s`;

        // Update the image
        if (keepPrevious) {
            const tempImg = mandelbrotImg.parentElement.lastElementChild;
            tempImg.src = URL.createObjectURL(blob);
            tempImg.onload = () => {
                tempImg.style.opacity = '1';
                setTimeout(() => {
                    mandelbrotImg.src = tempImg.src;
                    mandelbrotImg.style.display = 'block';
                    tempImg.remove();
                }, 300);
            };
        } else {
            mandelbrotImg.src = URL.createObjectURL(blob);
            mandelbrotImg.style.display = 'block';
        }

        loadingMessage.style.display = 'none';
        downloadButton.disabled = false;
        generateButton.disabled = false;
        isInitialized = true;

        if (modal.style.display === 'block') {
            updatePerformanceStats();
        }

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
    // If Mandelbrot is generating, don't generate Julia
    if (isGenerating) return;

    const juliaContainer = document.getElementById('juliaContainer');
    const currentImage = juliaContainer.querySelector('img');
    const juliaTimeDisplay = document.getElementById('juliaComputationTime');
    
    try {
        const startTime = performance.now();
        const response = await fetch('/generate_julia', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                version: currentVersion,
                width: 640,
                height: 480,
                max_iter: parseInt(document.getElementById('iterations').value),
                zoom: 1.0,
                zx: 1.5,
                zy: 2.0,
                center_x: cx,
                center_y: cy,
                cmap: document.getElementById('colorScheme').value
            })
        });

        // If Mandelbrot generation started while we were waiting, abort Julia update
        if (isGenerating) return;

        if (!response.ok) throw new Error(await response.text());

        const blob = await response.blob();
        if (blob.size === 0) throw new Error('Empty Julia image');

        // Check again if Mandelbrot generation started while we were processing
        if (isGenerating) return;

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
    }
}

// Convert mouse position to complex coordinates
function getComplexFromMouse(event, img) {
    const rect = img.getBoundingClientRect();
    const x = (event.clientX - rect.left) / rect.width;
    const y = (event.clientY - rect.top) / rect.height;

    const scale_x = 4.0 / currentView.zoom;
    const aspect_ratio = rect.width/rect.height;
    const scale_y = scale_x / aspect_ratio;

    let c_real, c_imag;

    c_real = currentView.center_x - scale_x /2 + scale_x * x;
    c_imag = currentView.center_y + scale_y /2 - scale_y * y;

    return { c_real, c_imag };
}

// Handle image click for zoom and Julia
document.getElementById('mandelbrotImage').addEventListener('click', async (event) => {
    if (isGenerating || !isInitialized) return;
    
    const img = event.target;
    const rect = img.getBoundingClientRect();
    const x = (event.clientX - rect.left) / rect.width;
    const y = (event.clientY - rect.top) / rect.height;

    const scale_x = 4.0 / currentView.zoom;
    const aspect_ratio = rect.width/rect.height;
    const scale_y = scale_x / aspect_ratio;

    // Calculate the clicked point in complex coordinates
    let c_real, c_imag;

    c_real = currentView.center_x - scale_x / 2 + scale_x * x;
    c_imag = currentView.center_y + scale_y / 2 - scale_y * y;

    // Update to make clicked point the new center
    currentView.center_x = c_real;
    currentView.center_y = c_imag;
    currentView.zoom *= 3;
    updateZoomRatio();

    // Start Mandelbrot generation immediately
    const mandelbrotPromise = generateFractal(true);
    
    generateJuliaFromClick(c_real, c_imag).catch(error => {
        console.error('Julia generation failed:', error);
    });


    // Wait for Mandelbrot to complete
    await mandelbrotPromise;
});

// Live Julia on mouse move
let debounceTimer = null;
let lastJuliaRequest = null;
document.getElementById('mandelbrotImage').addEventListener('mousemove', (event) => {
    if (!isInitialized) return;
    
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
        const img = event.target;
        const { c_real, c_imag } = getComplexFromMouse(event, img);
        
        // Cancel any pending Julia request
        if (lastJuliaRequest) {
            lastJuliaRequest.abort();
        }
        
        // Create new AbortController for this request
        lastJuliaRequest = new AbortController();
        
        // Generate Julia set without waiting
        generateJuliaFromClick(c_real, c_imag).catch(error => {
            if (error.name !== 'AbortError') {
                console.error('Julia generation failed:', error);
            }
        });
    }, 150);
});

// Handle generate button
document.getElementById('generateButton').addEventListener('click', () => generateFractal(false));

// Handle download button
const downloadButton = document.getElementById('downloadButton');

downloadButton.addEventListener('click', async () => {
    try {
        const selectedRes = currentVersion === 'hardware' ? hardwareResSelect.value : softwareResSelect.value;
        const dimensions = resolutionMap[selectedRes] || [640, 480];

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
            a.download = `mandelbrot_${selectedRes}.png`;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            a.remove();
        }
    } catch (error) {
        console.error('Download failed:', error);
    }
});

// Initialize version UI on page load
handleVersionChange();

// Performance Modal Handling
const modal = document.getElementById('performanceModal');
const performanceButton = document.getElementById('performanceButton');
const closeButton = document.querySelector('.close-button');
// Store performance data
let performanceData = [];

// Function to update performance stats
async function updatePerformanceStats() {
    try {
        const response = await fetch('/performance');
        const data = await response.json();
        performanceData = data;
        
        // Calculate statistics for each type
        const mandelbrotData = data.filter(item => item.type === 'mandelbrot');
        const juliaData = data.filter(item => item.type === 'julia');
        
        // Calculate averages for each type
        const mandelbrotAvg = mandelbrotData.length > 0 ? 
            (mandelbrotData.reduce((a, b) => a + b.computation_time, 0) / mandelbrotData.length).toFixed(3) : '-';
        const juliaAvg = juliaData.length > 0 ? 
            (juliaData.reduce((a, b) => a + b.computation_time, 0) / juliaData.length).toFixed(3) : '-';
        const requestAvg = data.length > 0 ? 
            (data.reduce((a, b) => a + b.request_delay, 0) / data.length).toFixed(3) : '-';
        
        // Update stats display
        document.getElementById('mandelbrotSpeed').textContent = `${mandelbrotAvg}s`;
        document.getElementById('juliaSpeed').textContent = `${juliaAvg}s`;
        document.getElementById('requestDelay').textContent = `${requestAvg}s`;
        document.getElementById('currentZoom').textContent = `${currentView.zoom.toFixed(1)}x`;
        
        // Get current resolution
        const selectedRes = currentVersion === 'hardware' ? 
            hardwareResSelect.value : softwareResSelect.value;
        const dimensions = resolutionMap[selectedRes] || [640, 480];
        document.getElementById('currentResolution').textContent = 
            `${dimensions[0]}x${dimensions[1]}`;
        
        // Update iterations
        document.getElementById('currentIterations').textContent = 
            document.getElementById('iterations').value;
        
        // Update render history
        const historyDiv = document.getElementById('renderHistory');
        historyDiv.innerHTML = data.slice(-5).reverse().map(item => `
            <div class="render-item">
                ${item.type} (${item.version}) - ${item.resolution}<br>
                Computation: ${item.computation_time.toFixed(3)}s<br>
                Request Delay: ${item.request_delay.toFixed(3)}s
            </div>
        `).join('');
    } catch (error) {
        console.error('Error fetching performance data:', error);
    }
}

// Show modal
performanceButton.addEventListener('click', () => {
    modal.style.display = 'block';
    updatePerformanceStats();
});

// Close modal
closeButton.addEventListener('click', () => {
    modal.style.display = 'none';
});

// Close modal when clicking outside
window.addEventListener('click', (event) => {
    if (event.target === modal) {
        modal.style.display = 'none';
    }
});