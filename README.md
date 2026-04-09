# PORTFOLIO-graficos

Portfolio de gráficos estadísticos en R con análisis de datos climáticos.

## Descripción

Este proyecto contiene funciones y scripts para análisis y visualización de datos climatológicos (precipitación, temperatura, etc.) usando R y ggplot2.

## Estructura

```
.
├── main.R                    # Script principal
├── src/
│   ├── opencode_local.R      # ⭐ OpenCode Local - Análisis de código
│   ├── plt_heatmap.R         # Funciones de gráficos
│   └── utils_escribe_climatol.R
├── scripts/
│   └── ...
├── docs/
│   ├── OPENCODE_USAGE.md     # 📖 Guía de uso OpenCode
│   ├── OPENCODE_COMMANDS.md  # 📋 Comandos disponibles
│   └── OLLAMA_SETUP.md       # ⚙️ Setup de Ollama
├── .opcoderc.json            # Configuración OpenCode
└── TEST_OPENCODE.R           # Test suite
```

## OpenCode Local - Análisis de Código con IA

Este proyecto incluye **OpenCode Local**, un agente de IA integrado que proporciona análisis de código, refactoring y consultas sobre el proyecto, sin enviar código a internet.

### Características

- ✅ Análisis de código local
- ✅ Refactoring inteligente
- ✅ Consultas sobre funciones
- ✅ Sin conexión a internet
- ✅ Privacidad garantizada
- ✅ Modelo local: qwen2.5-coder:14b

### Inicio Rápido

```bash
# 1. Inicia Ollama (en otra terminal)
ollama serve

# 2. En R
source("src/opencode_local.R")
config <- opencode_connect()
opencode_analyze_project()
opencode_query("¿Cuál es la función principal?")
```

### Requisitos

- **Ollama corriendo**: `ollama serve`
- **Modelo**: qwen2.5-coder:14b (`ollama pull qwen2.5-coder:14b`)
- **R**: Con paquetes `jsonlite` y `httr`

### Funciones Disponibles

| Función | Descripción |
|---------|------------|
| `opencode_connect()` | Conectar a Ollama |
| `opencode_analyze_project()` | Analizar estructura |
| `opencode_query(question)` | Consulta sobre código |
| `opencode_analyze_function(name)` | Analizar función |
| `opencode_suggest_refactor(pattern)` | Sugerir mejoras |

### Documentación

- [Guía de Uso](docs/OPENCODE_USAGE.md) - Cómo usar OpenCode
- [Referencia de Comandos](docs/OPENCODE_COMMANDS.md) - Todos los comandos
- [Setup de Ollama](docs/OLLAMA_SETUP.md) - Configuración de Ollama
- [Plan de Implementación](PLAN_OPENCODE_LOCAL.md) - Detalles técnicos

### Ejecutar Tests

```bash
# En R
Rscript TEST_OPENCODE.R

# O en terminal con R
R --quiet < TEST_OPENCODE.R
```

## Uso General del Proyecto

### Archivos Principales

- **main.R**: Script principal con análisis
- **src/plt_heatmap.R**: Funciones para gráficos de calor
- **src/utils_escribe_climatol.R**: Utilidades de datos climáticos

### Ejecución

```r
# En R
source("main.R")
```

## Requisitos del Sistema

- R 3.6+
- Paquetes: tidyverse, ggplot2, jsonlite, httr
- Ollama (para OpenCode Local)
- 16GB RAM (para modelo qwen2.5-coder:14b)

## Instalación de Dependencias R

```r
install.packages(c("jsonlite", "httr", "ggplot2", "tidyverse"))
```

## Instalación de Ollama

Descarga e instala desde: https://ollama.ai

Después, descarga el modelo:
```bash
ollama pull qwen2.5-coder:14b
```

## Licencia

[Especificar según sea necesario]

## Autor

[Tu nombre]

## Notas

- OpenCode Local está en modo "plan" (read-only) por defecto
- Primer análisis toma 20-30 segundos
- Consultas posteriores son más rápidas (5-10 segundos)
- Todo el código se procesa localmente, nunca sale de tu máquina
