const catalog = window.CATALOG_DATA || { solutions: [], cases: [], groups: [], counts: {} };

const state = {
  query: "",
  case: "all",
  group: "all",
  bif: "all",
  sort: "shear",
  selectedId: catalog.solutions[0]?.physical_id || "",
};

const els = {
  stats: document.getElementById("catalog-stats"),
  search: document.getElementById("search-input"),
  caseFilter: document.getElementById("case-filter"),
  groupFilter: document.getElementById("group-filter"),
  bifFilter: document.getElementById("bif-filter"),
  sortFilter: document.getElementById("sort-filter"),
  list: document.getElementById("solution-list"),
  detailCase: document.getElementById("detail-case"),
  detailTitle: document.getElementById("detail-title"),
  assetLinks: document.getElementById("asset-links"),
  comparisonImage: document.getElementById("comparison-image"),
  metrics: document.getElementById("metric-grid"),
  dedupSummary: document.getElementById("dedup-summary"),
  dedupTable: document.getElementById("dedup-table"),
  literatureSummary: document.getElementById("literature-summary"),
  literatureTable: document.getElementById("literature-table"),
  eigenSummary: document.getElementById("eigen-summary"),
  eigenGrid: document.getElementById("eigen-grid"),
  eigenLinks: document.getElementById("eigen-links"),
  bifSummary: document.getElementById("bif-summary"),
  bifChart: document.getElementById("bif-chart"),
  emptyChart: document.getElementById("empty-chart"),
  groupTable: document.getElementById("group-table"),
};

function assetUrl(path) {
  return path ? `../${path}` : "";
}

function fmt(value, digits = 5) {
  if (value === null || value === undefined || Number.isNaN(Number(value))) return "n/a";
  if (typeof value === "number") {
    return Number.isInteger(value) ? String(value) : value.toPrecision(digits);
  }
  return String(value);
}

function option(select, value, label) {
  const opt = document.createElement("option");
  opt.value = value;
  opt.textContent = label;
  select.appendChild(opt);
}

function setupControls() {
  els.stats.textContent = `${catalog.counts.solutions || 0} solutions, ${catalog.counts.from_stress_tests || 0} stress tests, ${catalog.counts.with_literature_mapping || 0} literature mapped, ${catalog.counts.with_dns_bifurcation || 0} DNS bifurcations, ${catalog.counts.with_eigen_analysis || 0} eigen analyses, ${catalog.counts.with_dedup_candidates || 0} dedup candidates`;

  option(els.caseFilter, "all", "All");
  for (const item of catalog.cases || []) option(els.caseFilter, item, item);

  option(els.groupFilter, "all", "All");
  for (const item of catalog.groups || []) option(els.groupFilter, item, item);

  els.search.addEventListener("input", () => {
    state.query = els.search.value.trim().toLowerCase();
    render();
  });
  els.caseFilter.addEventListener("change", () => {
    state.case = els.caseFilter.value;
    render();
  });
  els.groupFilter.addEventListener("change", () => {
    state.group = els.groupFilter.value;
    render();
  });
  els.bifFilter.addEventListener("change", () => {
    state.bif = els.bifFilter.value;
    render();
  });
  els.sortFilter.addEventListener("change", () => {
    state.sort = els.sortFilter.value;
    render();
  });
}

function solutionText(solution) {
  return [
    solution.physical_id,
    solution.case,
    solution.catalog_source,
    solution.deduplication?.component_id,
    ...(solution.deduplication?.members || []),
    ...(solution.literature || []).flatMap((row) => [row.literature_label, row.citation_key, row.paper_title, row.object_id]),
    ...(solution.groups || []),
    solution.representative?.group,
  ]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
}

