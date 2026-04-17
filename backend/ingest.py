"""RAG Ingestion Script — indexes a GitHub repository into a vector store.

Loads TWO sources into the chosen vector store (PGVector by default):

  1. GitHub Repo  (controlled by GITHUB_OWNER / GITHUB_REPO in .env)
     - Text files (.py .md .js .ts .json .toml .yaml .html .css .sh .sql .txt)
       → split into 500-char chunks and embedded via HuggingFace MiniLM-L6-v2
     - Binary/image files (.png .jpg .gif .svg .webp .ico .bmp .pdf .zip)
       → stored as metadata stubs so explore_codebase can list / count them

  2. Local docs files  (skipped when RAG_SKIP_LOCAL_DOCS=true)
     - Any .html .md .txt file found in the project root (RAG_DOCS_DIR)
     - HTML files: tags stripped, plain text extracted before embedding
     - Tagged with source="local_docs"

Usage:
    python ingest.py                        # full index → default vector DB
    python ingest.py --db pgvector          # PGVector only  (needs POSTGRES_URL)
    python ingest.py --db chroma            # ChromaDB only
    python ingest.py --db both              # both stores in parallel
    python ingest.py --reingest             # wipe existing store(s), then re-index
    python ingest.py --docs-only            # only re-index local docs (fast, no GitHub call)
    python ingest.py --db both --reingest   # full reset into both stores

Required .env keys:
    GITHUB_TOKEN=ghp_...
    GITHUB_OWNER=<owner>          e.g. Bishwajit-2810
    GITHUB_REPO=<repo>            e.g. The_New_York_Times

Optional .env keys:
    POSTGRES_URL=postgresql://postgres:postgres@localhost:5432/rag_db
    RAG_CHROMA_DIR=./chroma_store      (ChromaDB persistence directory)
    RAG_VECTOR_DB=pgvector             (chroma | pgvector | both — default: pgvector)
    RAG_SKIP_LOCAL_DOCS=true           (skip indexing local project docs)
    RAG_DOCS_DIR=.                     (project root to scan for local docs)
"""

import os
import re
import sys
import shutil
import httpx
from dotenv import load_dotenv
from loguru import logger

load_dotenv()

from github_mcp.config import GITHUB_TOKEN, DEFAULT_OWNER, DEFAULT_REPO

from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_chroma import Chroma
from langchain_core.documents import Document

# ── Config ─────────────────────────────────────────────────────────────────────
POSTGRES_URL = os.environ.get("POSTGRES_URL", "")
CHROMA_DIR = os.environ.get("RAG_CHROMA_DIR", "./chroma_store")
EMBED_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
COLLECTION = "github_mcp_docs"

# Local docs: scan the entire project tree for documentation files.
# Any .html / .md / .txt file found anywhere in the project is a candidate.
# Files inside .venv, __pycache__, node_modules, chroma_store are skipped.
# Override the project root with RAG_DOCS_DIR in .env if needed.
# Set RAG_SKIP_LOCAL_DOCS=true in .env to skip local doc indexing entirely
# (recommended when the target repo is unrelated to this MCP project).
DOCS_ROOT = os.environ.get("RAG_DOCS_DIR", ".")
SKIP_LOCAL_DOCS = os.environ.get("RAG_SKIP_LOCAL_DOCS", "false").lower() in (
    "1",
    "true",
    "yes",
)

# Documentation filename signals — files whose name contains any of these
# keywords (case-insensitive) are treated as priority docs.
DOC_NAME_SIGNALS = {
    "doc",
    "docs",
    "readme",
    "guide",
    "manual",
    "wiki",
    "plan",
    "spec",
    "api",
    "reference",
    "changelog",
    "contributing",
    "tutorial",
    "overview",
    "architecture",
    "design",
    "notes",
}

# File extensions to treat as potential documentation
DOC_TEXT_EXTS = {".html", ".htm", ".md", ".txt", ".rst"}

# Directories to always skip when walking the project tree
SKIP_DIRS = {
    ".venv",
    "venv",
    "__pycache__",
    "node_modules",
    "chroma_store",
    ".git",
    ".mypy_cache",
    ".pytest_cache",
    "dist",
    "build",
    ".eggs",
}

