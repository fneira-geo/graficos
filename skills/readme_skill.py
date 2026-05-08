"""
readme_skill.py — Generador automático de README.md usando Ollama.

Analiza la estructura del proyecto, detecta dependencias y genera un
README estructurado con: Resumen, Índice, Instalación y Ejemplos.
Soporta selección de modelo y opciones de salida.

Uso:
    uv run python skills/readme_skill.py [project_root]
    uv run python skills/readme_skill.py [project_root] --model qwen3-coder:latest
    uv run python skills/readme_skill.py [project_root] --model qwen3:latest --overwrite
    uv run python skills/readme_skill.py [project_root] --model qwen3.5:35b --overwrite
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Set

try:
    import ollama
except ImportError:
    print("Error: ollama no está instalado. Ejecuta: uv add ollama")
    sys.exit(1)

# ── Configuración ──────────────────────────────────────────────────────────────

OLLAMA_MODEL_DEFAULT = "qwen3-coder:latest"  # Updated: mejor calidad para este hardware
OUTPUT_FILE = "README.md"

# Directorios a omitir
SKIP_DIRS: Set[str] = {
    ".git", ".venv", "venv", "__pycache__", "node_modules",
    ".renv", ".vscode", ".idea", ".claude",           # IDEs / Claude
    "renv", ".Rproj.user",                            # R
    "skills",                                          # tooling interno
}

# Archivos a omitir (por nombre exacto)
SKIP_FILES: Set[str] = {
    "README.md", "TREEMAP.md", "claude.md", "CLAUDE.md",
    ".env", "LICENSE", "uv.lock", ".treemap_cache.json",
    ".gitignore", ".gitattributes",
}

# Extensiones a omitir
SKIP_EXTENSIONS: Set[str] = {".lock", ".cache", ".log", ".pyc"}

# Archivos clave a incluir en el prompt para mejor contexto
KEY_FILES = ["pyproject.toml", "DESCRIPTION", "main.R", "main.py"]

# ── Argumentos ─────────────────────────────────────────────────────────────────

def parse_args():
    """Parsea argumentos de línea de comandos."""
    parser = argparse.ArgumentParser(
        description="Genera README.md automáticamente usando Ollama",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  uv run python skills/readme_skill.py .
  uv run python skills/readme_skill.py . --model qwen3:latest
  uv run python skills/readme_skill.py /path/to/project --overwrite
        """
    )
    parser.add_argument(
        "project_root",
        nargs="?",
        default=".",
        help="Ruta del proyecto a analizar (default: directorio actual)"
    )
    parser.add_argument(
        "--model",
        default=OLLAMA_MODEL_DEFAULT,
        help=f"Modelo Ollama a usar (default: {OLLAMA_MODEL_DEFAULT})"
    )
    parser.add_argument(
        "--output",
        default=OUTPUT_FILE,
        help=f"Archivo de salida (default: {OUTPUT_FILE})"
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Sobreescribir si el archivo de salida ya existe"
    )
    return parser.parse_args()

# ── Detección de Tecnologías ───────────────────────────────────────────────────

def detect_technologies(root: Path):
    """Detecta tecnologías usadas en el proyecto."""
    techs = []

    # Escanear todos los archivos del proyecto (no solo raíz)
    all_files = {f.name for f in root.rglob("*") if f.is_file() and not any(skip in f.parts for skip in SKIP_DIRS)}

    # Lenguajes
    if any(f.endswith((".py", ".pyx")) for f in all_files):
        techs.append("Python")
    if any(f.endswith((".R", ".r")) for f in all_files):
        techs.append("R")

    # Gestores de dependencias y ambientes
    if "pyproject.toml" in all_files:
        techs.append("uv")
    if "requirements.txt" in all_files:
        techs.append("pip")
    if "environment.yml" in all_files:
        techs.append("conda")
    if "Gemfile" in all_files:
        techs.append("Ruby/Bundler")
    if "go.mod" in all_files:
        techs.append("Go")
    if "Cargo.toml" in all_files:
        techs.append("Rust")

    # Proyectos R específicos
    if "DESCRIPTION" in all_files:
        techs.append("R-package")
    if "renv.lock" in all_files or any(f.endswith(".Rproj") for f in all_files):
        techs.append("R-project")

    # SIG/Geoespacial
    if any(f in all_files for f in ["shapefile.shp", "*.geojson", "*.gpkg"]):
        techs.append("Geospatial/GIS")

    return list(dict.fromkeys(techs))  # Remover duplicados preservando orden

