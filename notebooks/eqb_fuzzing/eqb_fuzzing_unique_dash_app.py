#!/usr/bin/env python3
"""Interactive catalog for unique converged DNS solutions + ODE comparison."""

from __future__ import annotations

from pathlib import Path
import re
import csv
from functools import lru_cache

from dash import Dash, dcc, html, Input, Output
from dash.dash_table import DataTable
import plotly.graph_objects as go
import plotly.colors as pc


BASE = Path(__file__).resolve().parent / "overnight_runs_updated"
UNIQUE_DIR = BASE / "analysis" / "findsoln_unique"
GROUPS = ["A", "B", "C", "D", "E", "F", "G"]
MEMBER_RE = re.compile(r"^sol(?P<sid>\d+)@J(?P<J>\d+)K(?P<K>\d+)L(?P<L>\d+)$")
JKL_DIR_RE = re.compile(r"^jkl_(\d+)_(\d+)_(\d+)$")


def parse_members(members: str) -> list[int]:
    out: list[int] = []
    for t in str(members).split(";"):
        tt = t.strip()
        if not tt:
            continue
        m = MEMBER_RE.match(tt)
        if m:
            out.append(int(m.group("sid")))
    return sorted(set(out))


def parse_jkl(name: str) -> tuple[int, int, int] | None:
    m = JKL_DIR_RE.match(name)
    if not m:
        return None
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    with path.open("r", newline="") as f:
        return list(csv.DictReader(f))


def list_cases() -> list[str]:
    out: list[str] = []
    for p in sorted(UNIQUE_DIR.glob("unique_converged_dns_*.csv")):
        out.append(p.stem.replace("unique_converged_dns_", ""))
    return out


@lru_cache(maxsize=32)
def load_unique(case: str) -> list[dict[str, str]]:
    p = UNIQUE_DIR / f"unique_converged_dns_{case}.csv"
    return read_csv_rows(p)


@lru_cache(maxsize=32)
def load_compare(case: str) -> list[dict[str, str]]:
    p = UNIQUE_DIR / f"ode_dns_compare_{case}.csv"
    return read_csv_rows(p)


def find_bif_curves(case: str, group: str, sol_ids: list[int]) -> list[tuple[str, list[float], list[float]]]:
    curves: list[tuple[str, list[float], list[float]]] = []
    case_dir = BASE / case / group
    if not case_dir.is_dir():
        return curves

    for d in sorted(case_dir.iterdir()):
        if not d.is_dir():
            continue
        jkl = parse_jkl(d.name)
        if jkl is None:
            continue
        J, K, L = jkl
        m = (2 * J + 1) * (2 * K + 1) * (2 * L + 1)
        bif_dir = d / "bifurcations"
        if not bif_dir.is_dir():
            continue
        for sid in sol_ids:
            p = bif_dir / f"bif_{group}_sol{sid:03d}.csv"
            if not p.is_file():
                continue
            try:
                rows = read_csv_rows(p)
            except Exception:
                continue
            if not rows:
                continue
            if "Re" not in rows[0] or "shear" not in rows[0]:
                continue
            try:
                re_vals = [float(r["Re"]) for r in rows]
                sh_vals = [float(r["shear"]) for r in rows]
            except Exception:
                continue
            label = f"sol{sid:03d} J{J}K{K}L{L} (m={m})"
            curves.append((label, re_vals, sh_vals))
    return curves


def make_bif_fig(case: str, group: str, unique_id: str, sol_ids: list[int]) -> go.Figure:
    fig = go.Figure()
    curves = find_bif_curves(case, group, sol_ids)
    if not curves:
        fig.add_annotation(text="No ODE bifurcation curves found.", x=0.5, y=0.5, xref="paper", yref="paper", showarrow=False)
    else:
        palette = pc.qualitative.Dark24
        for i, (label, re_vals, sh_vals) in enumerate(curves):
            fig.add_trace(
                go.Scattergl(
                    x=re_vals,
                    y=sh_vals,
                    mode="lines",
                    name=label,
                    line=dict(color=palette[i % len(palette)], width=2),
                )
            )
    fig.update_layout(
        title=f"{case} | Group {group} | {unique_id} : ODE bifurcation overlays",
        xaxis_title="Re",
        yaxis_title="shear",
        margin=dict(l=55, r=190, t=52, b=45),
        height=720,
        legend=dict(orientation="v", yanchor="top", y=1.0, xanchor="left", x=1.02),
    )
    return fig


