import json
import subprocess
import numpy as np
from scipy.ndimage import gaussian_filter
import dash
from dash import dcc, html, Input, Output, State
import plotly.graph_objects as go

# ── Grid dimensions — must match Fortran ──────────────────────────────────────
NX, NY, NZ   = 200, 200, 100
X_MAX, Y_MAX = 500e3, 500e3   # meters
Z_MAX        = 5000.0

# ── Fortran interface ──────────────────────────────────────────────────────────
def run_fortran(depth, heading):
    params = {"sub_depth": float(depth),
              "sub_heading": float(heading),
              "sub_speed": 10.0}
    with open('params.json', 'w') as f:
        json.dump(params, f, indent=2)
    result = subprocess.run(['./sonar3d'], capture_output=True, text=True)
    return result.returncode == 0

def load_grid():
    data = np.fromfile('intensity_3d.bin', dtype=np.float64)
    grid = data.reshape((NX, NY, NZ), order='F')
    print(f'Grid populated: min={grid.min():.1f} max={grid.max():.1f} nonzero={np.count_nonzero(grid)}')
    print(f'Depth slice sums: {[grid[:,:,i].sum() for i in [0,10,25,50,75,99]]}')
    grid = gaussian_filter(grid, sigma=1.5)
    grid = np.where(grid > 0, grid, 0.0)
    grid = np.log1p(grid)
    vmax = grid.max()
    if vmax > 0:
        grid /= vmax
    return grid

def downsample(grid, factor=4):
    """Reduce grid size for browser rendering — 200x200x100 → 50x50x25"""
    return grid[::factor, ::factor, ::factor]

# ── Figure builder ─────────────────────────────────────────────────────────────
def make_volume_figure(grid, depth, heading):
    # Downsample before sending to browser
    grid = downsample(grid, factor=4)
    nx, ny, nz = grid.shape

    xs = np.linspace(-X_MAX/1e3, X_MAX/1e3, nx)
    ys = np.linspace(-Y_MAX/1e3, Y_MAX/1e3, ny)
    zs = np.linspace(0, Z_MAX, nz)

    gx, gy, gz = np.meshgrid(xs, ys, zs, indexing='ij')
    flat = grid.flatten(order='C')

    # Heading arrow
    hdg_rad = np.radians(heading)
    arrow_x = [0, 80 * np.cos(hdg_rad)]
    arrow_y = [0, 80 * np.sin(hdg_rad)]
    arrow_z = [-depth / 1000, -depth / 1000]

    fig = go.Figure()

    # ── Volume trace ────────────────────────────────────────────────────────
    fig.add_trace(go.Volume(
        x=gx.flatten(),
        y=gy.flatten(),
        z=(-gz).flatten(),
        value=flat,
        isomin=0.02,
        isomax=1.0,
        opacity=0.06,
        surface_count=12,
        colorscale='Inferno',
        showscale=True,
        colorbar=dict(
            title=dict(text='Intensity', side='right'),
            thickness=15,
            x=1.02,
            tickfont=dict(color='white')
        ),
        caps=dict(x_show=False, y_show=False, z_show=False),
        name='CZ Intensity'
    ))

    # ── Sub position ────────────────────────────────────────────────────────
    fig.add_trace(go.Scatter3d(
        x=[0], y=[0], z=[-depth / 1000],
        mode='markers+text',
        marker=dict(color='cyan', size=6, symbol='circle'),
        text=['SUB'],
        textfont=dict(color='cyan', size=11),
        textposition='top center',
        name='Submarine'
    ))

    # ── Heading indicator ───────────────────────────────────────────────────
    fig.add_trace(go.Scatter3d(
        x=arrow_x, y=arrow_y, z=arrow_z,
        mode='lines',
        line=dict(color='cyan', width=3),
        name=f'Heading {heading}°'
    ))

    # ── Ocean surface plane ─────────────────────────────────────────────────
    fig.add_trace(go.Mesh3d(
        x=[-X_MAX/1e3, X_MAX/1e3,  X_MAX/1e3, -X_MAX/1e3],
        y=[-Y_MAX/1e3, -Y_MAX/1e3,  Y_MAX/1e3,  Y_MAX/1e3],
        z=[0, 0, 0, 0],
        color='#003366',
        opacity=0.15,
        name='Surface'
    ))

    fig.update_layout(
        height=750,
        paper_bgcolor='#0a0a0f',
        scene=dict(
            bgcolor='#0a0a0f',
            xaxis=dict(title='E-W (km)', color='white',
                       gridcolor='#222', zerolinecolor='#444',
                       backgroundcolor='#0a0a0f'),
            yaxis=dict(title='N-S (km)', color='white',
                       gridcolor='#222', zerolinecolor='#444',
                       backgroundcolor='#0a0a0f'),
            zaxis=dict(
                title='Depth (km)', color='white',
                gridcolor='#222', zerolinecolor='#444',
                backgroundcolor='#0a0a0f',
                autorange='reversed',
            ),
            camera=dict(
                eye=dict(x=1.4, y=1.4, z=0.8),
                up=dict(x=0, y=0, z=1)
            ),
            aspectmode='manual',
            aspectratio=dict(x=2, y=2, z=1),
        ),
        font=dict(color='white', family='monospace'),
        title=dict(
            text=f'3D Convergence Zone Volume  |  depth={depth}m  heading={heading}°',
            font=dict(color='#00ffff', size=14)
        ),
        legend=dict(
            bgcolor='#111', bordercolor='#333',
            font=dict(color='white'), x=0, y=1
        ),
        margin=dict(l=0, r=0, t=40, b=0)
    )
    return fig

