# GitHub MCP Server

A modular GitHub API server built on [FastMCP](https://github.com/jlowin/fastmcp) — 12 MCP tools for repository management, GitHub Projects v2, and AI-powered codebase Q&A through a RAG pipeline (ChromaDB + Groq).

## 📖 Table of Contents

- [Quick Start](#-quick-start)
- [Features](#-features)
- [Project Structure](#-project-structure)
- [Environment Variables](#-environment-variables)
- [Setup & Installation](#-setup--installation)
- [RAG Pipeline](#-rag-pipeline)
- [Tool Reference](#-tool-reference)
  - [list_files](#1-list_files)
  - [create_branch](#2-create_branch)
  - [create_file](#3-create_file)
  - [create_pull_request](#4-create_pull_request)
  - [create_project_task](#5-create_project_task)
  - [list_project_tasks](#6-list_project_tasks)
  - [assign_task](#7-assign_task)
  - [update_task_status](#8-update_task_status)
  - [create_project_field](#9-create_project_field)
  - [set_task_fields](#10-set_task_fields)
  - [ask_codebase](#11-ask_codebase)
  - [explore_codebase](#12-explore_codebase)
- [Module Reference](#-module-reference)
- [Development Guide](#-development-guide)
- [Documentation](#-documentation)
- [License](#-license)

---

## ⚡ Quick Start

```bash
# Clone and install
git clone <your-repo-url>
cd GitHubMCP

# Install uv (if needed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create virtual environment + install deps
uv venv && source .venv/bin/activate
uv pip install -e .

# Configure
cp .env.example .env   # then edit with your credentials

# Index the repo (once)
uv run python ingest.py

# Start the MCP server
uv run python server.py --port 8090

# Inspect the server (optional, in a new terminal)
npx @modelcontextprotocol/inspector
```

The server starts on `http://localhost:8090/sse`.

---

## ✨ Features

| Feature                  | Details                                                                                            |
| ------------------------ | -------------------------------------------------------------------------------------------------- |
| **12 MCP Tools**         | GitHub repo management + AI-powered codebase Q&A                                                   |
| **Modular Architecture** | Each tool in its own file for easy maintenance                                                     |
| **RAG / AI Tools**       | `ask_codebase` and `explore_codebase` via PGVector + Groq                                          |
| **FastMCP Integration**  | Built on the FastMCP framework (SSE transport)                                                     |
| **Secure Config**        | Environment-based secrets via dotenv                                                               |
| **Projects v2 Support**  | Full GitHub Projects v2 API (REST + GraphQL)                                                       |
| **PGVector default**     | Postgres pgvector is the default store; ChromaDB is the fallback                                   |
| **Skip local docs**      | `RAG_SKIP_LOCAL_DOCS=true` keeps the index clean when the target repo is unrelated to this project |
| **Image/Binary Stubs**   | PNG/JPG/PDF etc. indexed as metadata stubs for `explore_codebase`                                  |

---

## 📁 Project Structure

```
GitHubMCP/
├── server.py                   # Main entry point — FastMCP setup + tool registration
├── server_fallback.py          # Original monolithic backup (1 241 lines)
├── ingest.py                   # RAG ingestion: GitHub repo + local docs → ChromaDB
├── rag_query.py                # Standalone RAG chain tester
├── pyproject.toml              # Dependencies managed by uv
├── README.md                   # This file
├── plan.md                     # Project plan & changelog
├── docs.html                   # Interactive HTML documentation
├── .env                        # Your credentials (create from .env.example)
│
├── chroma_store/               # Persisted ChromaDB vector store (auto-created)
│
└── github_mcp/                 # Main Python package
    ├── __init__.py             # Package init — exports version + config constants
    ├── config.py               # Load & validate environment variables
    ├── constants.py            # GitHub API URLs + GraphQL query strings
    │
    ├── core/
    │   ├── __init__.py
    │   └── github_api.py       # _headers(), _gql_headers(), _raise_for_status(), _gql_check()
    │
    ├── utils/
    │   ├── __init__.py
    │   └── project_helpers.py  # _resolve_project(), _find_field(), _inline_value()
    │
    └── tools/
        ├── __init__.py         # register_all_tools() — wires all 12 tools to FastMCP
        ├── files.py            # Tool 1  — list_files
        ├── branches.py         # Tool 2  — create_branch
        ├── file_operations.py  # Tool 3  — create_file
        ├── pull_requests.py    # Tool 4  — create_pull_request
        ├── tasks.py            # Tool 5  — create_project_task
        ├── task_list.py        # Tool 6  — list_project_tasks
        ├── task_assign.py      # Tool 7  — assign_task
        ├── task_status.py      # Tool 8  — update_task_status
        ├── project_fields.py   # Tool 9  — create_project_field
        ├── task_fields.py      # Tool 10 — set_task_fields
        └── rag_query.py        # Tool 11 + 12 — ask_codebase, explore_codebase
```

---

## 🔑 Environment Variables

Create a `.env` file in the project root:

```env
# ── Required ────────────────────────────────────────────
GITHUB_TOKEN=ghp_...          # GitHub Personal Access Token (repo + project scopes)
GITHUB_OWNER=Bishwajit-2810   # GitHub username or org
GITHUB_REPO=The_New_York_Times
PROJECT_ID=2                  # GitHub Projects v2 number from the board URL

# ── AI / RAG ────────────────────────────────────────────
GROQ_API_KEY=gsk_...          # Free at console.groq.com
RAG_VECTOR_DB=pgvector        # chroma | pgvector | both  (default: pgvector)
RAG_SKIP_LOCAL_DOCS=true      # true = only index the target GitHub repo, not local files

# ── PGVector (required when RAG_VECTOR_DB=pgvector or both) ─
POSTGRES_URL=postgresql://postgres:postgres@localhost:5434/ai_db

# ── ChromaDB (required when RAG_VECTOR_DB=chroma or both) ───
RAG_CHROMA_DIR=./chroma_store
```

### GitHub Token Permissions

| Scope      | Purpose                                                  |
| ---------- | -------------------------------------------------------- |
| `repo`     | Full repository access (read/write files, branches, PRs) |
| `project`  | GitHub Projects v2 access                                |
| `read:org` | Required when _owner_ is an organisation                 |

### Get a free Groq API key

Visit [console.groq.com](https://console.groq.com), create an account, and copy the key to `GROQ_API_KEY`.

---

## 🚀 How to Run This System

Follow these steps **in order** every time you set the project up on a new machine, or whenever you want to re-index a different repository.

### Step 0 — Prerequisites

- Python 3.12+
- [uv](https://github.com/astral-sh/uv) — fast Python package manager
- Docker (for PGVector) **or** skip and use ChromaDB (`RAG_VECTOR_DB=chroma`)

### Step 1 — Clone & install dependencies

```bash
git clone <your-repo-url>
cd GitHubMCP

# Install uv (skip if already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create virtual environment
uv venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate

# Install all Python dependencies
uv pip install -e .
```

### Step 2 — Configure .env

```bash
cp .env.example .env
# Edit .env — fill in GITHUB_TOKEN, GROQ_API_KEY, GITHUB_OWNER, GITHUB_REPO, etc.
```

Minimum required keys:

```env
GITHUB_TOKEN=ghp_...
GITHUB_OWNER=Bishwajit-2810
GITHUB_REPO=The_New_York_Times
PROJECT_ID=2
GROQ_API_KEY=gsk_...
RAG_VECTOR_DB=pgvector
POSTGRES_URL=postgresql://postgres:postgres@localhost:5434/ai_db
RAG_SKIP_LOCAL_DOCS=true
```

### Step 3 — Start PGVector (skip if using ChromaDB)

```bash
docker run -d \
  --name pgvector-rag \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=ai_db \
  -p 5434:5432 \
  pgvector/pgvector:pg16
```

Verify it is running:

```bash
docker ps | grep pgvector-rag
```

> **ChromaDB alternative:** Set `RAG_VECTOR_DB=chroma` and skip this step entirely.

### Step 4 — Index the repository (run once)

```bash
uv run python ingest.py
```

This fetches every file from `GITHUB_OWNER/GITHUB_REPO`, splits text into 500-char chunks, embeds them with `sentence-transformers/all-MiniLM-L6-v2`, and loads them into PGVector.

| File type                                               | Action                                  |
| ------------------------------------------------------- | --------------------------------------- |
| `.py .md .js .ts .json .toml .yaml .html .css .sh .sql` | Split into chunks and embedded          |
| `.png .jpg .gif .svg .ico .webp .pdf .zip`              | Stored as metadata stubs (not embedded) |

Expected output:

```
INFO  Default branch: 'master'
INFO  Total files in repo: 42
INFO  Text files loaded : 28
INFO  Binary files found: 14
INFO  Split into 312 chunks
INFO  PGVector: collection 'github_mcp_docs' stored ✅
INFO  Indexed 312 text chunks from 28 text files
INFO  Images found (8): ['logo.png', 'banner.jpg', ...]
```

Re-index after repo changes:

```bash
uv run python ingest.py --reingest         # wipe store, then re-index
uv run python ingest.py --db chroma        # ChromaDB only
uv run python ingest.py --db pgvector      # PGVector only
uv run python ingest.py --db both          # both stores
uv run python ingest.py --docs-only        # local docs only (fast, no GitHub API call)
```

### Step 5 — (Optional) Test the RAG chain

```bash
# Run 3 built-in test questions
uv run python rag_query.py

# Ask a custom question
uv run python rag_query.py "Tell me about this project"
```

### Step 6 — Start the MCP server

```bash
uv run python server.py --port 8090
```

The server listens at **<http://localhost:8090/sse>** and exposes all 12 tools over the MCP / SSE protocol.

### Step 7 — (Optional) Inspect the MCP server

In a new terminal, use the MCP Inspector to test the tools interactively:

```bash
npx @modelcontextprotocol/inspector
```

Then select the server running on port 8090 and interact with the tools in a browser-based UI.

### Switching vector stores without re-indexing

Change `RAG_VECTOR_DB` in `.env` and restart the server — no code changes needed:

| `RAG_VECTOR_DB` | Behaviour                                           |
| --------------- | --------------------------------------------------- |
| `pgvector`      | PGVector only (default, recommended)                |
| `chroma`        | ChromaDB only                                       |
| `both`          | Combined search (ChromaDB + PGVector, deduplicated) |

---

## 🤖 RAG Pipeline

The RAG pipeline indexes the remote GitHub repository into a vector store (PGVector by default), then powers the `ask_codebase` and `explore_codebase` tools.

### Install RAG dependencies

```bash
uv add langchain langchain-community langchain-chroma langchain-huggingface \
       langchain-groq langchain-text-splitters langchain-postgres \
       chromadb sentence-transformers pgvector psycopg2-binary
```

---

## 🛠 Tool Reference

### 1. `list_files`

> **File:** `github_mcp/tools/files.py`

Browse files and directories inside a GitHub repository.

| Parameter | Type  | Default        | Description                         |
| --------- | ----- | -------------- | ----------------------------------- |
| `path`    | `str` | `""`           | Path inside the repo (empty = root) |
| `ref`     | `str` | default branch | Branch / tag / SHA to read from     |
| `owner`   | `str` | `GITHUB_OWNER` | Repo owner                          |
| `repo`    | `str` | `GITHUB_REPO`  | Repository name                     |

**Returns:** `{ repo, path, count, items: [{name, type, size, sha, html_url, download_url}] }`

---

### 2. `create_branch`

> **File:** `github_mcp/tools/branches.py`

Create a new branch from an existing branch.

| Parameter       | Type  | Default        | Description         |
| --------------- | ----- | -------------- | ------------------- |
| `branch`        | `str` | —              | New branch name     |
| `source_branch` | `str` | `"main"`       | Branch to copy from |
| `owner`         | `str` | `GITHUB_OWNER` | Repo owner          |
| `repo`          | `str` | `GITHUB_REPO`  | Repository name     |

**Returns:** `{ repo, branch, source, sha, ref, url }`

---

### 3. `create_file`

> **File:** `github_mcp/tools/file_operations.py`

Create or update a file in a repository with an automatic commit.

| Parameter        | Type  | Default        | Description                                 |
| ---------------- | ----- | -------------- | ------------------------------------------- |
| `file_path`      | `str` | —              | Path inside the repo, e.g. `"src/hello.py"` |
| `content`        | `str` | —              | Plain-text file content                     |
| `commit_message` | `str` | —              | Git commit message                          |
| `branch`         | `str` | `"main"`       | Target branch                               |
| `owner`          | `str` | `GITHUB_OWNER` | Repo owner                                  |
| `repo`           | `str` | `GITHUB_REPO`  | Repository name                             |

**Returns:** `{ repo, action, file_path, branch, commit_sha, commit_url, blob_url }`

---

### 4. `create_pull_request`

> **File:** `github_mcp/tools/pull_requests.py`

Open a pull request on GitHub.

| Parameter | Type   | Default        | Description                         |
| --------- | ------ | -------------- | ----------------------------------- |
| `title`   | `str`  | —              | PR title                            |
| `head`    | `str`  | —              | Source branch (with your changes)   |
| `base`    | `str`  | `"main"`       | Target branch to merge into         |
| `body`    | `str`  | `""`           | PR description (Markdown supported) |
| `draft`   | `bool` | `False`        | Open as a draft PR                  |
| `owner`   | `str`  | `GITHUB_OWNER` | Repo owner                          |
| `repo`    | `str`  | `GITHUB_REPO`  | Repository name                     |

**Returns:** `{ repo, number, title, state, draft, html_url, head, base, created_at }`

---

### 5. `create_project_task`

> **File:** `github_mcp/tools/tasks.py`

Create a task on a GitHub Projects v2 board. Creates a real Issue (if `repo` is set) or a draft card. Optionally sets the Status column immediately.

| Parameter        | Type  | Default        | Description                                             |
| ---------------- | ----- | -------------- | ------------------------------------------------------- |
| `title`          | `str` | —              | Task title                                              |
| `body`           | `str` | `""`           | Description (Markdown supported)                        |
| `status`         | `str` | `None`         | Status column, e.g. `"Todo"`, `"In Progress"`, `"Done"` |
| `project_number` | `int` | `PROJECT_ID`   | Project number from the board URL                       |
| `repo`           | `str` | `GITHUB_REPO`  | Repo name — if given, creates a real Issue              |
| `owner`          | `str` | `GITHUB_OWNER` | Repo / project owner                                    |
| `assignee`       | `str` | `None`         | GitHub username to assign                               |
| `label`          | `str` | `None`         | Label name (auto-created if missing)                    |

**Returns:** `{ project_title, project_id, item_id, title, status, type, issue_url?, issue_number? }`

---

### 6. `list_project_tasks`

> **File:** `github_mcp/tools/task_list.py`

List items on a GitHub Projects v2 board with offset pagination. Returns title, type, status, all custom fields, assignees, labels, URLs.

| Parameter        | Type  | Default        | Description                                 |
| ---------------- | ----- | -------------- | ------------------------------------------- |
| `project_number` | `int` | `PROJECT_ID`   | Project number                              |
| `owner`          | `str` | `GITHUB_OWNER` | Project owner (user or org — auto-detected) |
| `offset`         | `int` | `0`            | 0-based index of the first item             |
| `limit`          | `int` | `50`           | Number of items to return                   |

**Returns:** `{ project_title, project_id, total_count, offset, limit, items, custom_field_names }`

---

### 7. `assign_task`

> **File:** `github_mcp/tools/task_assign.py`

Assign users and labels to a GitHub Issue. Missing labels are auto-created.

| Parameter      | Type        | Default        | Description                            |
| -------------- | ----------- | -------------- | -------------------------------------- |
| `issue_number` | `int`       | —              | Issue number from the URL              |
| `assignees`    | `list[str]` | —              | GitHub usernames (`[]` to clear)       |
| `labels`       | `list[str]` | `None`         | Labels to apply (merged with existing) |
| `repo`         | `str`       | `GITHUB_REPO`  | Repository name                        |
| `owner`        | `str`       | `GITHUB_OWNER` | Repo owner                             |

**Returns:** `{ repo, issue_number, title, state, html_url, assignees, labels, updated_at }`

---

### 8. `update_task_status`

> **File:** `github_mcp/tools/task_status.py`

Move an existing project item between Status columns on the board.

> **Important:** `item_id` must come from `list_project_tasks` — it starts with `PVTI_`.

| Parameter        | Type  | Default        | Description                                          |
| ---------------- | ----- | -------------- | ---------------------------------------------------- |
| `item_id`        | `str` | —              | **Mandatory.** From `list_project_tasks`             |
| `status`         | `str` | —              | New status, e.g. `"Todo"`, `"In Progress"`, `"Done"` |
| `project_number` | `int` | `PROJECT_ID`   | Project number                                       |
| `owner`          | `str` | `GITHUB_OWNER` | Project owner                                        |

**Returns:** `{ item_id, status_updated, project_id }`

---

### 9. `create_project_field`

> **File:** `github_mcp/tools/project_fields.py`

Add a custom field to a GitHub Projects v2 board. Idempotent — returns existing data if the field name already exists.

| Parameter        | Type  | Default        | Description                                              |
| ---------------- | ----- | -------------- | -------------------------------------------------------- |
| `field_name`     | `str` | —              | Display name, e.g. `"Story Points"`, `"Due Date"`        |
| `field_type`     | `str` | —              | One of `"text"`, `"number"`, `"date"` (case-insensitive) |
| `project_number` | `int` | `PROJECT_ID`   | Project number                                           |
| `owner`          | `str` | `GITHUB_OWNER` | Project owner                                            |

**Returns:** `{ project_id, field_id, field_name, field_type, already_existed }`

---

### 10. `set_task_fields`

> **File:** `github_mcp/tools/task_fields.py`

Set one or more custom field values on a project item in one call. Validates all field names before any update is applied.

> **Important:** Call `list_project_tasks` first to get the correct `item_id` and `custom_field_names`.

Value formats: `"YYYY-MM-DD"` for dates, `int/float` for numbers, `str` for text.

| Parameter        | Type   | Default        | Description                                                    |
| ---------------- | ------ | -------------- | -------------------------------------------------------------- |
| `item_id`        | `str`  | —              | **Mandatory.** From `list_project_tasks` — starts with `PVTI_` |
| `fields`         | `dict` | —              | `{ field_name: value }` — names must match project exactly     |
| `project_number` | `int`  | `PROJECT_ID`   | Project number                                                 |
| `owner`          | `str`  | `GITHUB_OWNER` | Project owner                                                  |

**Example:**

```python
set_task_fields(
    item_id="PVTI_lADOBqfXXs4AbcDE",
    fields={
        "Start Date":   "2026-03-01",
        "End Date":     "2026-03-31",
        "Story Points": 8
    }
)
```

**Returns:** `{ item_id, project_id, fields_set, available_field_names }`

---

### 11. `ask_codebase`

> **File:** `github_mcp/tools/rag_query.py`  
> **Requires:** `ingest.py` run first.

Ask a natural-language question about the codebase. Uses RAG (ChromaDB + Groq `openai/gpt-oss-120b`) to return a grounded answer with source-file citations.

| Parameter  | Type  | Description                     |
| ---------- | ----- | ------------------------------- |
| `question` | `str` | Any question about the codebase |

**Example questions:**

```
ask_codebase("How do I add a new MCP tool?")
ask_codebase("What environment variables are required?")
ask_codebase("How does GitHub API authentication work?")
```

**Returns:**

```json
{
  "answer": "To add a new tool, define an async function and decorate it with @mcp.tool() [server.py]...",
  "question": "How do I add a new MCP tool?",
  "model": "openai/gpt-oss-120b",
  "sources": ["rag_query.py", "server.py"]
}
```

---

### 12. `explore_codebase`

> **File:** `github_mcp/tools/rag_query.py`  
> **Requires:** `ingest.py` run first.

Explore the repository structure — find files, list images, read file contents, count files by type.

| Parameter | Type  | Description                         |
| --------- | ----- | ----------------------------------- |
| `query`   | `str` | A structural or file-level question |

**Example queries:**

```
explore_codebase("Are there any image files?")
explore_codebase("How many Python files are there?")
explore_codebase("Show me the contents of server.py")
explore_codebase("List all .md files")
explore_codebase("What files are in the tools folder?")
explore_codebase("Find all files with 'config' in the name")
explore_codebase("What file types exist in this repo?")
```

**Returns:**

```json
{
  "answer": "There are 8 image files: logo.png, banner.jpg...",
  "matched_files": ["logo.png", "banner.jpg"],
  "file_summary": { ".py": 12, ".md": 3, ".png": 5, ".jpg": 3 },
  "total_files": 42,
  "images": [{ "filename": "logo.png", "folder": "assets", "url": "..." }],
  "query": "Are there any image files?"
}
```

---

## 📦 Module Reference

### `server.py` — Main Entry Point

Initialises `FastMCP("github-mcp")`, calls `register_all_tools(mcp)` to wire all 12 tools, and starts the SSE server.

```bash
python server.py [--port PORT] [--host HOST]
```

---

### `ingest.py` — RAG Ingestion

Fetches every file from the target GitHub repo, splits text, embeds, and loads into PGVector (default) and/or ChromaDB.

| Function                            | Returns                    | Description                                                                                |
| ----------------------------------- | -------------------------- | ------------------------------------------------------------------------------------------ |
| `_gh_headers()`                     | `dict`                     | GitHub REST API auth headers                                                               |
| `_get_default_branch()`             | `str`                      | Fetch default branch; falls back to `"main"`                                               |
| `_get_all_repo_files(branch)`       | `list[dict]`               | Full recursive file tree via GitHub Git Trees API                                          |
| `_fetch_file_content(path, branch)` | `str \| None`              | Download raw file content from GitHub                                                      |
| `_strip_html(html)`                 | `str`                      | Strip HTML tags, decode entities, return plain text                                        |
| `_ext(path)`                        | `str`                      | Lowercase extension with dot (e.g. `.py`), or `""`                                         |
| `load_repo_documents(branch)`       | `(text_docs, binary_docs)` | Load all repo files; returns text chunks + binary stubs                                    |
| `load_local_docs()`                 | `list[Document]`           | Walk project root for `.html .md .txt .rst` docs (skipped when `RAG_SKIP_LOCAL_DOCS=true`) |
| `split_docs(docs)`                  | `list[Document]`           | 500-char chunks, 50-char overlap                                                           |
| `get_embeddings()`                  | `HuggingFaceEmbeddings`    | Load `sentence-transformers/all-MiniLM-L6-v2`                                              |
| `ingest_chroma(docs, emb)`          | `int`                      | Embed + persist to ChromaDB; returns stored doc count                                      |
| `ingest_pgvector(docs, emb)`        | `None`                     | Embed + persist to PGVector (requires `POSTGRES_URL`)                                      |
| `main()`                            | `None`                     | CLI entry point — `--db`, `--reingest`, `--docs-only` flags                                |

Key env vars consumed:

| Variable              | Default          | Description                              |
| --------------------- | ---------------- | ---------------------------------------- |
| `RAG_VECTOR_DB`       | `pgvector`       | `chroma \| pgvector \| both`             |
| `RAG_SKIP_LOCAL_DOCS` | `false`          | `true` = skip local project doc indexing |
| `POSTGRES_URL`        | —                | Required for PGVector                    |
| `RAG_CHROMA_DIR`      | `./chroma_store` | ChromaDB persistence directory           |

```bash
python ingest.py                    # full index → PGVector (default)
python ingest.py --reingest         # wipe & re-index
python ingest.py --db both          # PGVector + ChromaDB
python ingest.py --docs-only        # local docs only (fast)
```

---

### `rag_query.py` — Standalone RAG Tester

LCEL RAG chain tester. Verifies the vector store and Groq key independently of the MCP server.

| Function                        | Returns         | Description                                                       |
| ------------------------------- | --------------- | ----------------------------------------------------------------- |
| `_load_retriever(embeddings)`   | `BaseRetriever` | Build retriever based on `RAG_VECTOR_DB` (sync-safe for PGVector) |
| `_format_docs(docs)`            | `str`           | Format retrieved docs with `[filename]` headers                   |
| `build_chain()`                 | `chain`         | LCEL: retriever → format_docs → prompt → Groq LLM → parser        |
| `run_question(chain, question)` | `str`           | Invoke chain, print Q&A, return answer                            |
| `main()`                        | `None`          | CLI: built-in test questions or custom question from argv         |

```bash
python rag_query.py                           # 3 built-in test questions
python rag_query.py "Tell me about the project"   # custom question
```

---

### `github_mcp/config.py`

| Symbol              | Type  | Source                                             |
| ------------------- | ----- | -------------------------------------------------- |
| `GITHUB_TOKEN`      | `str` | `GITHUB_TOKEN` env var                             |
| `DEFAULT_OWNER`     | `str` | `GITHUB_OWNER` env var                             |
| `DEFAULT_REPO`      | `str` | `GITHUB_REPO` env var                              |
| `DEFAULT_PROJECT`   | `int` | `PROJECT_ID` env var                               |
| `validate_config()` | —     | Raises `RuntimeError` if `GITHUB_TOKEN` is missing |

---

### `github_mcp/constants.py`

| Symbol               | Description                                                  |
| -------------------- | ------------------------------------------------------------ |
| `GITHUB_API`         | `https://api.github.com`                                     |
| `GRAPHQL_URL`        | `https://api.github.com/graphql`                             |
| `PAGE_SIZE`          | `100` — max items per GraphQL page                           |
| `USER_PROJECT_QUERY` | GraphQL query for user-owned projects                        |
| `ORG_PROJECT_QUERY`  | GraphQL query for org-owned projects                         |
| `BUILTIN_FIELDS`     | Set of built-in field names to skip in custom-field listings |

---

### `github_mcp/core/github_api.py`

| Function                  | Returns | Description                                                       |
| ------------------------- | ------- | ----------------------------------------------------------------- |
| `_headers()`              | `dict`  | REST API headers — `Authorization: Bearer`, `Accept`, API version |
| `_gql_headers()`          | `dict`  | GraphQL headers — adds `Content-Type: application/json`           |
| `_raise_for_status(resp)` | `None`  | Raise `RuntimeError` on HTTP 4xx/5xx with JSON detail             |
| `_gql_check(resp)`        | `dict`  | Raise on HTTP error AND on GraphQL `errors`; return parsed JSON   |

---

### `github_mcp/utils/project_helpers.py`

| Function                                          | Returns | Description                                                |
| ------------------------------------------------- | ------- | ---------------------------------------------------------- |
| `_resolve_project(client, owner, project_number)` | `dict`  | Try user then org query; return `projectV2` node           |
| `_find_field(proj, name)`                         | `dict`  | Find field node by name (case-insensitive)                 |
| `_inline_value(data_type, value)`                 | `str`   | Build inline `{ date/number/text: ... }` block for GraphQL |

---

## 🔧 Development Guide

### Adding a New Tool

1. Create `github_mcp/tools/your_tool.py`:

```python
"""your_tool — one-line summary.

Longer description of what this module does.
"""

from typing import Optional
from fastmcp import FastMCP
from ..core.github_api import _headers

def register_your_tool(mcp: FastMCP) -> None:
    """Register the your_tool tool with the FastMCP server."""

    @mcp.tool()
    async def your_tool(param: str, owner: Optional[str] = None) -> dict:
        """Short description shown to the LLM agent.

        Longer explanation of behaviour and edge cases.

        Args:
            param: What this parameter does.
            owner: Repo owner (defaults to GITHUB_OWNER in .env).

        Returns:
            result: Description of the return value.
        """
        return {"result": "success"}
```

1. Register in `github_mcp/tools/__init__.py`:

```python
from .your_tool import register_your_tool

def register_all_tools(mcp):
    # ... existing tools ...
    register_your_tool(mcp)
```

1. Done — the tool is immediately available over SSE.

---

## 📚 Documentation

| Resource                 | Location                                                               |
| ------------------------ | ---------------------------------------------------------------------- |
| Interactive HTML docs    | Open `docs.html` in a browser                                          |
| Tool docstrings          | `github_mcp/tools/*.py` — each `@mcp.tool()` function                  |
| Module docstrings        | Top of every `.py` file                                                |
| Helper docstrings        | `github_mcp/core/github_api.py`, `github_mcp/utils/project_helpers.py` |
| Project plan & changelog | `plan.md`                                                              |

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

### Credits

- [FastMCP](https://github.com/jlowin/fastmcp) — MCP server framework
- [GitHub REST API](https://docs.github.com/en/rest) and [GraphQL API](https://docs.github.com/en/graphql)
- [LangChain](https://python.langchain.com/) — LCEL RAG chain
- [ChromaDB](https://www.trychroma.com/) — vector store
- [Groq](https://groq.com/) — LLM inference (free tier available)
- [uv](https://github.com/astral-sh/uv) — fast Python package manager