# Extensions to embed as text (from repo)
TEXT_EXTS = {
    ".py",
    ".md",
    ".html",
    ".css",
    ".js",
    ".ts",
    ".json",
    ".toml",
    ".yaml",
    ".yml",
    ".txt",
    ".sh",
    ".sql",
}

# Extensions to index as metadata stubs (binary/image — not embeddable)
BINARY_EXTS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".svg",
    ".webp",
    ".ico",
    ".bmp",
    ".pdf",
    ".zip",
    ".mp4",
    ".mp3",
}

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".ico", ".bmp"}


# ── HTML stripping ─────────────────────────────────────────────────────────────


def _strip_html(html: str) -> str:
    """Strip HTML tags and decode common entities, returning clean plain text."""
    # Remove <script> and <style> blocks entirely
    html = re.sub(
        r"<script[^>]*>.*?</script>", " ", html, flags=re.DOTALL | re.IGNORECASE
    )
    html = re.sub(
        r"<style[^>]*>.*?</style>", " ", html, flags=re.DOTALL | re.IGNORECASE
    )
    # Replace block tags with newlines to preserve paragraph structure
    html = re.sub(
        r"<(?:br|p|div|h[1-6]|li|tr|section|article)[^>]*>",
        "\n",
        html,
        flags=re.IGNORECASE,
    )
    # Strip remaining tags
    html = re.sub(r"<[^>]+>", " ", html)
    # Decode common HTML entities
    html = (
        html.replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", '"')
        .replace("&#39;", "'")
        .replace("&nbsp;", " ")
    )
    # Collapse whitespace
    html = re.sub(r"\n{3,}", "\n\n", html)
    html = re.sub(r"[ \t]+", " ", html)
    return html.strip()


# ── GitHub helpers ─────────────────────────────────────────────────────────────


def _gh_headers() -> dict:
    return {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github+json",
    }


def _get_default_branch() -> str:
    r = httpx.get(
        f"https://api.github.com/repos/{DEFAULT_OWNER}/{DEFAULT_REPO}",
        headers=_gh_headers(),
    )
    if r.status_code == 200:
        branch = r.json().get("default_branch", "main")
        logger.info(f"Default branch: '{branch}'")
        return branch
    logger.warning(f"Could not fetch repo info ({r.status_code}), defaulting to 'main'")
    return "main"


def _get_all_repo_files(branch: str) -> list[dict]:
    """Fetch the full recursive file tree from GitHub API."""
    url = (
        f"https://api.github.com/repos/{DEFAULT_OWNER}/{DEFAULT_REPO}"
        f"/git/trees/{branch}?recursive=1"
    )
    r = httpx.get(url, headers=_gh_headers())
    if r.status_code != 200:
        raise RuntimeError(f"GitHub tree API failed: {r.status_code} {r.text[:200]}")
    return [item for item in r.json().get("tree", []) if item.get("type") == "blob"]


def _fetch_file_content(file_path: str, branch: str) -> str | None:
    """Fetch raw text content of a file from GitHub."""
    url = (
        f"https://raw.githubusercontent.com/{DEFAULT_OWNER}/{DEFAULT_REPO}"
        f"/{branch}/{file_path}"
    )
    r = httpx.get(url, headers=_gh_headers(), timeout=30)
    if r.status_code == 200:
        try:
            return r.text
        except Exception:
            return None
    return None


# ── Helpers ────────────────────────────────────────────────────────────────────


def _ext(path: str) -> str:
    parts = path.rsplit(".", 1)
    return f".{parts[1].lower()}" if len(parts) == 2 else ""


# ── Source 1: GitHub repo ──────────────────────────────────────────────────────


