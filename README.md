# Sonar Ray Tracer

A 3D acoustic ray tracing simulation of underwater sound propagation, built in Fortran with an interactive Python/Dash frontend. Models convergence zone formation in the deep ocean using the Munk sound speed profile.

Inspired by my dad's work for the US Navy.

---

## What It Does

Sound in the ocean doesn't travel in straight lines. It bends based on the speed of sound, which varies with temperature, salinity, and pressure. This creates the **SOFAR channel** (Sound Fixing and Ranging) — a natural acoustic waveguide around 700–1300m depth where sound gets trapped and can travel thousands of miles.

This simulator:
- Models the Munk sound speed profile (the canonical analytic model of deep ocean acoustics)
- Traces fans of acoustic rays using a 4th-order Runge-Kutta integrator
- Accumulates ray intensity into a 3D spatial grid to reveal **convergence zones** — regions where multiple rays focus and sound energy concentrates
- Renders the result as an interactive 3D volume you can orbit, inspect, and recompute with different submarine parameters

---

## Physics

### Sound Speed Profile
The [Munk profile](https://en.wikipedia.org/wiki/Munk_profile) describes how sound speed varies with depth:

```
c(z) = c₀ · [1 + ε(η + e^(-η) - 1)]
where η = 2(z - z_min) / B
```

Three factors compete:
- **Temperature** dominates near the surface — warmer water = faster sound
- **Pressure** dominates at depth — higher pressure = faster sound
- Their opposing effects create a **minimum around 1300m** — the SOFAR axis

### Ray Tracing
Rays are traced using the **Hamiltonian ray equations** in slowness vector form:

```
dx/ds  = c * xi           (ray moves horizontally at speed c * xi)
dz/ds  = c * zeta         (ray moves vertically at speed c * zeta)
dxi/ds = 0                (no horizontal sound speed variation)
dzeta/ds = -(dc/dz) / c^2 (vertical bending driven by sound speed gradient)
```

Where `(xi, zeta)` is the slowness vector and `s` is arc length along the ray. Integration uses 4th-order Runge-Kutta.

### Convergence Zones
Rays bend toward regions of lower sound speed. Rays launched above the SOFAR axis curve downward; rays below curve upward. They oscillate around the axis, periodically focusing at **convergence zones** roughly every 50–70 km — regions of anomalously high acoustic intensity where a sonobuoy would receive a strong return.

---

## Project Structure

```
sonar_tracer/
├── sound_speed.f90          # Munk profile and analytical gradient
├── ray_state_3d.f90         # 3D ray state derived type
├── intensity_grid_3d.f90    # 3D accumulation grid (200×200×100)
├── ray_tracer_3d.f90        # RK4 integrator, 3D ray fan, OpenMP parallelization
├── main_3d.f90              # Entry point, reads params.json, writes intensity_3d.bin
├── app.py                   # Dash/Plotly interactive 3D frontend
├── plot_czmap.py            # 2D animated CZ map (matplotlib, standalone)
├── plot_profile.py          # Sound speed profile plotter
├── params.json              # Runtime parameters (written by app.py)
├── requirements.txt         # Python dependencies
└── README.md
```

---

## Requirements

### Fortran
- `gfortran` with OpenMP support

On Ubuntu/Debian:
```bash
sudo apt install gfortran
```

On Windows: install [MSYS2](https://www.msys2.org/) and run:
```bash
pacman -S mingw-w64-x86_64-gcc-fortran
```

### Python
```bash
pip install -r requirements.txt
```

```
numpy
matplotlib
pandas
scipy
dash
plotly
```

---

## Build

```bash
gfortran -O2 -fopenmp -o sonar3d \
  sound_speed.f90 \
  ray_state_3d.f90 \
  intensity_grid_3d_mod.f90 \
  ray_tracer_3d.f90 \
  main_3d.f90
```

---

## Run

### Interactive 3D Explorer
```bash
python app.py
```
Open `http://localhost:8050` in your browser.

Use the sliders to set submarine depth and heading, then release to trigger a new simulation. Each run traces 900 rays (25 elevation × 36 azimuth) through a 200×200×100 spatial grid and renders the result as a 3D volumetric intensity map.

### 2D Animated CZ Map
```bash
./sonar3d          # or the 2D binary if compiled separately
python plot_czmap.py
```

### Sound Speed Profile Only
```bash
python plot_profile.py
```

---

## Parameters

Controlled via `params.json` (written automatically by `app.py`):

| Parameter | Description | Default |
|---|---|---|
| `sub_depth` | Submarine depth in meters | 300.0 |
| `sub_heading` | Heading in degrees (0° = east) | 0.0 |
| `sub_speed` | Speed in knots (display only) | 10.0 |

Key simulation constants in `main_3d.f90`:

| Constant | Value | Description |
|---|---|---|
| `DS` | 100.0 m | RK4 arc-length step size |
| `N_STEPS` | 25,000 | Steps per ray |
| `N_ELEV` | 25 | Elevation angles in fan |
| `N_AZIM` | 36 | Azimuthal angles in fan |
| `ELEV_MIN/MAX` | ±20° | Launch angle range |
| `X_MAX / Y_MAX` | ±500 km | Horizontal domain |
| `Z_MAX` | 5,000 m | Ocean depth |

---

## What to Look For

**Sub on the SOFAR axis (depth ~1300m)**
Energy focuses tightly into repeating CZ rings. Highly detectable at long range. This is why submarines avoid the SOFAR axis.

**Sub shallow (depth ~200m)**
Near-surface shadow zone absorbs most energy. CZ structure is weak and asymmetric. Harder to detect at long range.

**Sub deep (depth ~3000m)**
CZ structure present but shifted — pressure-side refraction dominates. Different periodicity than shallow sources.

**Heading changes**
Rotates the asymmetry of the CZ pattern. The 3D view makes this immediately visible in a way no 2D cross-section can show.

---

## Performance

On a modern multi-core machine with OpenMP enabled, each simulation frame runs in approximately 3–5 seconds. The `COLLAPSE(2)` OpenMP directive parallelizes across both elevation and azimuth loops simultaneously — all 900 rays run concurrently across available cores.

The 3D render grid (200×200×100) is downsampled to 50×50×25 before sending to the browser, keeping WebGL responsive while preserving the acoustic structure.


---

## License

MIT