function filteredSolutions() {
  const rows = catalog.solutions.filter((solution) => {
    if (state.query && !solutionText(solution).includes(state.query)) return false;
    if (state.case !== "all" && solution.case !== state.case) return false;
    if (state.group !== "all" && !(solution.groups || []).includes(state.group)) return false;
    if (state.bif === "yes" && !solution.bifurcation?.available) return false;
    if (state.bif === "no" && solution.bifurcation?.available) return false;
    return true;
  });

  rows.sort((a, b) => {
    if (state.sort === "case") return `${a.case}:${a.physical_id}`.localeCompare(`${b.case}:${b.physical_id}`);
    if (state.sort === "id") return a.physical_id.localeCompare(b.physical_id);
    if (state.sort === "groups") return (b.n_groups || 0) - (a.n_groups || 0) || a.physical_id.localeCompare(b.physical_id);
    return (a.shear ?? Number.POSITIVE_INFINITY) - (b.shear ?? Number.POSITIVE_INFINITY);
  });

  if (!rows.some((row) => row.physical_id === state.selectedId)) {
    state.selectedId = rows[0]?.physical_id || catalog.solutions[0]?.physical_id || "";
  }
  return rows;
}

function renderList(rows) {
  els.list.replaceChildren();
  for (const solution of rows) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `solution-card${solution.physical_id === state.selectedId ? " active" : ""}`;
    button.addEventListener("click", () => {
      state.selectedId = solution.physical_id;
      render();
    });

    const img = document.createElement("img");
    img.alt = "";
    if (solution.assets?.dns_ode_comparison) {
      img.src = assetUrl(solution.assets.dns_ode_comparison);
    } else {
      img.className = "thumb-missing";
    }

    const body = document.createElement("div");
    const title = document.createElement("h2");
    title.textContent = solution.physical_id;
    const meta = document.createElement("p");
    meta.textContent = `${solution.case} | shear ${fmt(solution.shear, 4)} | L2 ${fmt(solution.L2, 4)}`;

    const badges = document.createElement("div");
    badges.className = "badges";
    for (const group of solution.groups || []) {
      const badge = document.createElement("span");
      badge.className = "badge";
      badge.textContent = group;
      badges.appendChild(badge);
    }
    const bifBadge = document.createElement("span");
    bifBadge.className = `badge ${solution.bifurcation?.available ? "ok" : "warn"}`;
    bifBadge.textContent = solution.bifurcation?.available ? "DNS curve" : "No DNS curve";
    badges.appendChild(bifBadge);
    if ((solution.literature || []).length) {
      const litBadge = document.createElement("span");
      litBadge.className = "badge ok";
      litBadge.textContent = "Literature";
      badges.appendChild(litBadge);
    }

    body.append(title, meta, badges);
    button.append(img, body);
    els.list.appendChild(button);
  }
}

function setImage(img, path, label) {
  img.classList.toggle("is-missing", !path);
  if (path) {
    img.src = assetUrl(path);
    img.alt = label;
  } else {
    img.removeAttribute("src");
    img.alt = `${label} not available`;
  }
}

function renderLinks(solution) {
  els.assetLinks.replaceChildren();
  const links = [
    ["Markdown", solution.markdown],
    ["ODE", solution.assets?.ode],
    ["DNS", solution.assets?.dns],
    ["Bif CSV", solution.bifurcation?.csv],
    ["lambda.asc", solution.eigen_analysis?.files?.lambda],
  ];
  for (const [label, path] of links) {
    if (!path) continue;
    const a = document.createElement("a");
    a.href = assetUrl(path);
    a.textContent = label;
    els.assetLinks.appendChild(a);
  }
}