def load_repo_documents(branch: str) -> tuple[list[Document], list[Document]]:
    """
    Returns (text_docs, binary_docs) from the GitHub repo.
    text_docs   — full content, will be split + embedded
    binary_docs — metadata stub only
    """
    files = _get_all_repo_files(branch)
    logger.info(f"Total files in repo: {len(files)}")

    text_docs: list[Document] = []
    binary_docs: list[Document] = []

    for item in files:
        path = item["path"]
        ext = _ext(path)
        filename = path.split("/")[-1]
        folder = "/".join(path.split("/")[:-1]) or "root"
        file_url = (
            f"https://github.com/{DEFAULT_OWNER}/{DEFAULT_REPO}/blob/{branch}/{path}"
        )

        base_meta = {
            "source": f"{DEFAULT_OWNER}/{DEFAULT_REPO}/{path}",
            "file_path": path,
            "filename": filename,
            "folder": folder,
            "extension": ext,
            "file_type": (
                "image"
                if ext in IMAGE_EXTS
                else "binary" if ext in BINARY_EXTS else "text"
            ),
            "doc_type": "repo",
            "url": file_url,
        }

        if ext in BINARY_EXTS:
            binary_docs.append(
                Document(
                    page_content=f"Binary file: {filename} (in /{folder})",
                    metadata=base_meta,
                )
            )
            logger.debug(f"  [binary] {path}")

        elif ext in TEXT_EXTS or ext == "":
            raw = _fetch_file_content(path, branch)
            if not raw or not raw.strip():
                logger.debug(f"  [skip]   {path} (empty or unreadable)")
                continue
            # Strip HTML tags for .html files
            content = _strip_html(raw) if ext == ".html" else raw
            if content.strip():
                text_docs.append(Document(page_content=content, metadata=base_meta))
                logger.debug(f"  [text]   {path}")

    logger.info(f"Repo text files  : {len(text_docs)}")
    logger.info(f"Repo binary files: {len(binary_docs)}")
    return text_docs, binary_docs


# ── Source 2: Local docs files ─────────────────────────────────────────────────


def load_local_docs() -> list[Document]:
    """
    Auto-discover and load ALL documentation files from the project tree.

    Strategy (no hardcoded filenames):
      1. Walk the entire project directory recursively
      2. Pick up every file with a doc-friendly extension (.html .md .txt .rst)
      3. Prioritise files whose name contains a doc keyword (readme, docs, guide…)
         but include ALL matching-extension files — the project may name docs
         anything (e.g. "notes.md", "architecture.html", "api_reference.txt")
      4. Strip HTML tags from .html/.htm files before embedding
      5. Skip build/cache/venv directories entirely

    All docs are tagged with doc_type='local_docs' in metadata so
    ask_codebase knows they are documentation, not source code.
    """
    docs: list[Document] = []
    abs_root = os.path.abspath(DOCS_ROOT)
    logger.info(f"Scanning project tree for docs: '{abs_root}'")

    found: list[tuple[str, bool]] = []  # (abs_path, is_priority)

    for dirpath, dirnames, filenames in os.walk(abs_root):
        # Prune skip dirs in-place so os.walk doesn't descend into them
        dirnames[:] = [
            d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")
        ]

        for fname in filenames:
            ext = _ext(fname)
            if ext not in DOC_TEXT_EXTS:
                continue

            abs_path = os.path.join(dirpath, fname)
            name_lower = fname.lower().replace("-", " ").replace("_", " ")
            is_priority = any(sig in name_lower for sig in DOC_NAME_SIGNALS)
            found.append((abs_path, is_priority))

    if not found:
        logger.warning(
            f"No documentation files (.html .md .txt .rst) found under '{abs_root}'. "
            "The project may have no docs yet — that's fine, continuing."
        )
        return docs

    # Sort: priority docs first, then alphabetical
    found.sort(key=lambda x: (not x[1], x[0]))

    priority_ct = sum(1 for _, p in found if p)
    logger.info(
        f"Found {len(found)} doc file(s) "
        f"({priority_ct} priority, {len(found)-priority_ct} other)"
    )

    for abs_path, is_priority in found:
        fname = os.path.basename(abs_path)
        ext = _ext(fname)
        # Relative path from project root for cleaner metadata
        try:
            rel_path = os.path.relpath(abs_path, abs_root)
        except ValueError:
            rel_path = abs_path
        folder = os.path.dirname(rel_path) or "root"

        try:
            with open(abs_path, "r", encoding="utf-8", errors="ignore") as f:
                raw = f.read()
        except Exception as e:
            logger.warning(f"  Could not read {fname}: {e}")
            continue

        if not raw.strip():
            logger.debug(f"  [skip] {rel_path} (empty)")
            continue

        # Strip HTML for html/htm files
        content = _strip_html(raw) if ext in (".html", ".htm") else raw

        if not content.strip():
            logger.debug(f"  [skip] {rel_path} (empty after stripping)")
            continue

        label = "priority" if is_priority else "doc"
        logger.info(f"  [{label}] {rel_path} ({len(content):,} chars)")

        docs.append(
            Document(
                page_content=content,
                metadata={
                    "source": f"local_docs/{fname}",
                    "file_path": abs_path,
                    "filename": fname,
                    "rel_path": rel_path,
                    "folder": folder,
                    "extension": ext,
                    "file_type": "text",
                    "doc_type": "local_docs",
                    "priority": str(is_priority),
                    "url": "",
                },
            )
        )

    logger.info(f"Local docs loaded: {len(docs)} file(s)")
    return docs


