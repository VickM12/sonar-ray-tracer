import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.cm as cm
import numpy as np

rays = pd.read_csv('ray_paths.csv')
angles = rays['angle_deg'].unique()

fig, ax = plt.subplots(figsize=(14, 6))

colors = cm.coolwarm(np.linspace(0, 1, len(angles)))

for color, angle in zip(colors, sorted(angles)):
    ray = rays[rays['angle_deg'] == angle]
    ax.plot(ray['range_m'] / 1000, ray['depth_m'], 
            color=color, linewidth=0.8, alpha=0.85)

ax.invert_yaxis()
ax.axhline(1300, color='red', linestyle='--', linewidth=0.8, 
           alpha=0.5, label='SOFAR axis')
ax.set_xlabel('Range (km)')
ax.set_ylabel('Depth (m)')
ax.set_title('Sonar Ray Fan — Munk Profile\nSource at SOFAR axis (1300m)')
ax.legend()
ax.grid(True, alpha=0.2)
plt.tight_layout()
plt.savefig('ray_paths.png', dpi=150)
plt.show()