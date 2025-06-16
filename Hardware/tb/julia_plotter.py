import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import time

# Start timer
start_time = time.time()

# Load csv file generated from SV Julia simulation
print("Loading data...")
df = pd.read_csv('julia_pixels.csv')

# Create image array directly from the data
print("Creating image array...")
# Get dimensions from the data
width = 1920
height = 1080

# Create image array
img = np.zeros((height, width), dtype=np.uint8)

# Reshape the data into a 2D array
img = df['iter'].values.reshape(height, width)

# Scale all pixel values to 0–255
print("Scaling values...")
max_iter = img.max()
img = (255 * (img / max_iter)).astype(np.uint8)

# Display image
print("Saving image...")
plt.figure(figsize=(19.2, 10.8), dpi=100)  # 16:9 aspect ratio

# Plot with proper extent and aspect ratio
plt.imshow(img, cmap='jet', origin='lower', interpolation='none',
           extent=[df['x'].min(), df['x'].max(), df['y'].min(), df['y'].max()],
           aspect='auto')  # Changed to 'auto' to respect the data's aspect ratio
plt.axis('off')

# Save image to PNG file with high quality settings
plt.savefig('julia.png',
            bbox_inches='tight',
            pad_inches=0,
            dpi=100,
            format='png',
            transparent=False)
plt.close()

elapsed = time.time() - start_time
print(f"Image generated and saved as julia.png in {elapsed:.1f} seconds.")
print(f"Max iterations: {max_iter}")
print(f"Image size: {img.shape}")
print(f"Coordinate ranges: x=[{df['x'].min():.3f}, {df['x'].max():.3f}], y=[{df['y'].min():.3f}, {df['y'].max():.3f}]") 