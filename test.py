import sys
from vispy import scene, app
import numpy as np

app.use_app('pyqt5')

canvas = scene.SceneCanvas(keys='interactive', show=True, bgcolor='black')
view = canvas.central_widget.add_view()
view.camera = scene.cameras.TurntableCamera(elevation=30, azimuth=-60, distance=10)

# Three lines at different Z depths — should form a visible stack
for z, color in [(0, 'red'), (2, 'green'), (4, 'blue')]:
    pts = np.array([[-5, -5, z], [5, -5, z], [5, 5, z], [-5, 5, z], [-5, -5, z]], dtype=np.float32)
    line = scene.visuals.Line(pos=pts, color=color, parent=view.scene)

scene.visuals.XYZAxis(parent=view.scene)
app.run()