import fs from "node:fs";
import path from "node:path";

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    if (i + 1 >= argv.length || argv[i + 1].startsWith("--")) {
      args[key] = "true";
    } else {
      args[key] = argv[i + 1];
      i += 1;
    }
  }
  return args;
}

function splitCsvLine(line) {
  const out = [];
  let current = "";
  let quoted = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (quoted && ch === '"' && line[i + 1] === '"') {
      current += '"';
      i += 1;
    } else if (ch === '"') {
      quoted = !quoted;
    } else if (ch === "," && !quoted) {
      out.push(current);
      current = "";
    } else {
      current += ch;
    }
  }
  out.push(current);
  return out;
}

function readCsv(file) {
  const text = fs.readFileSync(file, "utf8").trim();
  if (!text) return [];
  const [headerLine, ...lines] = text.split(/\r?\n/);
  const header = splitCsvLine(headerLine);
  return lines
    .filter((line) => line.trim())
    .map((line) => {
      const values = splitCsvLine(line);
      return Object.fromEntries(header.map((key, i) => [key, values[i] ?? ""]));
    });
}

function readCatalogData(file) {
  const text = fs.readFileSync(file, "utf8");
  const match = text.match(/^window\.CATALOG_DATA\s*=\s*([\s\S]*);\s*$/);
  if (!match) throw new Error(`Could not parse ${file}`);
  return JSON.parse(match[1]);
}

function writeCatalogData(file, data) {
  fs.writeFileSync(file, `window.CATALOG_DATA = ${JSON.stringify(data, null, 2)};\n`);
}

const args = parseArgs(process.argv.slice(2));
const siteData = path.resolve(args["site-data"] ?? "catalog/site/catalog-data.js");
const rebuiltRoot = path.resolve(args["rebuilt-root"] ?? "catalog/dns_geometry_to_ghc/rebuilt_catalog");
const candidatesPath = path.resolve(args["candidates"] ?? path.join(rebuiltRoot, "comparisons/target_duplicate_candidates.csv"));
const diagnosticsPath = path.resolve(args["diagnostics"] ?? path.join(rebuiltRoot, "comparisons/target_field_diagnostics.csv"));
const pairwisePath = path.resolve(args["pairwise"] ?? path.join(rebuiltRoot, "comparisons/target_pairwise_distances.csv"));

const catalog = readCatalogData(siteData);
const candidates = readCsv(candidatesPath);
const diagnostics = readCsv(diagnosticsPath);
const pairwise = readCsv(pairwisePath);
const byId = new Map(catalog.solutions.map((solution) => [solution.physical_id, solution]));

for (const solution of catalog.solutions) {
  const dedup = solution.deduplication ?? {};
  dedup.edges = (dedup.edges ?? []).filter((edge) => edge.method !== "dns_geometry_to_ghc");
  solution.deduplication = dedup;
  delete solution.geometry_continuation;
}

for (const row of diagnostics) {
  const solution = byId.get(row.physical_id);
  if (!solution) continue;
  solution.geometry_continuation = {
    available: true,
    method: "dns_geometry_to_ghc",
    target_Lx: Number(row.target_Lx),
    target_Lz: Number(row.target_Lz),
    grid: {
      Nx: Number(row.Nx),
      Ny: Number(row.Ny),
      Nz: Number(row.Nz),
    },
    l2norm: Number(row.l2norm),
    near_trivial: row.near_trivial === "true",
    resampled_ubest: path.relative(path.resolve("catalog"), row.resampled_ubest).replaceAll(path.sep, "/"),
  };
}

const componentMembers = new Set();
for (const row of candidates) {
  const distance = Number(row.best_distance);
  const edge = {
    source_id: row.source_id,
    target_id: row.target_id,
    status: "dns target match",
    method: "dns_geometry_to_ghc",
    distance,
    best_shift: row.best_shift,
    path: "dns_geometry_to_ghc/rebuilt_catalog/comparisons/target_pairwise_distances.csv",
  };
  for (const id of [row.source_id, row.target_id]) {
    const solution = byId.get(id);
    if (!solution) continue;
    solution.deduplication ??= {};
    solution.deduplication.edges ??= [];
    solution.deduplication.edges.push(edge);
    solution.deduplication.status = "candidate";
    solution.deduplication.component_id = "dns_geometry_to_ghc";
    solution.deduplication.method = "dns_geometry_to_ghc";
  }
  componentMembers.add(row.source_id);
  componentMembers.add(row.target_id);
}

for (const id of componentMembers) {
  const solution = byId.get(id);
  if (!solution) continue;
  const existing = new Set(solution.deduplication.members ?? []);
  for (const member of componentMembers) existing.add(member);
  solution.deduplication.members = [...existing].sort();
  solution.deduplication.component_size = solution.deduplication.members.length;
}

catalog.counts.with_dedup_candidates = catalog.solutions.filter((solution) => (solution.deduplication?.edges ?? []).length > 0).length;
catalog.counts.with_dns_geometry_to_ghc = diagnostics.length;
catalog.dns_geometry_to_ghc = {
  rebuilt_catalog: "dns_geometry_to_ghc/rebuilt_catalog",
  compared_fields: diagnostics.length,
  pairwise_comparisons: pairwise.length,
  duplicate_candidate_edges: candidates.length,
  candidate_threshold: 1e-3,
  comparison_csv: "dns_geometry_to_ghc/rebuilt_catalog/comparisons/target_pairwise_distances.csv",
  diagnostics_csv: "dns_geometry_to_ghc/rebuilt_catalog/comparisons/target_field_diagnostics.csv",
};

writeCatalogData(siteData, catalog);
console.log(`[wrote] ${siteData}`);
console.log(`[catalog] ${catalog.solutions.length} solutions, ${candidates.length} DNS geometry candidate edges`);