# ── Splitting + embedding ──────────────────────────────────────────────────────


def split_docs(docs: list[Document]) -> list[Document]:
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=500,
        chunk_overlap=50,
        separators=["\n\n", "\n", " ", ""],
    )
    chunks = splitter.split_documents(docs)
    logger.info(f"Split into {len(chunks)} chunks")
    return chunks


def get_embeddings() -> HuggingFaceEmbeddings:
    logger.info(f"Loading embedding model: {EMBED_MODEL}")
    return HuggingFaceEmbeddings(
        model_name=EMBED_MODEL,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )


# ── Stores ─────────────────────────────────────────────────────────────────────


def ingest_chroma(all_docs: list[Document], embeddings: HuggingFaceEmbeddings) -> int:
    logger.info(f"Storing {len(all_docs)} docs in ChromaDB -> '{CHROMA_DIR}' ...")
    vs = Chroma.from_documents(
        documents=all_docs,
        embedding=embeddings,
        persist_directory=CHROMA_DIR,
        collection_name=COLLECTION,
    )
    # Get count from _collection if available (Chroma interface)
    try:
        count = vs._collection.count()
    except (AttributeError, Exception):
        # Fallback: assume all docs were stored
        count = len(all_docs)
    logger.info(f"ChromaDB: {count} docs stored ✅")
    return count


def ingest_pgvector(
    all_docs: list[Document], embeddings: HuggingFaceEmbeddings
) -> None:
    """Store docs in PGVector. Required when POSTGRES_URL is set — not optional."""
    if not POSTGRES_URL:
        logger.info("PGVector skipped — POSTGRES_URL not set in .env")
        return
    try:
        from langchain_postgres import PGVector

        logger.info(f"Storing {len(all_docs)} docs in PGVector ...")

        # langchain-postgres requires psycopg3 driver URL scheme:
        #   postgresql+psycopg://user@host:port/db
        # We auto-convert from the standard postgresql:// format.
        pg_url = POSTGRES_URL
        if pg_url.startswith("postgresql://"):
            pg_url = pg_url.replace("postgresql://", "postgresql+psycopg://", 1)
        elif pg_url.startswith("postgres://"):
            pg_url = pg_url.replace("postgres://", "postgresql+psycopg://", 1)

        logger.info(
            f"PGVector | connecting to {pg_url.split('@')[-1]} ..."
        )  # hide credentials

        PGVector.from_documents(
            documents=all_docs,
            embedding=embeddings,
            connection=pg_url,
            collection_name=COLLECTION,
            use_jsonb=True,
            pre_delete_collection=True,  # wipe old data on re-ingest
        )
        logger.info(f"PGVector: collection '{COLLECTION}' stored ✅")
    except ImportError:
        logger.error(
            "PGVector deps missing. Run: uv add langchain-postgres pgvector psycopg2-binary"
        )
    except Exception as e:
        logger.error(f"PGVector failed: {e}")


