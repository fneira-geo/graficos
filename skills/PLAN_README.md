# Plan de Mejora: `readme_skill.py`

_Generado: 2026-05-06_

## Resumen Ejecutivo

El skill `readme_skill.py` ha sido mejorado para generar READMEs con estructura fija de 8 secciones (en lugar de 12 variables), integrando contexto de `TREEMAP.md`, `metadata.yaml`, y `.env` real del proyecto. Esto asegura documentación completa y consistente.

---

## Cambios Implementados

### 1. Nuevas funciones de context gathering

#### `get_treemap_content(root: Path) -> str`
- **Fuente:** `TREEMAP.md`
- **Retorna:** Contenido completo del archivo para usar como referencia de estructura
- **Uso:** El LLM puede citar descripciones existentes de archivos sin reinventar

#### `get_metadata_content(root: Path) -> str`
- **Fuente:** `metadata.yaml`
- **Retorna:** Contenido YAML formateado para el prompt
- **Extrae:** Autor, versión, stack (lenguajes, frameworks), convenciones, flujo de datos

#### `get_env_file_content(root: Path) -> str`
- **Fuente:** `.env` (ahora removido de `SKIP_FILES`)
- **Retorna:** Pares `CLAVE=valor` en formato legible para documentación
- **Uso:** El LLM describe cada variable con contexto de su valor real

### 2. Ajustes a funciones existentes

| Función | Cambio | Por qué |
|---|---|---|
| `KEY_FILES` | Agregar `"config.R"` | Capturar librerías y lectura de .env |
| `get_key_file_snippets()` | `max_lines: 30 → 60` | Completar bloque de librerías + `.validar_entorno()` |
| `get_script_headers()` | `max_lines: 20 → 30` | Capturar `@description`, `@author`, `@section` de Roxygen |
| `SKIP_FILES` | Remover `.env` | Permitir lectura del archivo real |

### 3. Nueva estructura de README (8 secciones fijas)

```
1. Encabezado
   - Título con emoji apropiado al dominio
   - Autor, fecha, contacto en formato blockquote

2. Resumen
   - Descripción detallada del proyecto
   - Propósito, dominio científico, contexto geográfico

3. Tabla de contenidos
   - Enlaces a secciones 4-8 (anchors markdown)

4. Flujo de trabajo
   ├── Diagrama: Entrada → Procesamiento → Salida
   ├── Instalación: Comandos exactos (uv sync, Rscript, etc.)
   ├── Configuración: Tabla de variables .env con descripciones
   └── Dependencias: Librerías R + paquetes Python

5. Estructura del repositorio
   - Árbol indentado con comentario inline para CADA línea
   - Describe contenido y propósito de cada carpeta/archivo

6. Glosario
   - Tabla: Variable | Descripción | Unidades/Tipo
   - Incluye: tn, tx, pp, rd, hr, vv, ps (variables meteorológicas)
   - Incluye: términos técnicos (formato long, CLIMATOL, etc.)

7. Ejemplos de salida
   - Archivos generados en `output/`
   - Describe sheets, formatos, contenido esperado

8. Dependencias de datos externos
   - CR2MET (ruta, formato NetCDF)
   - ERA5 (ruta, reanalisis ECMWF)
   - DPA (ruta, shapefiles administrativos)
   - Referencias a variables .env
```

### 4. Actualización del prompt a Ollama

El nuevo prompt:
- Recibe contexto de `metadata.yaml`, `TREEMAP.md`, `.env` real
- Pide exactamente 8 secciones en orden fijo
- Especifica reglas para cada sección (ej: "comentario inline para CADA línea" en estructura del repo)
- Incluye ejemplo de tabla para Glosario y Configuración
- Pide que no invente información, solo use lo proporcionado

---

## Archivos Modificados

### `skills/readme_skill.py`
Cambios de código:

1. **Importes** - agregar soporte para YAML:
   ```python
   try:
       import yaml
   except ImportError:
       print("Error: pyyaml no está instalado. Ejecuta: uv add pyyaml")
       sys.exit(1)
   ```

2. **Nuevas funciones:**
   - `get_treemap_content(root: Path) -> str`
   - `get_metadata_content(root: Path) -> str`
   - `get_env_file_content(root: Path) -> str`

3. **Configuración:**
   - `KEY_FILES` + `"config.R"`
   - `SKIP_FILES` - remover `".env"`

4. **Función `main()`:**
   - Llamar a las 3 nuevas funciones de context gathering
   - Pasar argumentos a `generate_readme_content()`

5. **Función `generate_readme_content()`:**
   - Agregar parámetros: `treemap_content`, `metadata_content`, `env_file_content`
   - Reescribir el prompt para 8 secciones fijas

---

## Verificación & Testing

Después de la implementación, ejecutar:

```bash
# 1. Generar README con el skill mejorado
uv run python skills/readme_skill.py . --overwrite

# 2. Validar secciones (debe haber exactamente 8)
grep -c "^## " README.md    # Debería retornar 7 (+ 1 título = 8)

# 3. Validar contenido específico
grep "Fernando Neira-Roman" README.md      # ✓ Debe encontrarse
grep "fneira.ciren@gmail.com" README.md   # ✓ Debe encontrarse
grep "Glosario" README.md                 # ✓ Sección 6
grep "tn\|tx\|pp" README.md               # ✓ Variables meteorológicas
grep "CR2MET\|ERA5\|DPA" README.md        # ✓ Dependencias externas

# 4. Validar que los datos de .env se documentan
grep "DATA_ENT\|DATA_SAL\|CUT_REG\|DIR_CR2" README.md  # ✓ 6 variables
```

---

## Notas de Implementación

- **Encoding:** UTF-8 en todos los archivos
- **Seguridad:** `.env` se lee, pero solo nombres y valores no-sensibles se pasan al LLM
- **Rollback:** El README antiguo se preserva como `README.md.bak` antes de sobrescribir (si es necesario)
- **Dependencias:** `pyyaml` será agregado a `pyproject.toml`

---

## Próximos pasos opcionales

1. Agregar flag `--dry-run` para imprimir el prompt sin llamar a Ollama
2. Validar automáticamente el README generado (8 secciones, tablas correctas, etc.)
3. Soportar múltiples idiomas (es / en) con flag `--language`
