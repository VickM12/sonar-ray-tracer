import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv('sound_speed_profile.csv')

fig, ax = plt.subplots(figsize=(5, 8))
ax.plot(df['speed_ms'], df['depth_m'])
ax.invert_yaxis()                        # ocean convention: depth increases downward
ax.set_xlabel('Sound Speed (m/s)')
ax.set_ylabel('Depth (m)')
ax.set_title('Munk Sound Speed Profile\n(SOFAR channel ~1300m)')
ax.axhline(1300, color='red', linestyle='--', linewidth=0.8, label='SOFAR axis')
ax.legend()
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('sound_speed_profile.png', dpi=150)
plt.show()