function renderMetrics(solution) {
  const rep = solution.representative || {};
  const diagnostics = solution.dns_diagnostics?.values || {};
  const derived = solution.dns_diagnostics?.derived || {};
  const eigen = solution.eigen_analysis || {};
  const leading = eigen.leading || {};
  const literature = (solution.literature || []).map((row) => row.literature_label).filter(Boolean).join("; ") || "unmapped";
  const groups = [
    {
      title: "Identity",
      rows: [
        ["Source", solution.catalog_source || "eqb_catalog"],
        ["Groups", (solution.groups || []).join(", ")],
        ["Literature", literature],
        ["Representative", `${rep.group || "?"} J${rep.J ?? "?"}K${rep.K ?? "?"}L${rep.L ?? "?"}`],
      ],
    },
    {
      title: "Geometry",
      rows: [
        ["Re", fmt(solution.Re)],
        ["Lx", fmt(solution.Lx)],
        ["Lz", fmt(solution.Lz)],
        ["L2", fmt(solution.L2)],
      ],
    },
    {
      title: "Shear",
      rows: [
        ["Shear", fmt(solution.shear)],
        ["Wall shear", fmt(diagnostics.wallshear)],
        ["I total", fmt(derived.I_total)],
      ],
    },
    {
      title: "Dissipation",
      rows: [
        ["Dissipation", fmt(diagnostics.dissipation)],
        ["D total", fmt(derived.D_total)],
      ],
    },
    {
      title: "DNS diagnostics",
      rows: [
        ["E3D", fmt(diagnostics.e3d)],
      ],
    },
    {
      title: "Stability",
      rows: [
        ["Leading Re(lambda)", fmt(leading.lambda_re)],
        ["Leading Im(lambda)", fmt(leading.lambda_im)],
        ["Unstable eigs", eigen.n_unstable === null || eigen.n_unstable === undefined ? "n/a" : String(eigen.n_unstable)],
      ],
    },
    {
      title: "Bifurcation",
      rows: [
        ["DNS points", String(solution.bifurcation?.n_points || 0)],
        ["Re range", solution.bifurcation?.available ? `${fmt(solution.bifurcation.min_Re)} - ${fmt(solution.bifurcation.max_Re)}` : "n/a"],
        ["Input range", solution.bifurcation?.available ? `${fmt(solution.bifurcation.min_input)} - ${fmt(solution.bifurcation.max_input)}` : "n/a"],
      ],
    },
  ];

  els.metrics.replaceChildren();
  for (const group of groups) {
    const section = document.createElement("section");
    section.className = "metric-group";
    const heading = document.createElement("h3");
    heading.textContent = group.title;
    const table = document.createElement("table");
    table.className = "metric-table";
    const tbody = document.createElement("tbody");
    for (const [label, value] of group.rows) {
      const tr = document.createElement("tr");
      const th = document.createElement("th");
      th.scope = "row";
      th.textContent = label;
      const td = document.createElement("td");
      td.textContent = value || "n/a";
      tr.append(th, td);
      tbody.appendChild(tr);
    }
    table.appendChild(tbody);
    section.append(heading, table);
    els.metrics.appendChild(section);
  }
}

function renderLiterature(solution) {
  const rows = solution.literature || [];
  els.literatureSummary.textContent = rows.length ? `${rows.length} mapped appearance${rows.length === 1 ? "" : "s"}` : "Unmapped";
  els.literatureTable.replaceChildren();
  if (!rows.length) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = 3;
    td.textContent = "No literature mapping recorded yet.";
    tr.appendChild(td);
    els.literatureTable.appendChild(tr);
    return;
  }
  for (const row of rows) {
    const tr = document.createElement("tr");
    const paper = `${row.authors || ""} (${row.year || "n/a"}), ${row.paper_title || ""}`;
    for (const value of [row.literature_label || "", paper, row.notes || row.confidence || ""]) {
      const td = document.createElement("td");
      td.textContent = value;
      tr.appendChild(td);
    }
    els.literatureTable.appendChild(tr);
  }
}

function renderDedup(solution) {
  const dedup = solution.deduplication || {};
  const edges = dedup.edges || [];
  const members = (dedup.members || []).filter((member) => member !== solution.physical_id);
  els.dedupSummary.textContent = edges.length
    ? `${dedup.status || "candidate"} component ${dedup.component_id || "unassigned"}; ${edges.length} candidate edge${edges.length === 1 ? "" : "s"}`
    : members.length
      ? `${dedup.status || "candidate"} component ${dedup.component_id || "unassigned"}`
      : "No candidate recorded";
  els.dedupTable.replaceChildren();
  if (!edges.length) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = 4;
    td.textContent = members.length
      ? `Component members: ${members.join(", ")}`
      : "No cross-parameter ODE deduplication candidate recorded yet.";
    tr.appendChild(td);
    els.dedupTable.appendChild(tr);
    return;
  }
  for (const edge of edges) {
    const other = edge.source_id === solution.physical_id ? edge.target_id : edge.source_id;
    const tr = document.createElement("tr");
    for (const value of [other || "", edge.status || "", fmt(edge.distance), edge.path || ""]) {
      const td = document.createElement("td");
      td.textContent = value;
      tr.appendChild(td);
    }
    els.dedupTable.appendChild(tr);
  }
}

