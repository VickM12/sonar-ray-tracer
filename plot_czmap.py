import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import pandas as pd
from matplotlib.colors import LogNorm
from scipy.ndimage import gaussian_filter

NR, NZ       = 1000, 500
R_MAX, Z_MAX = 1000e3, 5000.0
N_FRAMES     = 30

track = pd.read_csv('sub_track.csv')
profile = pd.read_csv('sound_speed_profile.csv')

fig, (ax_cz, ax_sp) = plt.subplots(1, 2, figsize=(16, 7),
                                    gridspec_kw={'width_ratios': [3, 1]})
plt.subplots_adjust(wspace=0.05)

# --- Sound speed profile (static) ---
ax_sp.plot(profile['speed_ms'], profile['depth_m'], 'b-', linewidth=1.5)
ax_sp.axhline(1300, color='red', linestyle='--', linewidth=0.8, alpha=0.6)
ax_sp.invert_yaxis()
ax_sp.set_xlabel('c (m/s)', fontsize=9)
ax_sp.set_ylabel('')
ax_sp.set_yticks([])
ax_sp.set_title('Sound Speed', fontsize=10)
ax_sp.grid(True, alpha=0.2)

# --- CZ map (animated) ---
extent = [0, R_MAX / 1000, Z_MAX, 0]   # range in km, depth positive down

def load_frame(n):
    data = np.fromfile(f'frames/frame_{n+1:03d}.bin', dtype=np.float64)
    grid = data.reshape((NR, NZ)).T
    grid = gaussian_filter(grid, sigma=2.0)
    return grid

first = load_frame(0)
first_plot = np.where(first > 0, first, np.nan)

im = ax_cz.imshow(first_plot, extent=extent, aspect='auto',
                   cmap='inferno', origin='upper',
                   norm=LogNorm(vmin=1, vmax=first_plot[np.isfinite(first_plot)].max()))

sub_dot,  = ax_cz.plot([], [], 'co', markersize=8, label='Sub', zorder=5)
sub_track, = ax_cz.plot([], [], 'c--', linewidth=1, alpha=0.6, zorder=4)

ax_cz.invert_yaxis()
ax_cz.set_xlabel('Range (km)')
ax_cz.set_ylabel('Depth (m)')
ax_cz.set_title('Convergence Zone Map — Moving Sub')
ax_cz.legend(loc='lower right')
ax_cz.grid(False)

cbar = fig.colorbar(im, ax=ax_cz, fraction=0.02, pad=0.02)
cbar.set_label('Ray Intensity (log)', fontsize=9)

time_text = ax_cz.text(0.02, 0.02, '', transform=ax_cz.transAxes,
                        color='white', fontsize=10)

def update(frame):
    grid = load_frame(frame)
    grid_plot = np.where(grid > 0, grid, np.nan)

    finite = grid_plot[np.isfinite(grid_plot)]
    if len(finite):
        im.set_norm(LogNorm(vmin=1, vmax=finite.max()))
    im.set_data(grid_plot)

    rx = track['range_m'].values[:frame+1] / 1000
    rz = track['depth_m'].values[:frame+1]
    sub_track.set_data(rx, rz)
    sub_dot.set_data([rx[-1]], [rz[-1]])

    t_min = track['time_s'].values[frame] / 60
    time_text.set_text(f't = {t_min:.0f} min  |  range = {rx[-1]:.1f} km')

    return im, sub_dot, sub_track, time_text

ani = animation.FuncAnimation(fig, update, frames=N_FRAMES,
                               interval=400, blit=True)

ani.save('cz_animation.gif', writer='pillow', dpi=120)
plt.show()