# ── Extracción de Metadatos de Scripts ──────────────────────────────────────────

def get_script_headers(root: Path, max_lines: int = 20) -> str:
    """Extrae encabezados/METADATA de cada script para describir su propósito."""
    headers = []
    extensions = {".R", ".r", ".py", ".sh"}

    for path in sorted(root.rglob("*")):
        # Saltar directorios excluidos
        if any(skip in path.parts for skip in SKIP_DIRS):
            continue

        if path.suffix not in extensions or path.name in SKIP_FILES:
            continue

        try:
            lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()[:max_lines]
            header_text = "\n".join(lines)
            rel_path = path.relative_to(root)
            headers.append(f"### {rel_path}\n```\n{header_text}\n```")
        except Exception:
            pass

    return "\n\n".join(headers) if headers else ""


def get_env_vars(root: Path) -> list:
    """Detecta variables de entorno usadas en el proyecto (Sys.getenv, os.getenv, os.environ)."""
    patterns = [
        r'Sys\.getenv\("(\w+)"\)',
        r"Sys\.getenv\('(\w+)'\)",
        r'os\.getenv\("(\w+)"\)',
        r"os\.getenv\('(\w+)'\)",
        r'os\.environ\["(\w+)"\]',
        r"os\.environ\['(\w+)'\]"
    ]
    found: Set[str] = set()

    for path in root.rglob("*"):
        # Saltar directorios excluidos
        if any(skip in path.parts for skip in SKIP_DIRS):
            continue

        if path.suffix not in {".R", ".r", ".py"}:
            continue

        try:
            content = path.read_text(encoding="utf-8", errors="ignore")
            for pattern in patterns:
                found.update(re.findall(pattern, content))
        except Exception:
            pass

    return sorted(found)


def get_output_listing(root: Path, max_files: int = 20) -> str:
    """Lista archivos en la carpeta output/ para describir resultados."""
    output_dir = root / "output"
    if not output_dir.exists():
        return "*(No hay carpeta output/ aún)*"

    files = [f.name for f in sorted(output_dir.iterdir()) if f.is_file()]
    if not files:
        return "*(Carpeta output/ vacía)*"

    file_list = "\n".join(f"- `{f}`" for f in files[:max_files])
    if len(files) > max_files:
        file_list += f"\n- ... (y {len(files) - max_files} archivos más)"

    return file_list

# ── Obtención de Contexto ───────────────────────────────────────────────────────

def get_project_context(root: Path, limit_files: int = 100):
    """Genera árbol de archivos indentado para que el LLM pueda anotarlo."""
    # Construir árbol de directorios
    tree_structure = {}
    file_count = 0

    for path in sorted(root.rglob("*")):
        # Saltar directorios excluidos
        if any(skip in path.parts for skip in SKIP_DIRS):
            continue

        if path.is_file():
            # Saltar archivos excluidos
            if path.name in SKIP_FILES or path.suffix in SKIP_EXTENSIONS or path.name.startswith("."):
                continue

            rel_path = path.relative_to(root)
            parts = rel_path.parts

            # Agregar a estructura
            current = tree_structure
            for part in parts[:-1]:
                if part not in current:
                    current[part] = {}
                current = current[part]

            current[parts[-1]] = None  # Archivo (sin más niveles)
            file_count += 1

            if file_count >= limit_files:
                break

    # Renderizar árbol
    def render_tree(d, indent=0):
        lines = []
        for key, value in sorted(d.items()):
            if value is None:  # Es un archivo
                lines.append("  " * indent + f"`{key}`")
            else:  # Es directorio
                lines.append("  " * indent + f"{key}/")
                lines.extend(render_tree(value, indent + 1))
        return lines

    tree_lines = render_tree(tree_structure)
    if file_count >= limit_files:
        tree_lines.append("(... y más archivos)")

    return "\n".join(tree_lines) if tree_lines else "(No hay archivos)"