# ── Main ───────────────────────────────────────────────────────────────────────


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(
        description="GitHub MCP RAG Ingestion",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Vector DB options (--db):
  chroma    Store in ChromaDB only          (default, no extra setup)
  pgvector  Store in PGVector only          (requires POSTGRES_URL in .env)
  both      Store in both ChromaDB + PGVector

Examples:
  python ingest.py
  python ingest.py --db pgvector
  python ingest.py --db both --reingest
  python ingest.py --docs-only --db chroma
        """,
    )
    parser.add_argument(
        "--db",
        choices=["chroma", "pgvector", "both"],
        default=os.environ.get("RAG_VECTOR_DB", "pgvector"),
        help="Vector DB to use: chroma | pgvector | both  (default: pgvector, or RAG_VECTOR_DB in .env)",
    )
    parser.add_argument(
        "--reingest", action="store_true", help="Wipe existing store(s) first"
    )
    parser.add_argument(
        "--docs-only",
        action="store_true",
        help="Only re-index local docs (skip GitHub)",
    )
    args = parser.parse_args()

    use_chroma = args.db in ("chroma", "both")
    use_pgvector = args.db in ("pgvector", "both")

    logger.info("=" * 60)
    logger.info("GitHub MCP RAG Ingestion")
    logger.info(f"Repo    : {DEFAULT_OWNER}/{DEFAULT_REPO}")
    logger.info(f"Docs dir: {os.path.abspath(DOCS_ROOT)}")
    logger.info(f"Vector DB: {args.db.upper()}")
    if use_chroma:
        logger.info(f"  ChromaDB  -> {CHROMA_DIR}")
    if use_pgvector:
        logger.info(f"  PGVector  -> {POSTGRES_URL or '(POSTGRES_URL not set!)'}")
    logger.info("=" * 60)

    if not GITHUB_TOKEN:
        logger.error("GITHUB_TOKEN missing from .env")
        sys.exit(1)

    if use_pgvector and not POSTGRES_URL:
        logger.error(
            "POSTGRES_URL is not set in .env but --db pgvector/both was requested.\n"
            "  Add: POSTGRES_URL=postgresql://postgres@localhost:5432/ai_db"
        )
        sys.exit(1)

    if args.reingest and use_chroma and os.path.exists(CHROMA_DIR):
        logger.info(f"Wiping ChromaDB store at '{CHROMA_DIR}' ...")
        shutil.rmtree(CHROMA_DIR)

    all_text_docs: list[Document] = []
    all_binary_docs: list[Document] = []

    # ── Source 1: GitHub repo ──────────────────────────────────────────────
    if not args.docs_only:
        logger.info("── [1/2] Loading GitHub repo files ──")
        branch = _get_default_branch()
        repo_text, repo_binary = load_repo_documents(branch)
        all_text_docs.extend(repo_text)
        all_binary_docs.extend(repo_binary)
    else:
        logger.info("── [1/2] GitHub repo skipped (--docs-only) ──")

    # ── Source 2: Local docs ───────────────────────────────────────────────
    if SKIP_LOCAL_DOCS:
        logger.info("── [2/2] Local docs skipped (RAG_SKIP_LOCAL_DOCS=true) ──")
        local_docs = []
    else:
        logger.info("── [2/2] Loading local docs ──")
        local_docs = load_local_docs()
        all_text_docs.extend(local_docs)

    if not all_text_docs and not all_binary_docs:
        logger.error("No documents found from any source.")
        sys.exit(1)

    # ── Split + embed + store ──────────────────────────────────────────────
    logger.info("── Splitting text documents ──")
    text_chunks = split_docs(all_text_docs)

    all_docs = text_chunks + all_binary_docs
    logger.info(
        f"Total to store: {len(all_docs)} "
        f"({len(text_chunks)} text chunks + {len(all_binary_docs)} binary stubs)"
    )

    logger.info("── Loading embeddings ──")
    embeddings = get_embeddings()

    if use_chroma:
        ingest_chroma(all_docs, embeddings)
    if use_pgvector:
        ingest_pgvector(all_docs, embeddings)

    # ── Summary ────────────────────────────────────────────────────────────
    image_files = [
        d.metadata["filename"]
        for d in all_binary_docs
        if d.metadata.get("file_type") == "image"
    ]
    local_names = [d.metadata["filename"] for d in local_docs]
    repo_text_ct = len(
        [d for d in all_text_docs if d.metadata.get("doc_type") == "repo"]
    )

    logger.info("=" * 60)
    logger.info(f"Repo text files  : {repo_text_ct}")
    logger.info(f"Repo binary stubs: {len(all_binary_docs)}")
    logger.info(f"Local docs       : {len(local_docs)} — {local_names}")
    logger.info(f"Text chunks      : {len(text_chunks)}")
    if image_files:
        logger.info(f"Images ({len(image_files)})  : {image_files}")
    logger.info("=" * 60)
    logger.info(
        f"Indexed {len(text_chunks)} chunks from "
        f"{repo_text_ct} repo files + {len(local_docs)} local docs."
    )
    logger.info("=" * 60)


if __name__ == "__main__":
    main()
