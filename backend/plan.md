# GitHub MCP Server — Project Plan & Changelog

## 📋 Current State (March 2026)

### ✅ Completed Features

- **Modular package structure** — `github_mcp/` with one file per tool
- **12 MCP Tools** registered via `register_all_tools(mcp)`:
  1. `list_files` — list repo files / directories
  2. `create_branch` — create a branch from any source
  3. `create_file` — create / update a file with a commit
  4. `create_pull_request` — open a PR (supports draft)
  5. `create_project_task` — create Issue or draft card on Projects v2 board
  6. `list_project_tasks` — list board items with offset pagination
  7. `assign_task` — assign users + labels (auto-creates missing labels)
  8. `update_task_status` — move items between Status columns
  9. `create_project_field` — add text/number/date field to a board (idempotent)
  10. `set_task_fields` — set multiple custom field values in one call
  11. `ask_codebase` — RAG Q&A over the indexed GitHub repo (Groq + PGVector)
  12. `explore_codebase` — file explorer backed by PGVector/ChromaDB index
- **RAG pipeline** — `ingest.py` indexes the target GitHub repo into PGVector (default)
- **Shared helpers** — `core/github_api.py`, `utils/project_helpers.py`
- **Documentation** — `docs.html` (interactive), `README.md`, `plan.md`
- **Package manager** — `uv` with `pyproject.toml`

---

## 🗂 File Inventory & Docstring Status

### Top-level scripts

| File           | Module docstring | All functions documented |
| -------------- | ---------------- | ------------------------ |
| `server.py`    | ✅               | ✅                       |
| `ingest.py`    | ✅               | ✅ (added March 2026)    |
| `rag_query.py` | ✅               | ✅                       |

### `github_mcp/` package

| File           | Module docstring | Functions documented   |
| -------------- | ---------------- | ---------------------- |
| `__init__.py`  | ✅               | n/a                    |
| `config.py`    | ✅               | ✅ `validate_config()` |
| `constants.py` | ✅               | n/a (constants only)   |

### `github_mcp/core/`

| File            | Module docstring | Functions documented                                             |
| --------------- | ---------------- | ---------------------------------------------------------------- |
| `__init__.py`   | ✅               | n/a                                                              |
| `github_api.py` | ✅               | ✅ `_headers`, `_gql_headers`, `_raise_for_status`, `_gql_check` |

### `github_mcp/utils/`

| File                 | Module docstring | Functions documented                                  |
| -------------------- | ---------------- | ----------------------------------------------------- |
| `__init__.py`        | ✅               | n/a                                                   |
| `project_helpers.py` | ✅               | ✅ `_resolve_project`, `_find_field`, `_inline_value` |

### `github_mcp/tools/`

| File                 | Tool                               | Module docstring | Tool docstring |
| -------------------- | ---------------------------------- | ---------------- | -------------- |
| `__init__.py`        | `register_all_tools`               | ✅               | ✅             |
| `files.py`           | `list_files`                       | ✅               | ✅             |
| `branches.py`        | `create_branch`                    | ✅               | ✅             |
| `file_operations.py` | `create_file`                      | ✅               | ✅             |
| `pull_requests.py`   | `create_pull_request`              | ✅               | ✅             |
| `tasks.py`           | `create_project_task`              | ✅               | ✅             |
| `task_list.py`       | `list_project_tasks`               | ✅               | ✅             |
| `task_assign.py`     | `assign_task`                      | ✅               | ✅             |
| `task_status.py`     | `update_task_status`               | ✅               | ✅             |
| `project_fields.py`  | `create_project_field`             | ✅               | ✅             |
| `task_fields.py`     | `set_task_fields`                  | ✅               | ✅             |
| `rag_query.py`       | `ask_codebase`, `explore_codebase` | ✅               | ✅ (both)      |

---

## 🎯 Target Architecture

```
GitHubMCP/
├── server.py                   # Main entry point (FastMCP setup)
├── ingest.py                   # RAG ingestion pipeline
├── rag_query.py                # Standalone RAG tester
├── pyproject.toml              # Dependencies (uv managed)
├── README.md                   # Full installation + API reference
├── plan.md                     # This file
├── docs.html                   # Interactive HTML documentation
├── .env                        # Environment variables
│
├── pgvector/                   # Auto-created PGVector mirror (optional dual-store)
├── chroma_store/               # ChromaDB persistence (fallback / dual-store)
│
└── github_mcp/
    ├── __init__.py
    ├── config.py
    ├── constants.py
    ├── core/
    │   └── github_api.py
    ├── utils/
    │   └── project_helpers.py
    └── tools/
        ├── __init__.py
        ├── files.py
        ├── branches.py
        ├── file_operations.py
        ├── pull_requests.py
        ├── tasks.py
        ├── task_list.py
        ├── task_assign.py
        ├── task_status.py
        ├── project_fields.py
        ├── task_fields.py
        └── rag_query.py
```