# ── Lectura de Archivos Clave ───────────────────────────────────────────────────

def get_key_file_snippets(root: Path, max_lines: int = 30) -> str:
    """Lee archivos clave del proyecto para enriquecer el contexto del LLM."""
    snippets = []

    for filename in KEY_FILES:
        filepath = root / filename
        if filepath.exists():
            try:
                lines = filepath.read_text(encoding="utf-8", errors="ignore").splitlines()[:max_lines]
                content = "\n".join(lines)
                snippets.append(f"### {filename}\n```\n{content}\n```")
            except Exception as e:
                print(f"⚠️  Advertencia: No se pudo leer {filename}: {e}", file=sys.stderr)

    return "\n\n".join(snippets) if snippets else ""

# ── Generación de README con Ollama ─────────────────────────────────────────────

def generate_readme_content(context: str, key_snippets: str, techs: list, root_name: str, model: str,
                           script_headers: str = "", env_vars: list = None, output_files: str = ""):
    """Genera contenido README profesional y detallado usando Ollama con streaming."""

    if env_vars is None:
        env_vars = []

    tech_str = ", ".join(techs) if techs else "variadas"
    env_vars_block = "\n".join(f"- `{var}`" for var in env_vars) if env_vars else "*(Ninguna detectada)*"

    prompt = f"""Actúa como un experto en documentación de software y ciencia de datos.
Genera un README.md PROFESIONAL Y DETALLADO en ESPAÑOL para el proyecto '{root_name}'.

════════════════════════════════════════════════════════════════════════════════
CONTEXTO DEL PROYECTO
════════════════════════════════════════════════════════════════════════════════

**Tecnologías detectadas:** {tech_str}

**Variables de entorno (.env):**
{env_vars_block}

**Estructura de archivos del proyecto:**
```
{context}
```

**Headers y propósito de cada script:**
{script_headers if script_headers else "(No hay información de headers de scripts)"}

**Archivos de configuración:**
{key_snippets if key_snippets else "(Sin archivos de configuración detectados)"}

**Archivos de salida (output/):**
{output_files}

════════════════════════════════════════════════════════════════════════════════
INSTRUCCIONES DE GENERACIÓN
════════════════════════════════════════════════════════════════════════════════

Genera un README.md con EXACTAMENTE estas 12 secciones en orden:

1. **# Título** (con emoji pertinente al dominio detectado)

2. **Párrafo de descripción detallada** (propósito, dominio, contexto geográfico/científico si aplica)

3. **## 📋 Tabla de contenidos** (con enlaces/anclas a cada sección)

4. **## 🔄 Flujo de datos**
   - Diagrama de texto mostrando: Entrada → Procesamiento → Salida
   - Describe brevemente cada etapa

5. **## 🚀 Inicio rápido**
   - Comandos exactos para clonar y ejecutar el proyecto
   - Incluye los comandos reales (no genéricos)

6. **## 🛠️ Instalación**
   - Para Python con uv: SIEMPRE usa `uv sync` (NUNCA `uv pip install -e .`)
   - Para R: lista los paquetes detectados en DEPENDENCIAS
   - Instrucciones claras y paso a paso

7. **## ⚙️ Configuración**
   - Lista las variables de entorno detectadas
   - Describe el propósito de cada una (si es evidente del código)
   - Nota si hay archivo .env requerido

8. **## 📂 Estructura del proyecto**
   - Árbol indentado de archivos/carpetas
   - IMPORTANTE: Añade comentario inline breve para CADA entrada (archivo o carpeta)
   - Explica qué contiene cada directorio principal
   - Describe el propósito de cada script basándote en sus headers si están disponibles

9. **## 📊 Variables y definiciones** (solo si aplica)
   - Si el proyecto es de meteorología, ciencia o ingeniería, crea tabla:
     | Variable | Descripción | Unidades |
     |----------|-------------|----------|
   - Incluye variables técnicas importantes

10. **## 📤 Resultados y salidas**
    - Lista los archivos generados en output/ y describe qué contienen
    - Formatos de salida esperados
    - Cómo interpretar los resultados

11. **## 🔗 Dependencias externas** (si las hay)
    - Datos externos (NetCDF, shapefiles, bases de datos)
    - APIs o servicios externos
    - Rutas de datos que deben configurarse

12. **## 👤 Autoría**
    - Nombre(s) del autor extraído de los headers de scripts
    - Email si está disponible
    - Año

════════════════════════════════════════════════════════════════════════════════
REGLAS ESTRICTAS
════════════════════════════════════════════════════════════════════════════════

⚠️ USA SOLO información de los archivos proporcionados. NO inventes.

⚠️ El árbol de archivos DEBE tener comentario inline para CADA entrada.
   Formato correcto:
   src/
     plt_heatmap.R          # Visualizaciones de completitud de datos
     utils_color.R          # Paletas de color personalizadas

⚠️ Para instalación Python: `uv sync` (nunca `uv pip install -e .`)

⚠️ Si hay variables técnicas recurrentes, DEBES hacer tabla en sección 9.

⚠️ Extrae el autor REAL desde los headers (@autor, Author:).

⚠️ RESPONDE ÚNICAMENTE CON MARKDOWN, sin explicaciones adicionales.
"""

    print(f"🧠 Generando README con {model}...")
    print("📝 Streaming:")
    print("─" * 60)

    try:
        # Streaming para feedback visual
        readme_chunks = []
        response = ollama.generate(
            model=model,
            prompt=prompt,
            stream=True,
            options={"temperature": 0.3}
        )

        for chunk in response:
            text = chunk.get("response", "")
            if text:
                print(text, end="", flush=True)
                readme_chunks.append(text)

        print("\n" + "─" * 60)
        return "".join(readme_chunks)

    except Exception as e:
        print(f"\n❌ Error al contactar con Ollama: {e}", file=sys.stderr)
        print("💡 Asegúrate de que Ollama está corriendo: ollama serve", file=sys.stderr)
        sys.exit(1)

