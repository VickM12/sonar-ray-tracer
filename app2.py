import json
import subprocess
import sys
import numpy as np
import matplotlib.cm as mcm

from vispy import scene, app as vispy_app
from vispy.scene import visuals

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout,
    QHBoxLayout, QSlider, QLabel, QPushButton, QFrame,
    QSizePolicy
)
from PyQt5.QtCore import Qt, QThread, pyqtSignal
from PyQt5.QtGui import QColor, QPalette

# ── Constants ─────────────────────────────────────────────────────────────────
X_MAX, Y_MAX = 500.0, 500.0   # km
Z_MAX        = 5.0             # km

# ── Colors ────────────────────────────────────────────────────────────────────
BG          = '#0a0a0f'
PANEL_BG    = '#111118'
ACCENT      = '#00ffff'
TEXT        = '#cccccc'
DIM         = '#444455'
READY_COL   = '#00ff88'
RUNNING_COL = '#ffaa00'
ERROR_COL   = '#ff3333'

# ── Fortran worker ────────────────────────────────────────────────────────────
class FortranWorker(QThread):
    finished = pyqtSignal(bool)

    def __init__(self, depth, heading):
        super().__init__()
        self.depth   = depth
        self.heading = heading

    def run(self):
        params = {
            "sub_depth":   float(self.depth),
            "sub_heading": float(self.heading),
            "sub_speed":   10.0
        }
        with open('params.json', 'w') as f:
            json.dump(params, f, indent=2)
        result = subprocess.run(['./sonar3d'], capture_output=True, text=True)
        self.finished.emit(result.returncode == 0)

# ── Ray path reader ───────────────────────────────────────────────────────────
def load_rays(filename='rays_3d.bin'):
    """
    Read binary ray path file written by Fortran.
    Format:
      int32  : total number of rays
      per ray:
        int32  : n_points
        float64 x n_points : x coords (km)
        float64 x n_points : y coords (km)
        float64 x n_points : z coords (km)
    Returns list of (N,3) float32 arrays, one per ray.
    """
    rays = []
    with open(filename, 'rb') as f:
        n_rays = np.frombuffer(f.read(4), dtype=np.int32)[0]
        for _ in range(n_rays):
            n_pts = np.frombuffer(f.read(4), dtype=np.int32)[0]
            if n_pts < 2:
                # skip degenerate rays but still consume bytes
                f.read(n_pts * 8 * 3)
                continue
            x = np.frombuffer(f.read(n_pts * 8), dtype=np.float64)
            y = np.frombuffer(f.read(n_pts * 8), dtype=np.float64)
            z = np.frombuffer(f.read(n_pts * 8), dtype=np.float64)
            path = np.column_stack([x, y, z]).astype(np.float32)
            rays.append(path)
    return rays

# ── Color rays by elevation angle ─────────────────────────────────────────────
def ray_color(ray_index, n_rays):
    """
    Color rays by index using coolwarm — blue for steep downward,
    red for steep upward, white for near-horizontal SOFAR rays.
    """
    cmap = mcm.get_cmap('coolwarm')
    t    = ray_index / max(n_rays - 1, 1)
    r, g, b, _ = cmap(t)
    return (r, g, b, 0.6)   # slight transparency so overlapping rays glow

# ── Vispy canvas ──────────────────────────────────────────────────────────────
class SonarCanvas(scene.SceneCanvas):
    def __init__(self):
        super().__init__(keys='interactive', bgcolor=BG, show=False)
        self.unfreeze()

        self.view = self.central_widget.add_view()
        self.view.camera = scene.cameras.ArcballCamera(
            fov=45,
            distance=800,
            center=(250, 0, 2.5)
        )

        self._ray_nodes = []
        self._sub       = None
        self._arrow     = None

        scene.visuals.XYZAxis(parent=self.view.scene)
        self.freeze()

    def render_scene(self, rays, depth_m, heading_deg):
        self.unfreeze()
    
        for node in self._ray_nodes:
            node.parent = None
        self._ray_nodes = []
        for node in [self._sub, self._arrow]:
            if node is not None:
                node.parent = None
    
        # ── Merge all rays into one draw call with NaN separators ────────────
        n_rays   = len(rays)
        cmap     = mcm.get_cmap('coolwarm')
        segments = []
        colors   = []
    
        for i, path in enumerate(rays):
            # Downsample path — every 10th point is plenty for visuals
            path = path[::10]
            n    = len(path)
            if n < 2:
                continue
    
            t     = i / max(n_rays - 1, 1)
            r, g, b, _ = cmap(t)
            col   = np.tile([r, g, b, 0.7], (n + 1, 1)).astype(np.float32)
    
            # NaN row as separator
            sep   = np.array([[np.nan, np.nan, np.nan]], dtype=np.float32)
            segments.append(np.vstack([path, sep]))
            colors.append(col)
    
        all_pos = np.vstack(segments).astype(np.float32)
        all_col = np.vstack(colors).astype(np.float32)
    
        line = visuals.Line(
            pos=all_pos,
            color=all_col,
            width=1,
            method='gl',
            connect='strip',
            parent=self.view.scene
        )
        self._ray_nodes = [line]
    
        # sub + arrow unchanged
        sub_z = depth_m / 1000.0
        self._sub = visuals.Markers(parent=self.view.scene)
        self._sub.set_data(
            np.array([[0.0, 0.0, sub_z]], dtype=np.float32),
            face_color=(0, 1, 1, 1), size=14, edge_width=0,
        )
        hdg_rad   = np.radians(heading_deg)
        arrow_end = np.array([80*np.cos(hdg_rad), 80*np.sin(hdg_rad), sub_z], dtype=np.float32)
        self._arrow = visuals.Line(
            pos=np.array([[0, 0, sub_z], arrow_end], dtype=np.float32),
            color=(0,1,1,1), width=2, parent=self.view.scene
        )
    
        self.freeze()
        self.update()
        
