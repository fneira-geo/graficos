"""
treemap.py — Project structure mapper for context.

Extracts file/function/section descriptions using AST (Python), regex
section headers (R), header extraction (Markdown), and Ollama for
undocumented code blocks. Output: TREEMAP.md in project root.

Usage:
    uv run python skills/treemap.py [project_root]
    uv run python skills/treemap.py [project_root] --no-llm
    uv run python skills/treemap.py [project_root] --clear-cache

Author: Fernando Neira-Roman
"""

import ast
import hashlib
import json
import re
import sys
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

# ── Configuration ──────────────────────────────────────────────────────────────

OLLAMA_URL   = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "qwen3.5:35b"
CACHE_FILE   = ".treemap_cache.json"
OUTPUT_FILE  = "TREEMAP.md"

MAX_BLOCK_CHARS = 1200  # max chars sent to Ollama per block
MAX_DESC_CHARS  = 120   # truncate descriptions to this length

# Directories to skip entirely
SKIP_DIRS = {
    ".venv", "venv", "__pycache__", ".git", "node_modules",
    ".renv", "renv",
    # IDE / tool dirs
    ".vscode", ".idea", ".claude", ".copilot", ".rproj.user",
    ".Rproj.user", ".quarto",
    # SKILLS
    "skills",
    # Data & output folders — inputs/results, not source code
    "data", "output", "outputs", "results", "resultados",
}

# Files to skip entirely
SKIP_FILES = {
    "__init__.py", ".DS_Store", "uv.lock", "package-lock.json",
    "yarn.lock", ".python-version", ".gitignore", ".gitattributes",
    "claude.md",
}

# Extensions to skip (binaries, archives, locks)
SKIP_EXTS = {
    ".tar", ".gz", ".zip", ".rar", ".7z",
    ".pdf", ".doc", ".docx", ".xls", ".xlsx",
    ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico",
    ".tif", ".tiff",                          # rasters → skip description
    ".shp", ".dbf", ".shx", ".prj",          # shapefiles
    ".cpg", ".qmd_spatial",                  # other spatial
    ".parquet", ".feather", ".arrow",
    ".nc", ".h5", ".hdf5",                   # scientific data
    ".lock",
}

# Credential filename patterns → skip
CREDENTIAL_PATTERNS = [
    r".*credentials.*\.json$",
    r".*secret.*\.json$",
    r".*key.*\.json$",
    r"agroclima.*\.json$",
    r"coastal.*\.json$",
    r"application_default.*\.json$",
]

# Extensions with LLM-based description
CODE_EXTS = {".py", ".R", ".r", ".js", ".ts", ".sh", ".bash", ".cpp", ".c", ".h"}

# Extensions with header-based description (no LLM)
DOC_EXTS = {".md", ".txt", ".qmd", ".rmd", ".Rmd"}

# Spatial data → label only
SPATIAL_EXTS = {".geojson"}

# Notebook
NOTEBOOK_EXTS = {".ipynb"}

# Config/misc JSON → include without LLM
MISC_EXTS = {".toml", ".yml", ".yaml", ".json", ".env"}

# ── Cache ──────────────────────────────────────────────────────────────────────

def load_cache(root: Path) -> dict:
    p = root / CACHE_FILE
    if p.exists():
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}

def save_cache(root: Path, cache: dict) -> None:
    (root / CACHE_FILE).write_text(
        json.dumps(cache, indent=2, ensure_ascii=False), encoding="utf-8"
    )

def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]

# ── Ollama ─────────────────────────────────────────────────────────────────────

