#!/usr/bin/env python3
"""Compare DNS and ODE alpha-gamma maps for group E.

Panels:
- DNS min-Re grid map (from dns_space_map/grid_map/E/re_min_grid_map.csv)
- ODE min-Re heatmap at JKL=(2,4,7)
- ODE min-Re heatmap at JKL=(1,3,5)
- Overlayed continuation/bifurcation curves at clicked (Lx, Lz)
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
from typing import Dict, List, Tuple, Optional

import numpy as np
import pandas as pd
from dash import Dash, dcc, html, Input, Output, callback_context
import plotly.graph_objects as go
from plotly.subplots import make_subplots


HERE = Path(__file__).resolve().parent
GROUP = "E"
LX_RANGE = (5.0, 15.0)
LZ_RANGE = (2.0, 10.0)

DNS_CSV = HERE / "eqb_alpha_gamma_grid" / "dns_space_map" / "grid_map" / GROUP / "re_min_grid_map.csv"
ODE135_DIR = HERE / "eqb_alpha_gamma_grid" / "minre_continuation" / GROUP
ODE247_DIR = HERE / "eqb_alpha_gamma_grid" / "multires_ode_continuation" / GROUP / "J2K4L7" / "geometry_grid"

ODE_BIF_PATTERN = re.compile(
    r"^bif_(?:(?P<group>[A-G])_)?Lx(?P<Lx>[0-9.]+)_Lz(?P<Lz>[0-9.]+)_id(?P<id>\d+)\.csv$"
)


@dataclass
class Branch:
    dataset: str
    Lx: float
    Lz: float
    branch_id: int
    x: np.ndarray  # Re
    y: np.ndarray  # shear/obs
    y_label: str


def round_key(value: float, ndigits: int = 4) -> float:
    return float(f"{value:.{ndigits}f}")


def nearest_val(vals: np.ndarray, target: float) -> float:
    if vals.size == 0:
        return float(target)
    idx = int(np.argmin(np.abs(vals - target)))
    return float(vals[idx])


def read_dns_grid(csv_path: Path) -> pd.DataFrame:
    if not csv_path.is_file():
        return pd.DataFrame()
    df = pd.read_csv(csv_path)
    # Expect columns from dns_continuesoln_map grid output.
    needed = {"target_Lx", "target_Lz", "min_Re", "status"}
    if not needed.issubset(df.columns):
        return pd.DataFrame()
    for col in ("target_Lx", "target_Lz", "min_Re"):
        df[col] = pd.to_numeric(df[col], errors="coerce")
    df["status"] = df["status"].astype(str)
    if "re_out_dir" in df.columns:
        df["re_out_dir"] = df["re_out_dir"].fillna("").astype(str)
    else:
        df["re_out_dir"] = ""
    if "ix" in df.columns:
        df["ix"] = pd.to_numeric(df["ix"], errors="coerce")
    if "iz" in df.columns:
        df["iz"] = pd.to_numeric(df["iz"], errors="coerce")
    df["Lx"] = df["target_Lx"].map(round_key)
    df["Lz"] = df["target_Lz"].map(round_key)
    return df


def read_ode_minre(group_dir: Path, group: str = GROUP) -> pd.DataFrame:
    path = group_dir / "bifurcations" / f"min_re_{group}.csv"
    if not path.is_file():
        return pd.DataFrame()
    df = pd.read_csv(path)
    needed = {"Lx", "Lz", "id", "min_Re"}
    if not needed.issubset(df.columns):
        return pd.DataFrame()
    for c in ("Lx", "Lz", "min_Re"):
        df[c] = pd.to_numeric(df[c], errors="coerce")
    df["id"] = pd.to_numeric(df["id"], errors="coerce").astype("Int64")
    df["Lx"] = df["Lx"].map(round_key)
    df["Lz"] = df["Lz"].map(round_key)
    return df.dropna(subset=["Lx", "Lz", "min_Re"])


def read_grid_points_csv(path: Path) -> pd.DataFrame:
    if not path.is_file():
        return pd.DataFrame(columns=["Lx", "Lz"])
    try:
        df = pd.read_csv(path)
    except Exception:
        return pd.DataFrame(columns=["Lx", "Lz"])
    if not {"Lx", "Lz"}.issubset(df.columns):
        return pd.DataFrame(columns=["Lx", "Lz"])
    df = df[["Lx", "Lz"]].copy()
    df["Lx"] = pd.to_numeric(df["Lx"], errors="coerce")
    df["Lz"] = pd.to_numeric(df["Lz"], errors="coerce")
    df = df.dropna()
    if df.empty:
        return df
    df["Lx"] = df["Lx"].map(round_key)
    df["Lz"] = df["Lz"].map(round_key)
    return df.drop_duplicates()


def read_ode_grid_axes(group_dir: Path, group: str = GROUP) -> Tuple[np.ndarray, np.ndarray]:
    pts = []
    for name in [f"completed_grid_{group}.csv", f"unsolved_grid_{group}.csv", f"summary_{group}.csv"]:
        p = group_dir / name
        if p.is_file():
            d = read_grid_points_csv(p)
            if not d.empty:
                pts.append(d)
    if not pts:
        return np.array([]), np.array([])
    df = pd.concat(pts, ignore_index=True).drop_duplicates()
    return infer_grid_vals(df, lx_col="Lx", lz_col="Lz")


def infer_grid_vals(df: pd.DataFrame, lx_col: str = "Lx", lz_col: str = "Lz") -> Tuple[np.ndarray, np.ndarray]:
    if df.empty:
        return np.array([]), np.array([])
    Lx_vals = np.array(sorted(set(float(v) for v in df[lx_col].dropna().tolist())), dtype=float)
    Lz_vals = np.array(sorted(set(float(v) for v in df[lz_col].dropna().tolist())), dtype=float)
    return Lx_vals, Lz_vals


def build_heatmap_matrix(df: pd.DataFrame, Lx_vals: np.ndarray, Lz_vals: np.ndarray, *, lx_col="Lx", lz_col="Lz", val_col="min_Re", ok_status_only=False) -> np.ndarray:
    # Plotly heatmap expects z.shape == (len(y), len(x)); here y=Lz, x=Lx.
    mat = np.full((len(Lz_vals), len(Lx_vals)), np.nan, dtype=float)
    if df.empty:
        return mat
    idx_x = {float(v): i for i, v in enumerate(Lx_vals)}
    idx_z = {float(v): j for j, v in enumerate(Lz_vals)}
    use = df.copy()
    if ok_status_only and "status" in use.columns:
        use = use[use["status"] == "ok"]
    if use.empty:
        return mat
    grouped = use.groupby([lx_col, lz_col], as_index=False)[val_col].min()
    for _, row in grouped.iterrows():
        i = idx_x.get(float(row[lx_col]))
        j = idx_z.get(float(row[lz_col]))
        if i is None or j is None:
            continue
        mat[j, i] = float(row[val_col])
    return mat


def load_ode_branches(group_dir: Path, dataset_name: str) -> Dict[Tuple[float, float], List[Branch]]:
    bif_dir = group_dir / "bifurcations"
    out: Dict[Tuple[float, float], List[Branch]] = {}
    if not bif_dir.is_dir():
        return out
    for path in bif_dir.iterdir():
        m = ODE_BIF_PATTERN.match(path.name)
        if not m:
            continue
        try:
            df = pd.read_csv(path)
        except Exception:
            continue
        if df.empty or "Re" not in df.columns or "shear" not in df.columns:
            continue
        Lx = round_key(float(m.group("Lx")))
        Lz = round_key(float(m.group("Lz")))
        bid = int(m.group("id"))
        br = Branch(
            dataset=dataset_name,
            Lx=Lx,
            Lz=Lz,
            branch_id=bid,
            x=pd.to_numeric(df["Re"], errors="coerce").dropna().to_numpy(),
            y=pd.to_numeric(df["shear"], errors="coerce").dropna().to_numpy(),
            y_label="shear",
        )
        n = min(len(br.x), len(br.y))
        if n == 0:
            continue
        br.x = br.x[:n]
        br.y = br.y[:n]
        out.setdefault((Lx, Lz), []).append(br)
    for k in out:
        out[k].sort(key=lambda b: b.branch_id)
    return out


def parse_mud_file(path: Path) -> Optional[pd.DataFrame]:
    if not path.is_file():
        return None
    rows = []
    with path.open() as f:
        for line in f:
            s = line.strip()
            if not s:
                continue
            if s.startswith("%Re") or s.startswith("%"):
                # header line starts with %Re in Channelflow MuD.asc output
                continue
            parts = s.split()
            if len(parts) < 2:
                continue
            try:
                re_val = float(parts[0])
                obs_val = float(parts[1])
            except ValueError:
                continue
            rows.append((re_val, obs_val))
    if not rows:
        return None
    df = pd.DataFrame(rows, columns=["Re", "obs"])
    return df


def load_dns_branches(dns_df: pd.DataFrame) -> Dict[Tuple[float, float], List[Branch]]:
    out: Dict[Tuple[float, float], List[Branch]] = {}
    if dns_df.empty or "re_out_dir" not in dns_df.columns:
        return out
    for _, row in dns_df.iterrows():
        re_dir = str(row.get("re_out_dir", "")).strip()
        if not re_dir:
            continue
        mud = Path(re_dir) / "MuD.asc"
        df = parse_mud_file(mud)
        if df is None or df.empty:
            continue
        Lx = round_key(float(row["Lx"]))
        Lz = round_key(float(row["Lz"]))
        # Use ix/iz-derived id if available, otherwise one branch per cell.
        bid = 1
        if "ix" in row and "iz" in row and pd.notna(row["ix"]) and pd.notna(row["iz"]):
            try:
                bid = int(row["ix"]) * 1000 + int(row["iz"])
            except Exception:
                pass
        br = Branch(
            dataset="DNS",
            Lx=Lx,
            Lz=Lz,
            branch_id=bid,
            x=df["Re"].to_numpy(dtype=float),
            y=df["obs"].to_numpy(dtype=float),
            y_label="obs",
        )
        out.setdefault((Lx, Lz), []).append(br)
    for k in out:
        out[k].sort(key=lambda b: b.branch_id)
    return out


def median_step(vals: np.ndarray) -> float:
    if vals.size < 2:
        return np.inf
    d = np.diff(np.sort(vals))
    d = d[d > 0]
    if d.size == 0:
        return np.inf
    return float(np.median(d))


class DatasetView:
    def __init__(
        self,
        name: str,
        heatmap_df: pd.DataFrame,
        branches: Dict[Tuple[float, float], List[Branch]],
        *,
        lx_col="Lx",
        lz_col="Lz",
        axis_Lx: Optional[np.ndarray] = None,
        axis_Lz: Optional[np.ndarray] = None,
    ):
        self.name = name
        self.df = heatmap_df
        self.branches = branches
        self.lx_col = lx_col
        self.lz_col = lz_col
        if axis_Lx is None or axis_Lz is None or len(axis_Lx) == 0 or len(axis_Lz) == 0:
            self.Lx_vals, self.Lz_vals = infer_grid_vals(heatmap_df, lx_col=lx_col, lz_col=lz_col)
        else:
            self.Lx_vals = np.array(sorted(float(v) for v in axis_Lx), dtype=float)
            self.Lz_vals = np.array(sorted(float(v) for v in axis_Lz), dtype=float)
        self.dx = median_step(self.Lx_vals)
        self.dz = median_step(self.Lz_vals)

    def minre_matrix(self, ok_status_only=False) -> np.ndarray:
        return build_heatmap_matrix(
            self.df,
            self.Lx_vals,
            self.Lz_vals,
            lx_col=self.lx_col,
            lz_col=self.lz_col,
            val_col="min_Re",
            ok_status_only=ok_status_only,
        )

    def snap(self, Lx: float, Lz: float) -> Optional[Tuple[float, float]]:
        if self.Lx_vals.size == 0 or self.Lz_vals.size == 0:
            return None
        Lx_n = round_key(nearest_val(self.Lx_vals, Lx))
        Lz_n = round_key(nearest_val(self.Lz_vals, Lz))
        return (Lx_n, Lz_n)

    def snap_if_close(self, Lx: float, Lz: float, tol_factor: float = 0.75) -> Optional[Tuple[float, float]]:
        snapped = self.snap(Lx, Lz)
        if snapped is None:
            return None
        Lx_n, Lz_n = snapped
        dx_ok = True if not np.isfinite(self.dx) else abs(Lx - Lx_n) <= tol_factor * self.dx
        dz_ok = True if not np.isfinite(self.dz) else abs(Lz - Lz_n) <= tol_factor * self.dz
        return snapped if (dx_ok and dz_ok) else None


def build_heatmap_fig(view: DatasetView, matrix: np.ndarray, title: str, selected: Optional[Tuple[float, float]] = None, show_failed=False) -> go.Figure:
    fig = go.Figure()
    fig.add_trace(
        go.Heatmap(
            z=matrix,
            x=view.Lx_vals,
            y=view.Lz_vals,
            colorscale="Turbo",
            colorbar=dict(title="min Re"),
            hovertemplate="Lx=%{x:.4f}<br>Lz=%{y:.4f}<br>min Re=%{z:.3f}<extra></extra>",
        )
    )
    if show_failed and not view.df.empty and "status" in view.df.columns:
        bad = view.df[(view.df["status"] != "ok") & view.df["min_Re"].notna()]
        if not bad.empty:
            fig.add_trace(
                go.Scatter(
                    x=bad[view.lx_col],
                    y=bad[view.lz_col],
                    mode="markers",
                    name="non-ok",
                    marker=dict(color="rgba(220,50,47,0.8)", symbol="x", size=8),
                    hovertemplate="failed/other<br>Lx=%{x:.4f}<br>Lz=%{y:.4f}<extra></extra>",
                )
            )
    if selected is not None:
        Lx_sel, Lz_sel = selected
        fig.add_trace(
            go.Scatter(
                x=[Lx_sel],
                y=[Lz_sel],
                mode="markers",
                name="selected",
                marker=dict(color="white", line=dict(color="black", width=2), size=14, symbol="circle-open"),
                hoverinfo="skip",
            )
        )
    fig.update_layout(
        title=title,
        xaxis=dict(title="Lx", range=[LX_RANGE[0], LX_RANGE[1]]),
        yaxis=dict(title="Lz", range=[LZ_RANGE[0], LZ_RANGE[1]]),
        height=420,
        margin=dict(l=55, r=10, t=45, b=45),
        clickmode="event+select",
        showlegend=False,
    )
    return fig


def build_overlay_fig(selected: Tuple[float, float], dns_view: DatasetView, ode247_view: DatasetView, ode135_view: DatasetView) -> go.Figure:
    Lx, Lz = selected
    fig = go.Figure()

    datasets = [
        ("DNS", dns_view, "#d62728"),
        ("ODE (2,4,7)", ode247_view, "#1f77b4"),
        ("ODE (1,3,5)", ode135_view, "#2ca02c"),
    ]
    y_labels = set()
    for label, view, color in datasets:
        snapped = view.snap_if_close(Lx, Lz)
        if snapped is None:
            continue
        Lx_n, Lz_n = snapped
        branches = view.branches.get(snapped, [])
        if not branches:
            continue
        for i, b in enumerate(branches):
            y_labels.add(b.y_label)
            fig.add_trace(
                go.Scattergl(
                    x=b.x,
                    y=b.y,
                    mode="lines",
                    line=dict(color=color, width=2, dash="solid" if i == 0 else "dot"),
                    name=f"{label} @ ({Lx_n:.4f},{Lz_n:.4f}) id {b.branch_id}",
                    legendgroup=label,
                    showlegend=True,
                )
            )

    if not fig.data:
        fig.add_annotation(
            text="No bifurcation/continuation curves available near selected point",
            x=0.5,
            y=0.5,
            xref="paper",
            yref="paper",
            showarrow=False,
        )

    ylabel = " / ".join(sorted(y_labels)) if y_labels else "shear / obs"
    fig.update_layout(
        title=f"Overlayed Curves Near Lx={Lx:.4f}, Lz={Lz:.4f}",
        xaxis_title="Re",
        yaxis_title=ylabel,
        height=520,
        margin=dict(l=60, r=20, t=55, b=45),
        legend=dict(orientation="v", y=1.0, x=1.02, yanchor="top"),
    )
    return fig


def build_status_text(dns_view: DatasetView, ode247_view: DatasetView, ode135_view: DatasetView) -> str:
    def count_valid(mat: np.ndarray) -> int:
        return int(np.isfinite(mat).sum())

    dns_ok = 0
    dns_total = 0
    if not dns_view.df.empty and "status" in dns_view.df.columns:
        dns_total = len(dns_view.df)
        dns_ok = int((dns_view.df["status"] == "ok").sum())
    ode247_total = len(ode247_view.df)
    ode135_total = len(ode135_view.df)
    return (
        f"DNS ok={dns_ok}/{dns_total} | "
        f"ODE (2,4,7) min-Re points={ode247_total} | "
        f"ODE (1,3,5) min-Re points={ode135_total}"
    )


DNS_DF = read_dns_grid(DNS_CSV)
DNS_VIEW = DatasetView("DNS", DNS_DF, load_dns_branches(DNS_DF))

ODE247_MINRE = read_ode_minre(ODE247_DIR)
ODE247_AX_LX, ODE247_AX_LZ = read_ode_grid_axes(ODE247_DIR)
ODE247_VIEW = DatasetView(
    "ODE247",
    ODE247_MINRE,
    load_ode_branches(ODE247_DIR, "ODE (2,4,7)"),
    axis_Lx=ODE247_AX_LX,
    axis_Lz=ODE247_AX_LZ,
)

ODE135_MINRE = read_ode_minre(ODE135_DIR)
ODE135_AX_LX, ODE135_AX_LZ = read_ode_grid_axes(ODE135_DIR)
ODE135_VIEW = DatasetView(
    "ODE135",
    ODE135_MINRE,
    load_ode_branches(ODE135_DIR, "ODE (1,3,5)"),
    axis_Lx=ODE135_AX_LX,
    axis_Lz=ODE135_AX_LZ,
)

DEFAULT_SELECTED = (
    float(DNS_VIEW.Lx_vals[len(DNS_VIEW.Lx_vals) // 2]) if DNS_VIEW.Lx_vals.size else 9.1667,
    float(DNS_VIEW.Lz_vals[len(DNS_VIEW.Lz_vals) // 2]) if DNS_VIEW.Lz_vals.size else 6.3333,
)


app = Dash(__name__)

app.layout = html.Div(
    [
        html.H3("Group E: DNS vs ODE (1,3,5) vs ODE (2,4,7)"),
        html.Div(build_status_text(DNS_VIEW, ODE247_VIEW, ODE135_VIEW), id="status-text", style={"marginBottom": "8px"}),
        dcc.Store(id="selected-point", data={"Lx": DEFAULT_SELECTED[0], "Lz": DEFAULT_SELECTED[1]}),
        html.Div(
            [
                dcc.Graph(id="dns-heatmap", style={"width": "33.3%", "display": "inline-block"}),
                dcc.Graph(id="ode247-heatmap", style={"width": "33.3%", "display": "inline-block"}),
                dcc.Graph(id="ode135-heatmap", style={"width": "33.3%", "display": "inline-block"}),
            ]
        ),
        dcc.Graph(id="overlay-branches"),
    ],
    style={"padding": "10px 14px"},
)


@app.callback(
    Output("selected-point", "data"),
    Input("dns-heatmap", "clickData"),
    Input("ode247-heatmap", "clickData"),
    Input("ode135-heatmap", "clickData"),
)
def choose_selected_point(dns_click, ode247_click, ode135_click):
    ctx = callback_context
    if not ctx.triggered:
        return {"Lx": DEFAULT_SELECTED[0], "Lz": DEFAULT_SELECTED[1]}
    trig = ctx.triggered[0]["prop_id"].split(".")[0]
    data = {"dns-heatmap": dns_click, "ode247-heatmap": ode247_click, "ode135-heatmap": ode135_click}.get(trig)
    if not data or "points" not in data or not data["points"]:
        return {"Lx": DEFAULT_SELECTED[0], "Lz": DEFAULT_SELECTED[1]}
    pt = data["points"][0]
    return {"Lx": float(pt["x"]), "Lz": float(pt["y"])}


@app.callback(
    Output("dns-heatmap", "figure"),
    Output("ode247-heatmap", "figure"),
    Output("ode135-heatmap", "figure"),
    Output("overlay-branches", "figure"),
    Input("selected-point", "data"),
)
def update_all(selected_data):
    Lx = float(selected_data.get("Lx", DEFAULT_SELECTED[0]))
    Lz = float(selected_data.get("Lz", DEFAULT_SELECTED[1]))

    dns_sel = DNS_VIEW.snap(Lx, Lz)
    ode247_sel = ODE247_VIEW.snap(Lx, Lz)
    ode135_sel = ODE135_VIEW.snap(Lx, Lz)

    dns_fig = build_heatmap_fig(
        DNS_VIEW,
        DNS_VIEW.minre_matrix(ok_status_only=True),
        "DNS min Re (status=ok)",
        selected=dns_sel,
        show_failed=True,
    )
    ode247_fig = build_heatmap_fig(
        ODE247_VIEW,
        ODE247_VIEW.minre_matrix(),
        "ODE min Re @ JKL=(2,4,7)",
        selected=ode247_sel,
    )
    ode135_fig = build_heatmap_fig(
        ODE135_VIEW,
        ODE135_VIEW.minre_matrix(),
        "ODE min Re @ JKL=(1,3,5)",
        selected=ode135_sel,
    )
    overlay_fig = build_overlay_fig((Lx, Lz), DNS_VIEW, ODE247_VIEW, ODE135_VIEW)
    return dns_fig, ode247_fig, ode135_fig, overlay_fig


if __name__ == "__main__":
    app.run(debug=True)