function renderEigen(solution) {
  const eigen = solution.eigen_analysis || {};
  const leading = eigen.leading || {};
  els.eigenSummary.textContent = eigen.available
    ? `${eigen.n_eigenvalues || 0} eigenvalues, ${eigen.n_unstable ?? 0} unstable`
    : eigen.error
      ? "Failed"
      : "Not computed";

  const rows = eigen.available
    ? [
        ["Method", eigen.method || "findeigenvals"],
        ["N", fmt(eigen.parameters?.N, 3)],
        ["Ns", fmt(eigen.parameters?.Ns, 3)],
        ["T", fmt(eigen.parameters?.T, 3)],
        ["Leading lambda", `${fmt(leading.lambda_re)} ${Number(leading.lambda_im || 0) < 0 ? "-" : "+"} ${fmt(Math.abs(leading.lambda_im || 0))}i`],
        ["Leading multiplier", `${fmt(leading.multiplier_re)} ${Number(leading.multiplier_im || 0) < 0 ? "-" : "+"} ${fmt(Math.abs(leading.multiplier_im || 0))}i`],
        ["Residual", fmt(leading.residual)],
        ["Leading vector", leading.eigenvector ? leading.eigenvector.split("/").pop() : "n/a"],
      ]
    : [["Status", eigen.error ? eigen.error.split("\n").slice(-1)[0] : "Not computed"]];

  els.eigenGrid.replaceChildren();
  for (const [label, value] of rows) {
    const div = document.createElement("div");
    div.className = "metric compact";
    const span = document.createElement("span");
    span.textContent = label;
    const strong = document.createElement("strong");
    strong.textContent = value || "n/a";
    div.append(span, strong);
    els.eigenGrid.appendChild(div);
  }

  els.eigenLinks.replaceChildren();
  const links = [
    ["lambda.asc", eigen.files?.lambda],
    ["Lambda.asc", eigen.files?.multipliers],
    ["Residu.asc", eigen.files?.residuals],
    ["Leading vector", leading.eigenvector],
  ];
  for (const [label, path] of links) {
    if (!path) continue;
    const a = document.createElement("a");
    a.href = assetUrl(path);
    a.textContent = label;
    els.eigenLinks.appendChild(a);
  }
}

function renderGroupTable(solution) {
  els.groupTable.replaceChildren();
  for (const row of solution.group_representatives || []) {
    const tr = document.createElement("tr");
    for (const key of ["group", "symmetry", "all_members"]) {
      const td = document.createElement("td");
      td.textContent = row[key] || "";
      tr.appendChild(td);
    }
    els.groupTable.appendChild(tr);
  }
}

function chartColor(direction) {
  if (direction === "minus") return "#1f7a72";
  if (direction === "plus") return "#9b5d1a";
  return "#52616a";
}