# ── Ejecución Principal ────────────────────────────────────────────────────────

def main():
    args = parse_args()
    root = Path(args.project_root).resolve()

    # Validar proyecto
    if not root.exists():
        print(f"❌ Error: {root} no existe.")
        sys.exit(1)

    if not root.is_dir():
        print(f"❌ Error: {root} no es un directorio.")
        sys.exit(1)

    # Preparar ruta de salida
    output_path = root / args.output

    # Guardia: archivo ya existe
    if output_path.exists() and not args.overwrite:
        print(f"⚠️  {args.output} ya existe en {root}")
        print("   Use --overwrite para reemplazar.")
        sys.exit(0)

    # Análisis
    print(f"🔍 Analizando proyecto: {root.name}")
    techs = detect_technologies(root)
    context = get_project_context(root)
    key_snippets = get_key_file_snippets(root)
    script_headers = get_script_headers(root)
    env_vars = get_env_vars(root)
    output_files = get_output_listing(root)

    print(f"   Tecnologías detectadas: {', '.join(techs) if techs else 'ninguna'}")
    print(f"   Variables .env encontradas: {len(env_vars)}")
    print(f"   Scripts analizados: {script_headers.count('###')}")
    print()

    # Generación
    readme_md = generate_readme_content(
        context, key_snippets, techs, root.name, args.model,
        script_headers=script_headers,
        env_vars=env_vars,
        output_files=output_files
    )

    # Escritura
    try:
        output_path.write_text(readme_md, encoding="utf-8")
        print("✅ README.md generado con éxito")
        print(f"   Ubicación: {output_path}")
        print(f"   Líneas: {len(readme_md.splitlines())}")
    except Exception as e:
        print(f"❌ Error al escribir {output_path}: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()