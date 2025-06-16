import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import time
from tqdm import tqdm   # for showing progress bar

# Start timer
start_time = time.time()

# Load csv file generated from SV Mandelbrot simulation
df = pd.read_csv('mandelbrot_pixels.csv')

# Get sorted list of all unique x and y values (floating point coords)
x_vals = np.sort(df['x'].unique())
y_vals = np.sort(df['y'].unique())

width = len(x_vals)
height = len(y_vals)

# Create blank grayscale image array (all black initially)
img = np.zeros((height, width), dtype=np.uint8)

# Map floating point coords to pixel indices
x_to_index = {x: i for i, x in enumerate(x_vals)}
y_to_index = {y: i for i, y in enumerate(y_vals)}

# Loop through every point in csv and place iteration count into image
for _, row in tqdm(df.iterrows(), total=len(df), desc="Processing pixels"):
    x_index = x_to_index[row['x']]          # get pixel column
    y_index = y_to_index[row['y']]          # get pixel row
    img[y_index, x_index] = row['iter']     # set brightness based on iteration count

# Scale all pixel values to 0–255 so can actually see them
img = (255 * (img / img.max())).astype(np.uint8)

# Display image
plt.imshow(img, cmap='jet', origin='lower')
plt.axis('off')

# Save image to PNG file
plt.savefig('mandelbrot.png', bbox_inches='tight', pad_inches=0)
plt.show()

elapsed = time.time() - start_time
print(f"Image generated and saved as mandelbrot.png in {elapsed:.1f} seconds.")