# ── Initial run ────────────────────────────────────────────────────────────────
run_fortran(300.0, 0.0)
initial_grid = load_grid()
initial_fig  = make_volume_figure(initial_grid, 300, 0)

# ── Dash layout ───────────────────────────────────────────────────────────────
app = dash.Dash(__name__)

SLIDER_STYLE = {'color': '#aaa', 'fontSize': '12px',
                'fontFamily': 'monospace', 'marginBottom': '8px'}

app.layout = html.Div(
    style={'backgroundColor': '#0a0a0f', 'padding': '24px',
           'fontFamily': 'monospace', 'color': 'white', 'minHeight': '100vh'},
    children=[

        html.H2('SONAR RAY TRACER',
                style={'color': '#00ffff', 'letterSpacing': '4px',
                       'marginBottom': '4px', 'fontSize': '18px'}),
        html.P('3D Convergence Zone Explorer — Munk Profile',
               style={'color': '#555', 'marginBottom': '24px', 'fontSize': '12px'}),

        # ── Controls ────────────────────────────────────────────────────────
        html.Div(
            style={'display': 'grid',
                   'gridTemplateColumns': '1fr 1fr auto',
                   'gap': '40px',
                   'alignItems': 'end',
                   'marginBottom': '16px'},
            children=[

                html.Div([
                    html.Label('SUB DEPTH (m)', style=SLIDER_STYLE),
                    dcc.Slider(
                        id='depth-slider',
                        min=50, max=4500, step=50, value=300,
                        marks={d: {'label': str(d),
                                   'style': {'color': '#666', 'fontSize': '10px'}}
                               for d in [50, 500, 1000, 1300, 2000, 3000, 4500]},
                        tooltip={"placement": "top", "always_visible": True},
                        updatemode='mouseup'
                    ),
                ]),

                html.Div([
                    html.Label('SUB HEADING (°)', style=SLIDER_STYLE),
                    dcc.Slider(
                        id='heading-slider',
                        min=0, max=350, step=10, value=0,
                        marks={h: {'label': str(h),
                                   'style': {'color': '#666', 'fontSize': '10px'}}
                               for h in [0, 45, 90, 135, 180, 225, 270, 315, 350]},
                        tooltip={"placement": "top", "always_visible": True},
                        updatemode='mouseup'
                    ),
                ]),

                html.Div([
                    html.Div(id='status-dot',
                             style={'width': '10px', 'height': '10px',
                                    'borderRadius': '50%',
                                    'backgroundColor': '#00ff88',
                                    'display': 'inline-block',
                                    'marginRight': '8px'}),
                    html.Span(id='status-text',
                              children='READY',
                              style={'color': '#00ff88', 'fontSize': '11px',
                                     'letterSpacing': '2px'})
                ]),
            ]
        ),

        # ── Status bar ──────────────────────────────────────────────────────
        html.Div(id='run-info',
                 style={'color': '#444', 'fontSize': '11px',
                        'marginBottom': '12px', 'letterSpacing': '1px'}),

        # ── 3D Volume ───────────────────────────────────────────────────────
        dcc.Loading(
            id='loading',
            type='circle',
            color='#00ffff',
            children=dcc.Graph(
                id='volume-graph',
                figure=initial_fig,
                style={'height': '750px'},
                config={
                    'displayModeBar': True,
                    'modeBarButtonsToRemove': ['toImage'],
                    'displaylogo': False
                }
            )
        ),
    ]
)

# ── Callback ──────────────────────────────────────────────────────────────────
@app.callback(
    Output('volume-graph', 'figure'),
    Output('run-info', 'children'),
    Output('status-text', 'children'),
    Output('status-dot', 'style'),
    Input('depth-slider', 'value'),
    Input('heading-slider', 'value'),
    prevent_initial_call=True
)
def update(depth, heading):
    dot_running = {'width': '10px', 'height': '10px', 'borderRadius': '50%',
                   'backgroundColor': '#ffaa00', 'display': 'inline-block',
                   'marginRight': '8px'}

    success = run_fortran(depth, heading)

    if not success:
        dot_err = {**dot_running, 'backgroundColor': '#ff3333'}
        return dash.no_update, 'Fortran error — check console', 'ERROR', dot_err

    grid = load_grid()
    fig  = make_volume_figure(grid, depth, heading)

    info = (f'depth={depth}m  |  heading={heading}°  |  '
            f'rays={25*36}  |  grid={NX}×{NY}×{NZ}  |  '
            f'render grid=50×50×25  |  range=±{int(X_MAX/1e3)}km')

    dot_ready = {'width': '10px', 'height': '10px', 'borderRadius': '50%',
                 'backgroundColor': '#00ff88', 'display': 'inline-block',
                 'marginRight': '8px'}

    return fig, info, 'READY', dot_ready

if __name__ == '__main__':
    app.run(debug=False, port=8050)