function drawChart(solution) {
  const canvas = els.bifChart;
  const ctx = canvas.getContext("2d");
  const ratio = window.devicePixelRatio || 1;
  const rect = canvas.getBoundingClientRect();
  canvas.width = Math.max(1, Math.round(rect.width * ratio));
  canvas.height = Math.max(1, Math.round(rect.height * ratio));
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);

  const width = rect.width;
  const height = rect.height;
  ctx.clearRect(0, 0, width, height);

  const curve = solution.bifurcation?.curve || [];
  els.emptyChart.textContent = curve.length ? "" : "No DNS bifurcation curve available.";
  canvas.style.visibility = curve.length ? "visible" : "hidden";
  if (!curve.length) return;

  const margin = { left: 58, right: 20, top: 18, bottom: 42 };
  const minX = 100;
  const maxX = 500;
  const minY = 0;
  const maxY = 5;

  const xScale = (x) => margin.left + ((x - minX) / Math.max(maxX - minX, 1e-9)) * (width - margin.left - margin.right);
  const yScale = (y) =>
    height - margin.bottom - ((y - minY) / Math.max(maxY - minY, 1e-9)) * (height - margin.top - margin.bottom);

  ctx.strokeStyle = "#d7dee2";
  ctx.lineWidth = 1;

  ctx.fillStyle = "#5f6f78";
  ctx.font = "12px system-ui, sans-serif";
  ctx.textAlign = "right";
  ctx.textBaseline = "middle";
  for (let y = 0; y <= 5; y += 1) {
    const py = yScale(y);
    ctx.strokeStyle = y === 0 ? "#9aa7ad" : "#e4e9ec";
    ctx.beginPath();
    ctx.moveTo(margin.left, py);
    ctx.lineTo(width - margin.right, py);
    ctx.stroke();
    ctx.fillText(String(y), margin.left - 8, py);
  }
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  for (let x = 100; x <= 500; x += 100) {
    const px = xScale(x);
    ctx.strokeStyle = x === 100 ? "#9aa7ad" : "#e4e9ec";
    ctx.beginPath();
    ctx.moveTo(px, margin.top);
    ctx.lineTo(px, height - margin.bottom);
    ctx.stroke();
    ctx.fillText(String(x), px, height - margin.bottom + 8);
  }

  ctx.strokeStyle = "#9aa7ad";
  ctx.beginPath();
  ctx.rect(margin.left, margin.top, width - margin.left - margin.right, height - margin.top - margin.bottom);
  ctx.stroke();

  ctx.textAlign = "center";
  ctx.textBaseline = "alphabetic";
  ctx.fillText("Re", (margin.left + width - margin.right) / 2, height - 10);
  ctx.save();
  ctx.translate(15, (margin.top + height - margin.bottom) / 2);
  ctx.rotate(-Math.PI / 2);
  ctx.fillText("input", 0, 0);
  ctx.restore();

  const directions = [...new Set(curve.map((p) => p.direction || "curve"))];
  ctx.save();
  ctx.beginPath();
  ctx.rect(margin.left, margin.top, width - margin.left - margin.right, height - margin.top - margin.bottom);
  ctx.clip();
  for (const direction of directions) {
    const points = curve.filter((p) => (p.direction || "curve") === direction);
    if (!points.length) continue;
    ctx.strokeStyle = chartColor(direction);
    ctx.lineWidth = 2;
    ctx.beginPath();
    points.forEach((point, idx) => {
      const x = xScale(point.Re);
      const y = yScale(point.input);
      if (idx === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();
  }
  ctx.restore();
}

function renderDetail(solution) {
  if (!solution) return;
  els.detailCase.textContent = `${solution.case} | Re ${fmt(solution.Re)} | ${solution.groups.join(", ")}`;
  els.detailTitle.textContent = solution.physical_id;
  setImage(els.comparisonImage, solution.assets?.dns_ode_comparison, "DNS and ODE comparison plot");
  renderLinks(solution);
  renderMetrics(solution);
  renderDedup(solution);
  renderLiterature(solution);
  renderEigen(solution);
  renderGroupTable(solution);

  const bif = solution.bifurcation || {};
  els.bifSummary.textContent = bif.available
    ? `${bif.n_points} points, Re ${fmt(bif.min_Re)} - ${fmt(bif.max_Re)}`
    : "Not available";
  drawChart(solution);
}

function render() {
  const rows = filteredSolutions();
  renderList(rows);
  renderDetail(catalog.solutions.find((solution) => solution.physical_id === state.selectedId) || rows[0]);
}

window.addEventListener("resize", () => {
  const solution = catalog.solutions.find((item) => item.physical_id === state.selectedId);
  if (solution) drawChart(solution);
});

setupControls();
render();