def to_float(v: str) -> float:
    try:
        return float(v)
    except Exception:
        return float("nan")


def to_int(v: str) -> int:
    try:
        return int(float(v))
    except Exception:
        return 0


def make_compare_fig(rows: list[dict[str, str]], y_dns: str, y_ode: str, title: str, yaxis_title: str) -> go.Figure:
    fig = go.Figure()
    if not rows:
        fig.add_annotation(text="No matching DNS/ODE comparison rows.", x=0.5, y=0.5, xref="paper", yref="paper", showarrow=False)
    else:
        x = [f"sol{to_int(r.get('sol_id', '0')):03d}" for r in rows]
        y1 = [to_float(r.get(y_dns, "nan")) for r in rows]
        y2 = [to_float(r.get(y_ode, "nan")) for r in rows]
        fig.add_trace(go.Bar(name=f"DNS {y_dns}", x=x, y=y1))
        fig.add_trace(go.Bar(name=f"ODE {y_ode}", x=x, y=y2))
    fig.update_layout(
        title=None,
        barmode="group",
        xaxis_title="solution id",
        yaxis_title=yaxis_title,
        height=220,
        margin=dict(l=45, r=12, t=12, b=35),
        legend=dict(orientation="h", yanchor="bottom", y=1.01, xanchor="left", x=0.0),
    )
    return fig


def make_delta_table_markdown(rows: list[dict[str, str]]) -> str:
    if not rows:
        return "No comparison rows."
    lines = ["sol_id | delta_shear | delta_L2norm", "---|---:|---:"]
    for r in rows:
        sid = to_int(r.get("sol_id", "0"))
        ds = to_float(r.get("delta_shear", "nan"))
        dl2 = to_float(r.get("delta_L2norm", "nan"))
        lines.append(f"{sid:03d} | {ds:.6g} | {dl2:.6g}")
    return "\n".join(lines)


app = Dash(__name__)
cases = list_cases()
default_case = cases[0] if cases else ""
default_group = GROUPS[0]

app.layout = html.Div(
    [
        html.H3("EQB Fuzzing: Unique DNS Catalog + ODE Comparison"),
        html.Div(
            [
                html.Div(
                    [
                        html.Label("Case"),
                        dcc.Dropdown(id="case-dd", options=[{"label": c, "value": c} for c in cases], value=default_case, clearable=False),
                    ],
                    style={"width": "45%", "display": "inline-block"},
                ),
                html.Div(
                    [
                        html.Label("Group"),
                        dcc.Dropdown(id="group-dd", options=[{"label": g, "value": g} for g in GROUPS], value=default_group, clearable=False),
                    ],
                    style={"width": "45%", "display": "inline-block", "marginLeft": "2%"},
                ),
            ]
        ),
        html.Div(
            [
                html.Div(
                    [
                        html.H4("Unique Solutions"),
                        DataTable(
                            id="unique-table",
                            columns=[
                                {"name": "unique_id", "id": "unique_id"},
                                {"name": "shear", "id": "shear"},
                                {"name": "L2", "id": "L2"},
                                {"name": "multiplicity", "id": "multiplicity"},
                                {"name": "members", "id": "members"},
                            ],
                            data=[],
                            row_selectable="single",
                            selected_rows=[],
                            style_table={"overflowX": "auto", "overflowY": "auto", "maxHeight": "230px"},
                            style_cell={"textAlign": "left", "fontFamily": "monospace", "fontSize": "11px", "padding": "4px"},
                        ),
                        html.H4("DNS vs ODE (Shear)", style={"marginTop": "10px", "marginBottom": "4px"}),
                        dcc.Graph(id="cmp-shear-fig", config={"displayModeBar": False}),
                        html.H4("DNS vs ODE (L2/Norm)", style={"marginTop": "8px", "marginBottom": "4px"}),
                        dcc.Graph(id="cmp-norm-fig", config={"displayModeBar": False}),
                        html.H4("Delta (DNS - ODE)", style={"marginTop": "8px", "marginBottom": "4px"}),
                        dcc.Markdown(id="delta-md", style={"fontSize": "12px"}),
                    ],
                    style={"width": "32%", "display": "inline-block", "verticalAlign": "top"},
                ),
                html.Div(
                    [dcc.Graph(id="bif-fig")],
                    style={"width": "67%", "display": "inline-block", "marginLeft": "1%", "verticalAlign": "top"},
                ),
            ]
        ),
    ],
    style={"padding": "10px 14px"},
)