def ollama_describe(code: str, context: str = "") -> str | None:
    prompt = (
        f"Describe in ONE concise sentence (max 15 words) what this code does. "
        f"Context: {context}. "
        f"Reply ONLY with the description, no preamble, no punctuation at end.\n\n"
        f"```\n{code[:MAX_BLOCK_CHARS]}\n```"
    )
    payload = json.dumps({
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.1, "num_predict": 60}
    }).encode()

    try:
        req = urllib.request.Request(
            OLLAMA_URL, data=payload,
            headers={"Content-Type": "application/json"}, method="POST"
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
            result = data.get("response", "").strip().strip(".")
            return result[:MAX_DESC_CHARS] if result else None
    except (urllib.error.URLError, TimeoutError) as e:
        print(f"  [ollama error] {e}")
        return None

def cached_ollama(cache: dict, key: str, code: str, context: str) -> str:
    """Return cached description or call Ollama. Only caches valid responses."""
    if key in cache and cache[key] != "—":
        return cache[key]
    result = ollama_describe(code, context)
    desc = result or "—"
    if result:
        cache[key] = desc
    return desc

# ── Filters ────────────────────────────────────────────────────────────────────

def is_credential(path: Path) -> bool:
    return any(re.match(p, path.name, re.IGNORECASE) for p in CREDENTIAL_PATTERNS)

def is_treemap_output(path: Path) -> bool:
    return path.name == OUTPUT_FILE or re.match(r"TREEMAP.*\.md$", path.name)

def should_skip_file(path: Path) -> bool:
    if path.name in SKIP_FILES:
        return True
    if path.suffix.lower() in SKIP_EXTS:
        return True
    if path.suffix.lower() == ".json" and is_credential(path):
        return True
    if is_treemap_output(path):
        return True
    if path.name == CACHE_FILE:
        return True
    return False

# ── Markdown / text description ────────────────────────────────────────────────

def md_description(path: Path) -> str:
    """Extract H1/H2 headers from markdown/text and build a one-line description."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return "—"

    headers = re.findall(r"^#{1,2}\s+(.+)$", text, re.MULTILINE)
    if not headers:
        # Fallback: first non-empty line
        for line in text.splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                return line[:MAX_DESC_CHARS]
        return "—"

    # Join first 3 headers as context
    desc = " · ".join(h.strip() for h in headers[:3])
    return desc[:MAX_DESC_CHARS]

# ── Notebook description ───────────────────────────────────────────────────────

def notebook_description(path: Path, cache: dict, use_llm: bool) -> str:
    """Extract first markdown cell + first code cell from notebook."""
    try:
        nb = json.loads(path.read_text(encoding="utf-8", errors="replace"))
    except Exception:
        return "—"

    cells = nb.get("cells", [])
    md_text, code_text = "", ""

    for cell in cells:
        ct = cell.get("cell_type", "")
        src = "".join(cell.get("source", []))
        if ct == "markdown" and not md_text:
            # Extract headers
            headers = re.findall(r"^#{1,2}\s+(.+)$", src, re.MULTILINE)
            md_text = " · ".join(headers[:2]) if headers else src[:200]
        if ct == "code" and not code_text:
            code_text = src

    if md_text:
        return md_text[:MAX_DESC_CHARS]

    if code_text and use_llm:
        fhash = file_hash(path)
        return cached_ollama(cache, f"{fhash}:__module__", code_text, f"notebook {path.name}")

    return "—"

# ── Python parsing ─────────────────────────────────────────────────────────────

def python_file_desc(path: Path, cache: dict, use_llm: bool) -> str:
    source = path.read_text(encoding="utf-8", errors="replace")
    fhash  = file_hash(path)
    try:
        tree = ast.parse(source)
        doc  = ast.get_docstring(tree)
        if doc:
            return doc.split("\n")[0].strip()[:MAX_DESC_CHARS]
    except SyntaxError:
        pass
    if use_llm:
        return cached_ollama(cache, f"{fhash}:__module__", source[:800], f"Python module {path.name}")
    return "—"

def parse_python(path: Path, cache: dict, use_llm: bool) -> list[dict]:
    source = path.read_text(encoding="utf-8", errors="replace")
    fhash  = file_hash(path)
    items  = []
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return [{"name": "⚠ parse error", "sig": "", "desc": "Invalid syntax", "kind": "error"}]

    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            continue
        if node.name.startswith("_") and node.name != "__init__":
            continue

        kind      = "class" if isinstance(node, ast.ClassDef) else "func"
        docstring = ast.get_docstring(node) or ""
        desc      = docstring.split("\n")[0].strip()[:MAX_DESC_CHARS] if docstring else ""

        if not desc and use_llm:
            lines = source.splitlines()
            block = "\n".join(lines[node.lineno - 1: getattr(node, "end_lineno", node.lineno + 20)])
            desc  = cached_ollama(cache, f"{fhash}:{node.name}", block, f"{kind} '{node.name}' in {path.name}")

        sig = ""
        if kind == "func":
            args = [a.arg for a in node.args.args]
            sig  = f"({', '.join(args)})"

        items.append({"name": node.name, "sig": sig, "desc": desc or "—", "kind": kind})

    return items

# ── R parsing ──────────────────────────────────────────────────────────────────

# Matches both "## Section Name" and "# section_name  ----" styles
R_SECTION_RE  = re.compile(
    r"^(?:##\s+(.+?)\s*$|#\s+([\w][\w _/]+?)\s*-{4,})",
    re.MULTILINE
)
R_FUNCTION_RE = re.compile(r"^(\w+)\s*<-\s*function\s*\(([^)]*)\)\s*\{", re.MULTILINE)

def _r_section_name(m: re.Match) -> str:
    return (m.group(1) or m.group(2)).strip()

def r_file_desc(path: Path, cache: dict, use_llm: bool) -> str:
    source = path.read_text(encoding="utf-8", errors="replace")
    fhash  = file_hash(path)
    # 1. Roxygen @description tag
    m = re.search(r"#'\s*@description[:\s]+(.+)", source)
    if m:
        return m.group(1).strip()[:MAX_DESC_CHARS]
    # 2. ## METADATA section
    m = re.search(r"## METADATA\s*\n(.*?)(?=\n##|\Z)", source, re.DOTALL)
    if m:
        for line in m.group(1).splitlines():
            line = line.strip().lstrip("#").strip()
            if len(line) > 10 and not line.lower().startswith("author"):
                return line[:MAX_DESC_CHARS]
    if use_llm:
        return cached_ollama(cache, f"{fhash}:__module__", source[:800], f"R script {path.name}")
    return "—"

def parse_r(path: Path, cache: dict, use_llm: bool) -> dict:
    source   = path.read_text(encoding="utf-8", errors="replace")
    fhash    = file_hash(path)
    sections = {}
    matches  = list(R_SECTION_RE.finditer(source))

    for i, m in enumerate(matches):
        sec_name = _r_section_name(m)
        start    = m.end()
        end      = matches[i + 1].start() if i + 1 < len(matches) else len(source)
        block    = source[start:end].strip()
        funcs    = []

        for fm in R_FUNCTION_RE.finditer(block):
            fname = fm.group(1)
            args  = fm.group(2).strip()
            desc  = ""
            # Roxygen @description block immediately before function
            pre_text = block[:fm.start()]
            rox = re.search(r"(?:#'\s*@description[:\s]+(.+))(?:\n#'[^\n]*)?\s*$", pre_text)
            if rox:
                desc = rox.group(1).strip()
            # Inline # comment before function
            if not desc:
                pre_lines = pre_text.rstrip().splitlines()
                if pre_lines and pre_lines[-1].strip().startswith("#"):
                    desc = pre_lines[-1].strip().lstrip("#'").strip()

            if not desc and use_llm:
                snippet = block[fm.start(): fm.start() + 600]
                desc    = cached_ollama(
                    cache, f"{fhash}:{sec_name}:{fname}",
                    snippet, f"R function '{fname}' in section '{sec_name}'"
                )

            funcs.append({"name": fname, "args": args, "desc": desc or "—"})

        sections[sec_name] = funcs

    return sections

# ── Shell / JS / C parsing (lightweight) ──────────────────────────────────────

def generic_file_desc(path: Path, cache: dict, use_llm: bool) -> str:
    """For JS, shell, C/C++ — read header comments or use Ollama on first 800 chars."""
    try:
        source = path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return "—"

    fhash = file_hash(path)
    # Try leading comment block
    lines = source.splitlines()
    header_lines = []
    for line in lines[:20]:
        stripped = line.strip()
        if stripped.startswith(("#", "//", "/*", "*", "'")):
            clean = re.sub(r"^[#/*'\s]+", "", stripped).strip()
            if clean:
                header_lines.append(clean)
        elif header_lines:
            break

    if header_lines:
        return " ".join(header_lines)[:MAX_DESC_CHARS]

    if use_llm:
        return cached_ollama(cache, f"{fhash}:__module__", source[:800], f"script {path.name}")

    return "—"

# ── File status ────────────────────────────────────────────────────────────────

def file_status(path: Path) -> str:
    if not path.exists():
        return "[NO CREADO]"
    if path.parent.name.lower() in {"output", "outputs", "results", "resultados"}:
        return "[GENERADO]"
    return ""

# ── Tree walker ────────────────────────────────────────────────────────────────

def build_tree(root: Path) -> list[tuple[Path, int]]:
    result = []

    def walk(p: Path, depth: int):
        if p.is_dir():
            if p.name in SKIP_DIRS or p.name.startswith("."):
                return
            if depth > 0:
                result.append((p, depth))
            try:
                children = sorted(p.iterdir(), key=lambda x: (x.is_file(), x.name.lower()))
                for child in children:
                    walk(child, depth + 1)
            except PermissionError:
                pass
        else:
            if not should_skip_file(p):
                result.append((p, depth))

    walk(root, 0)
    return result

# ── Description dispatcher ─────────────────────────────────────────────────────

def get_file_desc(path: Path, cache: dict, use_llm: bool) -> str:
    ext = path.suffix.lower()
    if ext in {".py"}:
        return python_file_desc(path, cache, use_llm)
    if ext in {".r"}:
        return r_file_desc(path, cache, use_llm)
    if ext in DOC_EXTS:
        return md_description(path)
    if ext in NOTEBOOK_EXTS:
        return notebook_description(path, cache, use_llm)
    if ext in {".js", ".ts", ".sh", ".bash", ".cpp", ".c", ".h"}:
        return generic_file_desc(path, cache, use_llm)
    if ext in SPATIAL_EXTS:
        return "spatial data (GeoJSON)"
    if ext in MISC_EXTS:
        return ""
    return ""

# ── Call graph ────────────────────────────────────────────────────────────────

def extract_python_imports(path: Path) -> dict:
    """Return {module_name: [names_imported]} from a Python file."""
    source = path.read_text(encoding="utf-8", errors="replace")
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return {}

    imports = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom):
            mod = node.module or ""
            # Only local imports (no dots in module = stdlib/third-party, skip)
            names = [a.name for a in node.names]
            # Keep only if module matches a local file name
            imports.setdefault(mod, []).extend(names)
        elif isinstance(node, ast.Import):
            for alias in node.names:
                imports.setdefault(alias.name, [])
    return imports

def extract_python_calls(path: Path, known_functions: dict[str, str]) -> dict[str, list[str]]:
    """
    Return {script_name: [func_names_called]} for calls to functions
    defined in other local scripts.
    known_functions: {func_name: source_script_stem}
    """
    source = path.read_text(encoding="utf-8", errors="replace")
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return {}

    calls: dict[str, list[str]] = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            name = ""
            if isinstance(node.func, ast.Name):
                name = node.func.id
            elif isinstance(node.func, ast.Attribute):
                name = node.func.attr
            if name and name in known_functions:
                src = known_functions[name]
                if src != path.stem:
                    calls.setdefault(src, [])
                    if name not in calls[src]:
                        calls[src].append(name)
    return calls

def extract_r_sources(path: Path, known_scripts: set[str]) -> list[str]:
    """Return list of script stems sourced via source() in an R file."""
    source = path.read_text(encoding="utf-8", errors="replace")
    found  = re.findall(r'source\(["\']([^"\']+)["\']', source)
    stems  = []
    for f in found:
        stem = Path(f).stem
        if stem in known_scripts:
            stems.append(stem)
    return stems

def extract_r_calls(path: Path, known_functions: dict[str, str]) -> dict[str, list[str]]:
    """Return {script_stem: [func_names_called]} for calls to functions in other R scripts."""
    source = path.read_text(encoding="utf-8", errors="replace")
    calls: dict[str, list[str]] = {}
    # Match bare function calls: word followed by (
    for m in re.finditer(r'\b(\w+)\s*\(', source):
        name = m.group(1)
        if name in known_functions and known_functions[name] != path.stem:
            src = known_functions[name]
            calls.setdefault(src, [])
            if name not in calls[src]:
                calls[src].append(name)
    return calls

def build_call_graph(entries: list[tuple[Path, int]]) -> str:
    """Build ## Call Graph section for TREEMAP.md."""
    py_files = [p for p, _ in entries if p.is_file() and p.suffix == ".py" and p.name != "treemap.py"]
    r_files  = [p for p, _ in entries if p.is_file() and p.suffix.lower() == ".r"]

    lines = ["## Call Graph", ""]

    # ── Python ──
    if py_files:
        # Build known_functions map: func_name → script stem
        known_funcs: dict[str, str] = {}
        for path in py_files:
            try:
                tree = ast.parse(path.read_text(encoding="utf-8", errors="replace"))
                for node in ast.walk(tree):
                    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                        if not node.name.startswith("_"):
                            known_funcs[node.name] = path.stem
            except SyntaxError:
                pass

        lines.append("### Python")
        lines.append("")
        for path in py_files:
            imports = extract_python_imports(path)
            calls   = extract_python_calls(path, known_funcs)
            local_stems = {p.stem for p in py_files}

            # Filter to local scripts only
            local_imports = {k: v for k, v in imports.items() if k in local_stems}
            all_deps = {**local_imports}
            for stem, funcs in calls.items():
                all_deps.setdefault(stem, [])
                all_deps[stem] = list(set(all_deps[stem] + funcs))

            if all_deps:
                lines.append(f"`{path.name}`")
                for dep, names in sorted(all_deps.items()):
                    tag = f"  ({', '.join(sorted(names))})" if names else ""
                    lines.append(f"  → {dep}.py{tag}")
                lines.append("")

    # ── R ──
    if r_files:
        known_r_funcs: dict[str, str] = {}
        r_stems = {p.stem for p in r_files}

        for path in r_files:
            source = path.read_text(encoding="utf-8", errors="replace")
            for m in R_FUNCTION_RE.finditer(source):
                known_r_funcs[m.group(1)] = path.stem

        lines.append("### R")
        lines.append("")
        for path in r_files:
            sources = extract_r_sources(path, r_stems)
            calls   = extract_r_calls(path, known_r_funcs)

            deps: dict[str, list[str]] = {}
            for s in sources:
                deps.setdefault(s, [])
            for stem, funcs in calls.items():
                deps.setdefault(stem, [])
                deps[stem] = list(set(deps.get(stem, []) + funcs))

            if deps:
                lines.append(f"`{path.name}`")
                for dep, funcs in sorted(deps.items()):
                    tag = f"  ({', '.join(sorted(funcs))})" if funcs else ""
                    lines.append(f"  → {dep}.R{tag}")
                lines.append("")

    if not py_files and not r_files:
        lines.append("_No code files found._")
        lines.append("")

    return "\n".join(lines)

# ── Markdown generation ────────────────────────────────────────────────────────

def generate_treemap(root: Path, use_llm: bool) -> str:
    cache    = load_cache(root)
    entries  = build_tree(root)
    descs    = {}

    print(f"  Analyzing {len([e for e in entries if e[0].is_file()])} files...")
    for path, _ in entries:
        if path.is_file():
            descs[path] = get_file_desc(path, cache, use_llm)

    save_cache(root, cache)

    lines = [
        f"# Proyecto: {root.name}",
        "",
        f"_Generado: {datetime.now().strftime('%Y-%m-%d %H:%M')}_",
        "",
        "## Estructura",
        "",
        "```",
        f"{root.name}/",
    ]

    # ASCII tree
    for i, (path, depth) in enumerate(entries):
        next_depth = entries[i + 1][1] if i + 1 < len(entries) else 0
        is_last    = next_depth < depth if i + 1 < len(entries) else True
        indent     = "│   " * (depth - 1) + ("└── " if is_last else "├── ")
        desc       = descs.get(path, "")
        status     = file_status(path) if path.is_file() else ""
        tag_parts  = [s for s in [status, desc] if s]
        tag        = f"  # {' '.join(tag_parts)}" if tag_parts else ""
        lines.append(f"{indent}{path.name}{tag}")

    lines += ["```", "", "## Descripción de archivos", ""]

    # Detailed section — only code files
    for path, _ in entries:
        if not path.is_file():
            continue
        ext  = path.suffix.lower()
        desc = descs.get(path, "")

        if ext == ".py":
            items = parse_python(path, cache, use_llm)
            lines.append(f"### `{path.name}`")
            lines.append(desc or "—")
            if items:
                lines.append("")
                for it in items:
                    prefix = "🔷" if it["kind"] == "class" else "·"
                    lines.append(f"{prefix} `{it['name']}{it['sig']}`  — {it['desc']}")
            lines.append("")

        elif ext == ".r":
            sections = parse_r(path, cache, use_llm)
            lines.append(f"### `{path.name}`")
            lines.append(desc or "—")
            for sec, funcs in sections.items():
                lines.append(f"\n**{sec}**")
                for f in funcs:
                    lines.append(f"· `{f['name']}({f['args']})`  — {f['desc']}")
            lines.append("")

        elif ext in {".js", ".ts", ".sh", ".bash", ".cpp", ".c", ".h"}:
            lines.append(f"### `{path.name}`")
            lines.append(desc or "—")
            lines.append("")

        elif ext in DOC_EXTS | NOTEBOOK_EXTS:
            if desc and desc != "—":
                lines.append(f"### `{path.name}`")
                lines.append(desc)
                lines.append("")

    lines.append(build_call_graph(entries))

    save_cache(root, cache)
    return "\n".join(lines)

# ── Entry point ────────────────────────────────────────────────────────────────

def main():
    args        = sys.argv[1:]
    use_llm     = "--no-llm" not in args
    clear_cache = "--clear-cache" in args
    roots       = [a for a in args if not a.startswith("--")]
    root        = Path(roots[0]).resolve() if roots else Path.cwd()

    if not root.exists():
        print(f"Error: {root} does not exist.")
        sys.exit(1)

    if clear_cache:
        cp = root / CACHE_FILE
        if cp.exists():
            cp.unlink()
            print(f"Cache cleared: {cp}")

    print(f"Mapping: {root}")
    print(f"LLM:     {'enabled (' + OLLAMA_MODEL + ')' if use_llm else 'disabled'}")

    content = generate_treemap(root, use_llm)
    out     = root / OUTPUT_FILE
    out.write_text(content, encoding="utf-8")
    print(f"Written: {out}")

if __name__ == "__main__":
    main()