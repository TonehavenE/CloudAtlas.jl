#!/usr/bin/env python3
"""Dash app for alpha-gamma grid exploration.

- Left: min-Re heatmap
- Right: bifurcation curves for clicked grid point
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import subprocess
import io
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd
from dash import Dash, dcc, html, Input, Output
import plotly.graph_objects as go
import plotly.colors as pc

BASE_DIR = Path(__file__).resolve().parent / "eqb_alpha_gamma_grid"
SHEAR_SCRIPT = Path(__file__).resolve().parent / "compute_eqb_shear.jl"
GROUPS = ["A", "B", "C", "D", "E", "F", "G"]
BIF_PATTERN = re.compile(r"^bif_(?:(?P<group>[A-G])_)?Lx(?P<Lx>[0-9.]+)_Lz(?P<Lz>[0-9.]+)_id(?P<id>\d+)\.csv$")

DEFAULT_COLORSCALE = "Turbo"
EQB_RE = 300.0


@dataclass
class Branch:
    Lx: float
    Lz: float
    branch_id: int
    Re: np.ndarray
    shear: np.ndarray


def read_completed_grid(group_dir: Path, group: str) -> pd.DataFrame | None:
    path = group_dir / f"completed_grid_{group}.csv"
    if not path.is_file():
        return None
    return pd.read_csv(path)


def read_min_re(group_dir: Path, group: str) -> pd.DataFrame | None:
    path = group_dir / "bifurcations" / f"min_re_{group}.csv"
    if not path.is_file():
        return None
    return pd.read_csv(path)


def round_key(value: float, ndigits: int = 4) -> float:
    return float(f"{value:.{ndigits}f}")


def infer_grid_vals(completed: pd.DataFrame | None, min_re: pd.DataFrame | None) -> Tuple[np.ndarray, np.ndarray]:
    Lx_vals: List[float] = []
    Lz_vals: List[float] = []
    if completed is not None:
        Lx_vals.extend(round_key(v) for v in completed["Lx"].tolist())
        Lz_vals.extend(round_key(v) for v in completed["Lz"].tolist())
    if min_re is not None:
        Lx_vals.extend(round_key(v) for v in min_re["Lx"].tolist())
        Lz_vals.extend(round_key(v) for v in min_re["Lz"].tolist())
    if not Lx_vals or not Lz_vals:
        return np.array([]), np.array([])
    return np.unique(np.array(Lx_vals)), np.unique(np.array(Lz_vals))


def build_min_re_matrix(Lx_vals: np.ndarray, Lz_vals: np.ndarray, min_re: pd.DataFrame | None) -> np.ndarray:
    mat = np.full((len(Lx_vals), len(Lz_vals)), np.nan, dtype=float)
    if min_re is None:
        return mat
    # Take minimum if duplicates exist.
    grouped = min_re.groupby(["Lx", "Lz"], as_index=False)["min_Re"].min()
    idx_Lx = {v: i for i, v in enumerate(Lx_vals)}
    idx_Lz = {v: i for i, v in enumerate(Lz_vals)}
    for _, row in grouped.iterrows():
        i = idx_Lx.get(round_key(row["Lx"]))
        j = idx_Lz.get(round_key(row["Lz"]))
        if i is None or j is None:
            continue
        mat[i, j] = row["min_Re"]
    return mat


def load_branches(group_dir: Path) -> Dict[Tuple[float, float], List[Branch]]:
    bif_dir = group_dir / "bifurcations"
    out: Dict[Tuple[float, float], List[Branch]] = {}
    if not bif_dir.is_dir():
        return out
    for path in bif_dir.iterdir():
        m = BIF_PATTERN.match(path.name)
        if not m:
            continue
        Lx = round_key(float(m.group("Lx")))
        Lz = round_key(float(m.group("Lz")))
        branch_id = int(m.group("id"))
        df = pd.read_csv(path)
        if df.empty or "Re" not in df.columns or "shear" not in df.columns:
            continue
        branch = Branch(Lx=Lx, Lz=Lz, branch_id=branch_id, Re=df["Re"].to_numpy(), shear=df["shear"].to_numpy())
        out.setdefault((Lx, Lz), []).append(branch)
    # Stable ordering by branch id for consistent colors
    for k in out:
        out[k].sort(key=lambda b: b.branch_id)
    return out


def build_heatmap_figure(Lx_vals: np.ndarray, Lz_vals: np.ndarray, min_re_mat: np.ndarray, title: str) -> go.Figure:
    fig = go.Figure(
        data=go.Heatmap(
            z=min_re_mat,
            x=Lz_vals,
            y=Lx_vals,
            colorscale=DEFAULT_COLORSCALE,
            colorbar=dict(title="min Re"),
            hovertemplate="Lx=%{y:.4f}<br>Lz=%{x:.4f}<br>min Re=%{z:.6f}<extra></extra>",
        )
    )
    fig.update_layout(
        title=title,
        xaxis_title="Lz",
        yaxis_title="Lx",
        height=650,
        margin=dict(l=60, r=20, t=50, b=50),
    )
    return fig


def build_branch_figure(
    branches: List[Branch],
    Lx: float,
    Lz: float,
    eqb_shear_by_id: Dict[int, float] | None = None,
) -> go.Figure:
    fig = go.Figure()
    if not branches:
        fig.add_annotation(
            text="No bifurcation curves for this (Lx, Lz)",
            x=0.5,
            y=0.5,
            xref="paper",
            yref="paper",
            showarrow=False,
        )
    else:
        palette = pc.qualitative.Dark24
        for idx, b in enumerate(branches):
            color = palette[idx % len(palette)]
            fig.add_trace(
                go.Scattergl(
                    x=b.Re,
                    y=b.shear,
                    mode="lines",
                    name=f"id {b.branch_id}",
                    line=dict(color=color, width=2),
                )
            )
        if eqb_shear_by_id:
            for idx, (eqb_id, sh) in enumerate(sorted(eqb_shear_by_id.items())):
                color = palette[idx % len(palette)]
                fig.add_trace(
                    go.Scatter(
                        x=[EQB_RE],
                        y=[sh],
                        mode="markers",
                        name=f"EQB {eqb_id}",
                        marker=dict(color=color, size=9, symbol="circle-open"),
                    )
                )
    fig.update_layout(
        title=f"Bifurcation curves at Lx={Lx:.4f}, Lz={Lz:.4f}",
        xaxis_title="Re",
        yaxis_title="shear",
        height=650,
        margin=dict(l=60, r=20, t=50, b=50),
        legend=dict(orientation="v", yanchor="top", y=1.0, xanchor="left", x=1.02),
    )
    return fig


def nearest_val(vals: np.ndarray, target: float) -> float:
    idx = int(np.argmin(np.abs(vals - target)))
    return round_key(float(vals[idx]))


# Cache per group
CACHE: Dict[str, dict] = {}
SHEAR_CACHE: Dict[Tuple[str, float, float], Dict[int, float]] = {}


def compute_eqb_shear(group: str, Lx: float, Lz: float, group_dir: Path) -> Dict[int, float]:
    if not SHEAR_SCRIPT.is_file():
        return {}
    key = (group, Lx, Lz)
    if key in SHEAR_CACHE:
        return SHEAR_CACHE[key]
    cmd = [
        "julia",
        f"--project={Path(__file__).resolve().parents[2]}",
        str(SHEAR_SCRIPT),
        "--group",
        group,
        "--Lx",
        f"{Lx:.10f}",
        "--Lz",
        f"{Lz:.10f}",
        "--dir",
        str(group_dir),
    ]
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        return {}
    if not result.stdout.strip():
        return {}
    raw_lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if not raw_lines:
        return {}
    if raw_lines[0].lower().startswith("id,"):
        df = pd.read_csv(io.StringIO("\n".join(raw_lines)))
    else:
        data_lines = [line for line in raw_lines if line.split(",")[0].isdigit()]
        if not data_lines:
            return {}
        df = pd.read_csv(io.StringIO("\n".join(data_lines)), header=None, names=["id", "shear"])
    if "id" not in df.columns or "shear" not in df.columns:
        return {}
    shear_by_id = {int(row["id"]): float(row["shear"]) for _, row in df.iterrows()}
    SHEAR_CACHE[key] = shear_by_id
    return shear_by_id


def get_group_data(group: str) -> dict:
    if group in CACHE:
        return CACHE[group]
    group_dir = BASE_DIR / group
    completed = read_completed_grid(group_dir, group)
    min_re = read_min_re(group_dir, group)
    Lx_vals, Lz_vals = infer_grid_vals(completed, min_re)
    min_re_mat = build_min_re_matrix(Lx_vals, Lz_vals, min_re)
    branches = load_branches(group_dir)

    data = {
        "Lx_vals": Lx_vals,
        "Lz_vals": Lz_vals,
        "min_re_mat": min_re_mat,
        "branches": branches,
    }
    CACHE[group] = data
    return data


app = Dash(__name__)

app.layout = html.Div(
    [
        html.Div(
            [
                html.Label("Symmetry group"),
                dcc.Dropdown(
                    id="group-dropdown",
                    options=[{"label": g, "value": g} for g in GROUPS],
                    value="D",
                    clearable=False,
                ),
                dcc.Checklist(
                    id="render-eqb",
                    options=[{"label": "Render EQB points (slow)", "value": "on"}],
                    value=[],
                    style={"marginTop": "6px"},
                ),
            ],
            style={"width": "240px", "marginBottom": "8px"},
        ),
        html.Div(
            [
                dcc.Graph(id="heatmap", style={"width": "50%", "display": "inline-block"}),
                dcc.Graph(id="branch-plot", style={"width": "50%", "display": "inline-block"}),
            ]
        ),
    ],
    style={"padding": "10px 16px"},
)


@app.callback(
    Output("heatmap", "figure"),
    Input("group-dropdown", "value"),
)
def update_heatmap(group: str) -> go.Figure:
    data = get_group_data(group)
    if data["Lx_vals"].size == 0:
        return go.Figure()
    title = f"Group {group} - min Re"
    return build_heatmap_figure(data["Lx_vals"], data["Lz_vals"], data["min_re_mat"], title)


@app.callback(
    Output("branch-plot", "figure"),
    Input("group-dropdown", "value"),
    Input("heatmap", "clickData"),
    Input("render-eqb", "value"),
)
def update_right_panel(group: str, click_data, render_eqb) -> go.Figure:
    data = get_group_data(group)
    Lx_vals = data["Lx_vals"]
    Lz_vals = data["Lz_vals"]
    if Lx_vals.size == 0 or Lz_vals.size == 0:
        return go.Figure()

    if click_data and "points" in click_data and click_data["points"]:
        pt = click_data["points"][0]
        Lz = nearest_val(Lz_vals, float(pt["x"]))
        Lx = nearest_val(Lx_vals, float(pt["y"]))
    else:
        Lx = float(Lx_vals[0])
        Lz = float(Lz_vals[0])

    branches = data["branches"].get((Lx, Lz), [])
    eqb_shear = None
    if render_eqb and "on" in render_eqb:
        eqb_shear = compute_eqb_shear(group, Lx, Lz, BASE_DIR / group)
    return build_branch_figure(branches, Lx, Lz, eqb_shear_by_id=eqb_shear)


if __name__ == "__main__":
    app.run(debug=True)