# ── Widget helpers ────────────────────────────────────────────────────────────
def make_label(text, color=TEXT, size=11, bold=False):
    lbl = QLabel(text)
    weight = 'bold' if bold else 'normal'
    lbl.setStyleSheet(
        f'color: {color}; font-size: {size}px; font-weight: {weight};'
        f'font-family: monospace; background: transparent;'
    )
    return lbl

def make_slider(min_val, max_val, step, value):
    s = QSlider(Qt.Horizontal)
    s.setMinimum(min_val)
    s.setMaximum(max_val)
    s.setSingleStep(step)
    s.setPageStep(step * 5)
    s.setValue(value)
    s.setStyleSheet("""
        QSlider::groove:horizontal {
            height: 4px; background: #222233; border-radius: 2px;
        }
        QSlider::handle:horizontal {
            background: #00ffff; width: 14px; height: 14px;
            margin: -5px 0; border-radius: 7px;
        }
        QSlider::sub-page:horizontal {
            background: #004455; border-radius: 2px;
        }
    """)
    return s

# ── Main window ───────────────────────────────────────────────────────────────
class SonarApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle('SONAR RAY TRACER — 3D CZ Explorer')
        self.setMinimumSize(1200, 800)
        self._worker          = None
        self._current_depth   = 300
        self._current_heading = 0
        self._build_ui()
        self._initial_run()

    def _build_ui(self):
        root = QWidget()
        root.setStyleSheet(f'background-color: {BG};')
        self.setCentralWidget(root)

        outer = QHBoxLayout(root)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        # ── Control panel ────────────────────────────────────────────────────
        panel = QWidget()
        panel.setFixedWidth(260)
        panel.setStyleSheet(f'background-color: {PANEL_BG};')
        pl = QVBoxLayout(panel)
        pl.setContentsMargins(20, 24, 20, 24)
        pl.setSpacing(8)

        pl.addWidget(make_label('SONAR RAY TRACER', color=ACCENT, size=14, bold=True))
        pl.addWidget(make_label('3D Convergence Zone Explorer', color=DIM, size=10))
        pl.addSpacing(16)
        pl.addWidget(self._divider())

        pl.addSpacing(12)
        pl.addWidget(make_label('SUB DEPTH', color=TEXT, size=10, bold=True))
        self.depth_val_label = make_label('300 m', color=ACCENT, size=12)
        pl.addWidget(self.depth_val_label)
        self.depth_slider = make_slider(50, 4500, 50, 300)
        self.depth_slider.valueChanged.connect(self._on_depth_changed)
        pl.addWidget(self.depth_slider)

        pl.addSpacing(16)
        pl.addWidget(make_label('SUB HEADING', color=TEXT, size=10, bold=True))
        self.heading_val_label = make_label('0°  (East)', color=ACCENT, size=12)
        pl.addWidget(self.heading_val_label)
        self.heading_slider = make_slider(0, 350, 10, 0)
        self.heading_slider.valueChanged.connect(self._on_heading_changed)
        pl.addWidget(self.heading_slider)

        pl.addSpacing(20)
        self.run_btn = QPushButton('RUN SIMULATION')
        self.run_btn.setFixedHeight(40)
        self.run_btn.clicked.connect(self._run_simulation)
        self.run_btn.setStyleSheet(f"""
            QPushButton {{
                background-color: {ACCENT}; color: #000000; border: none;
                font-family: monospace; font-size: 12px;
                font-weight: bold; letter-spacing: 2px;
            }}
            QPushButton:hover {{ background-color: #00dddd; }}
            QPushButton:disabled {{ background-color: #223333; color: #446666; }}
        """)
        pl.addWidget(self.run_btn)

        pl.addSpacing(12)
        pl.addWidget(self._divider())
        pl.addSpacing(8)
        self.status_label = make_label('● READY', color=READY_COL, size=11)
        pl.addWidget(self.status_label)
        pl.addSpacing(8)
        self.info_label = make_label(
            'depth: 300m\nheading: 0°\nrays: 900',
            color=DIM, size=10
        )
        self.info_label.setWordWrap(True)
        pl.addWidget(self.info_label)

        pl.addStretch()
        pl.addWidget(self._divider())
        pl.addSpacing(8)
        pl.addWidget(make_label(
            'Tip: depth 1300m = SOFAR axis\n\n'
            'Orbit: left drag\nZoom: scroll\nPan: right drag',
            color=DIM, size=9
        ))

        outer.addWidget(panel)

        # ── Vispy canvas ──────────────────────────────────────────────────────
        self.canvas = SonarCanvas()
        native = self.canvas.native
        native.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        outer.addWidget(native)

    def _divider(self):
        line = QFrame()
        line.setFrameShape(QFrame.HLine)
        line.setStyleSheet(f'color: {DIM}; background-color: {DIM};')
        line.setFixedHeight(1)
        return line

    def _on_depth_changed(self, val):
        self._current_depth = val
        self.depth_val_label.setText(f'{val} m')

    def _on_heading_changed(self, val):
        self._current_heading = val
        self.heading_val_label.setText(f'{val}°  ({self._compass(val)})')

    def _compass(self, deg):
        dirs = ['E', 'NE', 'N', 'NW', 'W', 'SW', 'S', 'SE']
        return dirs[int((deg + 22.5) / 45) % 8]

    def _initial_run(self):
        self._set_status('COMPUTING', RUNNING_COL)
        self.run_btn.setEnabled(False)
        self._start_worker(300, 0)

    def _run_simulation(self):
        if self._worker and self._worker.isRunning():
            return
        self._set_status('COMPUTING', RUNNING_COL)
        self.run_btn.setEnabled(False)
        self.info_label.setText(
            f'depth: {self._current_depth}m\n'
            f'heading: {self._current_heading}°\n'
            f'rays: 900\n\nrunning...'
        )
        self._start_worker(self._current_depth, self._current_heading)

    def _start_worker(self, depth, heading):
        self._worker = FortranWorker(depth, heading)
        self._worker.finished.connect(self._on_fortran_done)
        self._worker.start()

    def _on_fortran_done(self, success):
        if not success:
            self._set_status('ERROR', ERROR_COL)
            self.run_btn.setEnabled(True)
            return
        depth, heading = self._current_depth, self._current_heading
        rays = load_rays('rays_3d.bin')
        self.canvas.render_scene(rays, depth, heading)
        self._set_status('READY', READY_COL)
        self.run_btn.setEnabled(True)
        self.info_label.setText(
            f'depth: {depth}m\nheading: {heading}°\n'
            f'rays loaded: {len(rays)}'
        )

    def _set_status(self, text, color):
        self.status_label.setText(f'● {text}')
        self.status_label.setStyleSheet(
            f'color: {color}; font-size: 11px; font-family: monospace;'
        )

    def closeEvent(self, event):
        self.canvas.close()
        event.accept()

# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == '__main__':
    vispy_app.use_app('pyqt5')

    qt_app = QApplication(sys.argv)
    qt_app.setStyle('Fusion')

    palette = QPalette()
    palette.setColor(QPalette.Window,          QColor(10, 10, 15))
    palette.setColor(QPalette.WindowText,      QColor(204, 204, 204))
    palette.setColor(QPalette.Base,            QColor(17, 17, 24))
    palette.setColor(QPalette.AlternateBase,   QColor(25, 25, 35))
    palette.setColor(QPalette.Text,            QColor(204, 204, 204))
    palette.setColor(QPalette.Button,          QColor(17, 17, 24))
    palette.setColor(QPalette.ButtonText,      QColor(204, 204, 204))
    palette.setColor(QPalette.Highlight,       QColor(0, 255, 255))
    palette.setColor(QPalette.HighlightedText, QColor(0, 0, 0))
    qt_app.setPalette(palette)

    window = SonarApp()
    window.show()
    sys.exit(qt_app.exec_())