---

## 📝 Implementation Phases

### Phase 1: Package Structure ✅ COMPLETE

- Created `github_mcp/` directory layout
- Added all `__init__.py` files
- Moved constants + config to dedicated files

### Phase 2: Core & Utils Extraction ✅ COMPLETE

- `core/github_api.py` — `_headers()`, `_gql_headers()`, `_raise_for_status()`, `_gql_check()`
- `utils/project_helpers.py` — `_resolve_project()`, `_find_field()`, `_inline_value()`

### Phase 3: Tool Extraction ✅ COMPLETE

Each tool extracted to its own file (~50–200 lines each).

### Phase 4: RAG Pipeline ✅ COMPLETE

- `ingest.py` — indexes GitHub repo + local docs into ChromaDB
- `rag_query.py` — standalone LCEL chain tester
- `github_mcp/tools/rag_query.py` — `ask_codebase` + `explore_codebase` MCP tools

### Phase 5: Documentation ✅ COMPLETE (March 2026 update)

- `README.md` — full API reference for all 12 tools + module reference
- `docs.html` — interactive HTML doc covering all 12 tools, RAG pipeline, module APIs
- `plan.md` — this file updated with docstring status table
- All Python files have module-level and function-level docstrings

---

## 🔧 Changelog

### March 2026 (latest)

- **PGVector as default vector store** — `RAG_VECTOR_DB=pgvector` is now the default in
  `.env`, `ingest.py`, `rag_query.py`, and `github_mcp/tools/rag_query.py`
- **Fixed async crash** — `ask_codebase` raised `AssertionError: _async_engine not found`
  when using a sync psycopg connection URL. Fixed by adding `_PGVectorSyncRetriever`
  (a `BaseRetriever` subclass that wraps sync `similarity_search()`) inside
  `github_mcp/tools/rag_query.py`; BaseRetriever's default `_aget_relevant_documents`
  runs it safely in a thread executor
- **RAG prompt grounded to target repo** — `_RAG_PROMPT` is now an f-string that reads
  `GITHUB_OWNER`/`GITHUB_REPO` from the environment so answers refer to the correct repo
  (`Bishwajit-2810/The_New_York_Times`) rather than the MCP server project
- **`RAG_SKIP_LOCAL_DOCS` flag** — added to `ingest.py` and defaulted to `true` in
  `.env`; prevents this project's own docs from polluting the target-repo vector store
- **Full documentation pass** — all module-level, function-level, and tool-level
  docstrings updated across `server.py`, `ingest.py`, `rag_query.py` (root), and
  `github_mcp/tools/rag_query.py`
- **`README.md` overhauled** — new "🚀 How to Run This System" section (Steps 0–6),
  restructured env-var table, updated RAG pipeline section, updated module reference
- **`docs.html` updated** — Quick Start, .env block, RAG pipeline §3 (PGVector default,
  new install deps, corrected expected output), Tool 11 `ask_codebase` docstring block,
  `server.py` and `ingest.py` module reference docstring blocks
- Added `ask_codebase` (Tool 11) RAG Q&A tool
- Added `explore_codebase` (Tool 12) file-explorer tool
- Added `--docs-only` flag to `ingest.py`
- Rebuilt `docs.html` — adds Tools 11 & 12, RAG section, module API tables
- Rebuilt `README.md` — full tool reference, module reference, docstring status

### Earlier

- Modular refactor: monolithic `server_fallback.py` split into `github_mcp/` package
- Added Tools 1–10 (GitHub REST + GraphQL)
- Added offset pagination to `list_project_tasks`
- Added `_inline_value()` auto-detect for date/number/text GraphQL mutations
- Added idempotentcy to `create_project_field`
- `assign_task` auto-creates missing labels

---

## 🚀 Benefits of Modular Structure

| Benefit             | Detail                                                         |
| ------------------- | -------------------------------------------------------------- |
| **Maintainability** | Each tool ~50–200 lines; easy to locate and patch              |
| **Testability**     | Import and test each tool in isolation                         |
| **Scalability**     | Add new tools by creating one file + one line in `__init__.py` |
| **Collaboration**   | Clear per-module ownership; minimal merge conflicts            |
| **Discoverability** | File name = tool name; structure is self-documenting           |