@app.callback(
    Output("group-dd", "options"),
    Output("group-dd", "value"),
    Input("case-dd", "value"),
)
def update_group_options(case: str):
    if not case:
        opts = [{"label": g, "value": g} for g in GROUPS]
        return opts, GROUPS[0]
    rows = load_unique(case)
    available = [g for g in GROUPS if g in {str(r.get("group", "")) for r in rows}]
    if not available:
        available = GROUPS
    opts = [{"label": g, "value": g} for g in available]
    return opts, available[0]


@app.callback(
    Output("unique-table", "data"),
    Output("unique-table", "selected_rows"),
    Input("case-dd", "value"),
    Input("group-dd", "value"),
)
def update_unique_table(case: str, group: str):
    if not case or not group:
        return [], []
    rows = load_unique(case)
    dfg = [r for r in rows if str(r.get("group", "")) == group]
    if not dfg:
        return [], []
    dfg.sort(key=lambda r: str(r.get("unique_id", "")))
    out = [
        {
            "unique_id": r.get("unique_id", ""),
            "shear": r.get("shear", ""),
            "L2": r.get("L2", ""),
            "multiplicity": r.get("multiplicity", ""),
            "members": r.get("members", ""),
        }
        for r in dfg
    ]
    return out, [0]


@app.callback(
    Output("bif-fig", "figure"),
    Output("cmp-shear-fig", "figure"),
    Output("cmp-norm-fig", "figure"),
    Output("delta-md", "children"),
    Input("case-dd", "value"),
    Input("group-dd", "value"),
    Input("unique-table", "data"),
    Input("unique-table", "selected_rows"),
)
def update_figures(case: str, group: str, rows, selected_rows):
    empty = go.Figure()
    if not case or not group or not rows:
        empty.add_annotation(text="No data", x=0.5, y=0.5, xref="paper", yref="paper", showarrow=False)
        return empty, empty, empty, "No comparison rows."
    idx = selected_rows[0] if selected_rows else 0
    idx = max(0, min(idx, len(rows) - 1))
    row = rows[idx]
    unique_id = str(row["unique_id"])
    sol_ids = parse_members(str(row["members"]))

    rows = load_compare(case)
    dfc = [
        r
        for r in rows
        if str(r.get("group", "")) == group and to_int(r.get("sol_id", "0")) in sol_ids
    ]
    dfc.sort(key=lambda r: to_int(r.get("sol_id", "0")))

    bif = make_bif_fig(case, group, unique_id, sol_ids)
    cmp_shear = make_compare_fig(dfc, "dns_shear", "ode_shear", f"{case} | {group} | {unique_id} : shear", "shear")
    cmp_norm = make_compare_fig(dfc, "dns_L2", "ode_norm", f"{case} | {group} | {unique_id} : L2 / norm", "L2 / norm")
    delta_md = make_delta_table_markdown(dfc)
    return bif, cmp_shear, cmp_norm, delta_md


if __name__ == "__main__":
    app.run(debug=True)
