"""RAG tools for GitHub MCP Server.

Provides two MCP tools that answer questions about whichever GitHub repository
was indexed by ``ingest.py``.  The target repo is determined by ``GITHUB_OWNER``
and ``GITHUB_REPO`` in the project's ``.env`` file.

Tools:
    ask_codebase:
        Natural-language Q&A over the indexed repository using a RAG pipeline.
        Retrieves the top-k most relevant chunks from the vector store, feeds
        them to Groq (``openai/gpt-oss-120b``) with a grounded prompt, and
        returns an answer with ``[filename]`` citations.

    explore_codebase:
        File-level explorer.  Answers structural questions such as "how many
        Python files are there?", "list all images", or "show me README.md".
        Builds a full file index from the vector store instead of doing a
        similarity search, so it can count / list every indexed file.

Vector store selection (``RAG_VECTOR_DB`` in ``.env``):
    pgvector  — PGVector only (default, requires ``POSTGRES_URL``)
    chroma    — ChromaDB only (requires ``ingest.py --db chroma``)
    both      — Combined search (ChromaDB + PGVector, deduplicated results)

Run ``ingest.py`` first to populate the chosen vector store.
"""

import os
import re
from functools import lru_cache
from collections import defaultdict
from loguru import logger

# ── RAG config ────────────────────────────────────────────────────────────────
CHROMA_DIR = os.environ.get("RAG_CHROMA_DIR", "./chroma_store")
POSTGRES_URL = os.environ.get("POSTGRES_URL", "")
# RAG_VECTOR_DB controls which store the tools query at runtime:
#   chroma    → ChromaDB only
#   pgvector  → PGVector only         (default)
#   both      → MergerRetriever (ChromaDB + PGVector, deduplicated results)
VECTOR_DB = os.environ.get("RAG_VECTOR_DB", "pgvector").lower()
EMBED_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
LLM_MODEL = "openai/gpt-oss-120b"
RETRIEVER_K = 5
COLLECTION = "github_mcp_docs"

# Log vector DB configuration at module load time
logger.info(
    f"RAG | Configuration loaded: RAG_VECTOR_DB={VECTOR_DB}, POSTGRES_URL={'set' if POSTGRES_URL else 'not set'}, CHROMA_DIR={CHROMA_DIR}"
)

# Target repo (from .env) — used to ground the RAG prompt correctly
_GITHUB_OWNER = os.environ.get("GITHUB_OWNER", "")
_GITHUB_REPO = os.environ.get("GITHUB_REPO", "")
_TARGET_REPO = (
    f"{_GITHUB_OWNER}/{_GITHUB_REPO}"
    if _GITHUB_OWNER and _GITHUB_REPO
    else "the indexed repository"
)

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".ico", ".bmp"}

_RAG_PROMPT = f"""You are a helpful code assistant answering questions about the **{_TARGET_REPO}** GitHub repository.

Answer the question using ONLY the context provided below. Do not use any outside knowledge.
For every fact you state, cite the source filename in brackets like [filename.py] or [README.md].
If the context does not contain enough information to answer, say "Not enough context to answer."

Context:
{{context}}

Question: {{question}}

Answer (with cited filenames):"""

_EXPLORE_PROMPT = """You are a helpful code assistant exploring a GitHub repository for the user.

Use ONLY the information below to answer. Be direct and factual.
- For file listings: show them as a clean numbered or bulleted list
- For file contents: wrap in proper markdown code blocks with the language tag
- For counts: give the exact number
- For image files: list their full path and folder location

Repository data:
{context}

User query: {question}

Answer:"""


# ── Shared helpers ────────────────────────────────────────────────────────────


def _ext(filename: str) -> str:
    parts = filename.rsplit(".", 1)
    return f".{parts[1].lower()}" if len(parts) == 2 else ""


def _lang_tag(filename: str) -> str:
    return {
        ".py": "python",
        ".md": "markdown",
        ".js": "javascript",
        ".ts": "typescript",
        ".json": "json",
        ".yaml": "yaml",
        ".yml": "yaml",
        ".toml": "toml",
        ".sh": "bash",
        ".txt": "text",
        ".html": "html",
        ".css": "css",
        ".sql": "sql",
    }.get(_ext(filename), "text")


def _format_docs(docs: list) -> str:
    parts = []
    for doc in docs:
        source = doc.metadata.get("source", doc.metadata.get("path", "unknown"))
        filename = source.split("/")[-1] if "/" in source else source
        parts.append(f"[{filename}]\n{doc.page_content}")
    return "\n\n---\n\n".join(parts)


@lru_cache(maxsize=1)
def _get_embeddings():
    """Load and cache HuggingFace embeddings (shared by all stores)."""
    from langchain_huggingface import HuggingFaceEmbeddings

    logger.info(f"RAG | loading embeddings: {EMBED_MODEL}")
    return HuggingFaceEmbeddings(
        model_name=EMBED_MODEL,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )


@lru_cache(maxsize=1)
def _get_chroma():
    """Load and cache ChromaDB vectorstore."""
    from langchain_chroma import Chroma

    if not os.path.exists(CHROMA_DIR):
        raise RuntimeError(
            f"ChromaDB store not found at '{CHROMA_DIR}'. "
            "Run ingest.py first to index the codebase."
        )
    logger.info(f"RAG | loading ChromaDB from '{CHROMA_DIR}'")
    vs = Chroma(
        persist_directory=CHROMA_DIR,
        embedding_function=_get_embeddings(),
        collection_name=COLLECTION,
    )
    logger.info("RAG | ChromaDB ready ✅")
    return vs


@lru_cache(maxsize=1)
def _get_pgvector():
    """Load PGVector store. Returns None if POSTGRES_URL not set or unavailable."""
    if not POSTGRES_URL:
        return None
    try:
        from langchain_postgres import PGVector

        logger.info("RAG | loading PGVector ...")
        pg_url = POSTGRES_URL
        if pg_url.startswith("postgresql://"):
            pg_url = pg_url.replace("postgresql://", "postgresql+psycopg://", 1)
        vs = PGVector(
            embeddings=_get_embeddings(),
            connection=pg_url,
            collection_name=COLLECTION,
            use_jsonb=True,
        )
        logger.info("RAG | PGVector ready ✅")
        return vs
    except Exception as e:
        logger.warning(f"RAG | PGVector unavailable ({e}), ChromaDB only")
        return None


def _get_vectorstore():
    """Return the primary vectorstore based on RAG_VECTOR_DB setting."""
    logger.info(f"RAG | Vector DB config: RAG_VECTOR_DB={VECTOR_DB}")

    if VECTOR_DB == "pgvector":
        logger.info("RAG | Attempting to load PGVector...")
        pg = _get_pgvector()
        if pg is None:
            logger.error("RAG | PGVector failed to initialize")
            raise RuntimeError(
                "RAG_VECTOR_DB=pgvector but PGVector is unavailable. "
                "Check POSTGRES_URL and that the Docker container is running."
            )
        logger.info(
            f"RAG | Using PGVector store (connected to {POSTGRES_URL.split('@')[-1]})"
        )
        return pg

    logger.info("RAG | Attempting to load ChromaDB...")
    chroma = _get_chroma()
    logger.info(f"RAG | Using ChromaDB store from '{CHROMA_DIR}'")
    return chroma


def _combined_search(query: str, k: int) -> list:
    """
    Query both ChromaDB and PGVector, merge results, deduplicate by content.
    No MergerRetriever dependency — works with any LangChain version.
    """
    seen, results = set(), []
    for label, vs in [("ChromaDB", _get_chroma()), ("PGVector", _get_pgvector())]:
        if vs is None:
            continue
        try:
            docs = vs.similarity_search(query, k=k)
            for doc in docs:
                key = doc.page_content[:120]
                if key not in seen:
                    seen.add(key)
                    results.append(doc)
            logger.debug(f"RAG | {label} returned {len(docs)} docs")
        except Exception as e:
            logger.warning(f"RAG | {label} search failed: {e}")
    return results[: k * 2]


def _get_retriever():
    """Return retriever based on RAG_VECTOR_DB env var.

    Logs which vector database is being used:
      RAG_VECTOR_DB=chroma    → ChromaDB only
      RAG_VECTOR_DB=pgvector  → PGVector only         (default)
      RAG_VECTOR_DB=both      → combined search (ChromaDB + PGVector, deduplicated)

    Switch at any time by changing RAG_VECTOR_DB in .env and restarting the server.
    """
    logger.info(f"RAG | Initializing retriever with RAG_VECTOR_DB={VECTOR_DB}")
    ret_kwargs = {"search_type": "similarity", "search_kwargs": {"k": RETRIEVER_K}}

    if VECTOR_DB == "pgvector":
        logger.info("RAG | Initializing PGVector retriever...")
        pg_vs = _get_pgvector()
        if pg_vs is None:
            logger.error("RAG | PGVector initialization failed")
            raise RuntimeError(
                "RAG_VECTOR_DB=pgvector but PGVector is unavailable. "
                "Check POSTGRES_URL and that Docker container is running."
            )
        # Use a sync-wrapper retriever instead of pg_vs.as_retriever().
        # VectorStoreRetriever calls PGVector.asimilarity_search() in async
        # context which requires an async engine (_async_engine) that is never
        # set up when using a sync connection string.  BaseRetriever's default
        # _aget_relevant_documents runs _get_relevant_documents in a thread
        # executor — safe and requires no extra dependencies.
        from langchain_core.retrievers import BaseRetriever
        from langchain_core.documents import Document
        from langchain_core.callbacks import CallbackManagerForRetrieverRun
        from pydantic import Field
        from typing import Any

        class _PGVectorSyncRetriever(BaseRetriever):
            vs: Any = Field()
            k: int = Field(default=RETRIEVER_K)

            class Config:
                arbitrary_types_allowed = True

            def _get_relevant_documents(
                self, query: str, *, run_manager: CallbackManagerForRetrieverRun
            ) -> list[Document]:
                return self.vs.similarity_search(query, k=self.k)

        logger.info("RAG | ✅ ACTIVE DB: PGVector")
        return _PGVectorSyncRetriever(vs=pg_vs, k=RETRIEVER_K)

    if VECTOR_DB == "both":
        logger.info("RAG | Initializing combined retriever (ChromaDB + PGVector)...")
        pg_vs = _get_pgvector()
        if pg_vs is not None:
            from langchain_core.retrievers import BaseRetriever
            from langchain_core.documents import Document
            from langchain_core.callbacks import CallbackManagerForRetrieverRun
            from pydantic import Field

            class _CombinedRetriever(BaseRetriever):
                k: int = Field(default=RETRIEVER_K)

                def _get_relevant_documents(
                    self, query: str, *, run_manager: CallbackManagerForRetrieverRun
                ) -> list[Document]:
                    return _combined_search(query, self.k)

            logger.info("RAG | ✅ ACTIVE DB: Combined (ChromaDB + PGVector)")
            return _CombinedRetriever(k=RETRIEVER_K)
        else:
            logger.warning(
                "RAG | PGVector unavailable in 'both' mode, falling back to ChromaDB only"
            )
            logger.info("RAG | ✅ ACTIVE DB: ChromaDB (fallback)")
            return _get_chroma().as_retriever(**ret_kwargs)

    # Default: chroma
    logger.info("RAG | ✅ ACTIVE DB: ChromaDB")
    return _get_chroma().as_retriever(**ret_kwargs)


@lru_cache(maxsize=1)
def _build_ask_chain():
    """Build and cache the ask_codebase LCEL chain."""
    from langchain_groq import ChatGroq
    from langchain_core.prompts import ChatPromptTemplate
    from langchain_core.output_parsers import StrOutputParser
    from langchain_core.runnables import RunnablePassthrough, RunnableLambda

    retriever = _get_retriever()
    llm = ChatGroq(model=LLM_MODEL, temperature=0)
    prompt = ChatPromptTemplate.from_template(_RAG_PROMPT)

    chain = (
        {
            "context": retriever | RunnableLambda(_format_docs),
            "question": RunnablePassthrough(),
        }
        | prompt
        | llm
        | StrOutputParser()
    )
    logger.info("RAG | ask_codebase chain ready ✅")
    return chain


def _get_all_docs() -> list:
    """Fetch ALL documents from the vector store (Chroma or PGVector)."""
    vs = _get_vectorstore()

    class _Doc:
        def __init__(self, page_content, metadata):
            self.page_content = page_content
            self.metadata = metadata

    # Handle Chroma: use _collection.get()
    if hasattr(vs, "_collection") and hasattr(vs._collection, "get"):
        result = vs._collection.get(include=["documents", "metadatas"])
        return [
            _Doc(c, m or {}) for c, m in zip(result["documents"], result["metadatas"])
        ]

    # Handle PGVector: query with a very large k to get all docs
    # (this is a workaround since PGVector doesn't have a public get_all() method)
    logger.info("RAG | Fetching all docs from PGVector (this may take a moment)...")
    try:
        # Try multiple search strategies to maximize retrieval
        all_docs = []
        seen_content = set()

        # Use multiple queries to try to retrieve all documents
        search_queries = ["", " ", ".", "a", "def ", "import ", "class ", "return "]
        for query in search_queries:
            try:
                # Request a large number of results (PGVector should return what's available)
                docs = vs.similarity_search(query, k=10000)
                for doc in docs:
                    content_key = doc.page_content[:100]
                    if content_key not in seen_content:
                        seen_content.add(content_key)
                        all_docs.append(_Doc(doc.page_content, doc.metadata or {}))
            except Exception:
                continue

            # If we got some docs, stop searching
            if all_docs:
                logger.info(f"RAG | Retrieved {len(all_docs)} documents from PGVector")
                break

        if not all_docs:
            logger.warning("RAG | No documents found in vector store")
        return all_docs
    except Exception as e:
        logger.error(f"RAG | Failed to fetch all docs: {e}")
        return []


def _build_file_index() -> dict:
    """
    Build a rich file index from all ChromaDB docs.

    Returns dict keyed by full source path:
    {
      "owner/repo/images/logo.png": {
        "filename":  "logo.png",
        "folder":    "images",
        "extension": ".png",
        "file_type": "image",          # "image" | "binary" | "text"
        "url":       "https://...",
        "chunks":    ["Binary file: logo.png (in /images)"]
      }, ...
    }
    """
    index = {}
    for doc in _get_all_docs():
        meta = doc.metadata
        source = meta.get("source", meta.get("path", "unknown"))

        if source not in index:
            # Use rich metadata from new ingest.py if available,
            # else fall back to parsing the source path
            filename = meta.get("filename") or (
                source.split("/")[-1] if "/" in source else source
            )
            folder = meta.get("folder") or ("/".join(source.split("/")[:-1]) or "root")
            extension = meta.get("extension") or _ext(filename)
            file_type = meta.get("file_type") or (
                "image" if extension in IMAGE_EXTS else "text"
            )
            index[source] = {
                "filename": filename,
                "folder": folder,
                "extension": extension,
                "file_type": file_type,
                "url": meta.get("url", ""),
                "chunks": [],
            }
        index[source]["chunks"].append(doc.page_content)

    return index


# ── Tool registrations ────────────────────────────────────────────────────────


def register_ask_codebase_tool(mcp) -> None:
    """Register the ask_codebase tool with the FastMCP server."""

    @mcp.tool()
    async def ask_codebase(question: str) -> dict:
        """Ask a natural-language question about the indexed GitHub repository.

        Uses a RAG pipeline (PGVector/ChromaDB + Groq openai/gpt-oss-120b) to
        retrieve relevant code chunks and return a grounded answer with source
        file citations.  The target repository is set by GITHUB_OWNER and
        GITHUB_REPO in .env.

        Run ingest.py first to index the repository into the vector store.

        Args:
            question: Any question about the repository, e.g.:
                      "Tell me about this project."
                      "What does the authentication module do?"
                      "How is the database schema structured?"

        Returns:
            answer:   Grounded answer with [filename] citations.
            question: The original question echoed back.
            model:    LLM model used.
            sources:  Deduplicated list of retrieved source filenames.
        """
        logger.info(f"ask_codebase | Using {VECTOR_DB.upper()} vector DB 🔍")
        logger.info(f"ask_codebase | question={question!r}")

        if not question or not question.strip():
            raise ValueError("question must not be empty.")

        chain = _build_ask_chain()
        answer = await chain.ainvoke(question)
        docs = _get_retriever().invoke(question)
        sources = list(
            dict.fromkeys(
                d.metadata.get("filename")
                or d.metadata.get("source", "unknown").split("/")[-1]
                for d in docs
            )
        )

        logger.info(f"ask_codebase | done sources={sources}")
        return {
            "answer": answer,
            "question": question,
            "model": LLM_MODEL,
            "sources": sources,
        }


def register_explore_codebase_tool(mcp) -> None:
    """Register the explore_codebase tool with the FastMCP server."""

    @mcp.tool()
    async def explore_codebase(query: str) -> dict:
        """Explore the repository — find files, list images, read file contents.

        Unlike ask_codebase (which answers logic/behaviour questions),
        this tool answers structural and file-level queries:

        Examples:
          "Are there any image files? How many and list them"
          "How many Python files are there?"
          "Show me the contents of index.html"
          "What files are in the images folder?"
          "List all files in the build folder"
          "Find all .svg files"
          "What file types exist in this repo?"
          "Show me README.md"

        NOTE: Run ingest.py with the updated version first so image/binary
        files are indexed alongside text files.

        Args:
            query: A structural or file-level question about the repo.

        Returns:
            answer:        LLM answer with file listings or code blocks.
            matched_files: Files directly matched by this query.
            file_summary:  { extension: count } for the whole repo.
            total_files:   Total unique files indexed.
            images:        All image files found (name + folder + url).
            query:         The original query echoed back.
        """
        logger.info(f"explore_codebase | Using {VECTOR_DB.upper()} vector DB 🔍")
        logger.info(f"explore_codebase | query={query!r}")

        if not query or not query.strip():
            raise ValueError("query must not be empty.")

        # ── 1. Build file index from ALL chromadb docs ─────────────────────
        file_index = _build_file_index()
        total_files = len(file_index)

        # Extension summary
        ext_counter: dict[str, int] = defaultdict(int)
        for info in file_index.values():
            ext_counter[info["extension"] or "(no ext)"] += 1
        file_summary = dict(sorted(ext_counter.items()))

        # All image files
        all_images = [
            {
                "filename": info["filename"],
                "folder": info["folder"],
                "url": info["url"],
            }
            for info in file_index.values()
            if info["file_type"] == "image"
        ]

        # ── 2. Match files to the query ────────────────────────────────────
        q_lower = query.lower()

        is_image_query = any(
            w in q_lower
            for w in [
                "image",
                "images",
                "photo",
                "picture",
                "img",
                "png",
                "jpg",
                "jpeg",
                "gif",
                "svg",
                "icon",
            ]
        )
        is_count_query = any(
            w in q_lower for w in ["how many", "count", "number of", "total"]
        )
        is_content_query = any(
            w in q_lower
            for w in [
                "show",
                "content",
                "display",
                "read",
                "open",
                "view",
                "what is in",
                "what's in",
            ]
        )
        is_folder_query = any(
            w in q_lower for w in ["folder", "directory", "dir", "in the"]
        )

        # Detect explicit extension e.g. ".py" or "python files"
        ext_match = re.search(
            r"\.(py|md|js|ts|json|yaml|yml|toml|sh|txt|html|css|sql|png|jpg|jpeg|gif|svg|webp|ico)\b",
            q_lower,
        )
        asked_ext = f".{ext_match.group(1)}" if ext_match else None

        # Detect explicit filename e.g. "server.py", "index.html"
        file_match = re.search(r"\b([\w\-]+\.\w+)\b", query)
        asked_file = file_match.group(1).lower() if file_match else None

        # Detect folder name from query
        folder_match = re.search(
            r"\b(images|build|original_page|\.github|workflows|src|assets|static|public)\b",
            q_lower,
        )
        asked_folder = folder_match.group(1) if folder_match else None

        # ── Match ──────────────────────────────────────────────────────────
        matched: list[dict] = []

        if is_image_query:
            matched = (
                list(file_index.values())
                if not all_images
                else [
                    file_index[s]
                    for s in file_index
                    if file_index[s]["file_type"] == "image"
                ]
            )

        elif asked_file:
            matched = [
                info
                for info in file_index.values()
                if asked_file in info["filename"].lower()
            ]

        elif asked_folder:
            matched = [
                info
                for info in file_index.values()
                if asked_folder.lower() in info["folder"].lower()
            ]

        elif asked_ext:
            matched = [
                info for info in file_index.values() if info["extension"] == asked_ext
            ]

        else:
            # Keyword match on filenames
            keywords = [
                w
                for w in re.findall(r"\b\w{3,}\b", q_lower)
                if w
                not in {
                    "how",
                    "many",
                    "the",
                    "are",
                    "all",
                    "any",
                    "list",
                    "show",
                    "file",
                    "files",
                    "what",
                    "there",
                    "this",
                    "repo",
                    "give",
                    "and",
                    "tell",
                    "me",
                    "them",
                    "they",
                    "their",
                }
            ]
            if keywords:
                matched = [
                    info
                    for info in file_index.values()
                    if any(
                        kw in info["filename"].lower() or kw in info["folder"].lower()
                        for kw in keywords
                    )
                ]
            if not matched:
                matched = list(file_index.values())

        matched_filenames = list(dict.fromkeys(info["filename"] for info in matched))

        # ── 3. Build context for LLM ───────────────────────────────────────
        context_parts = []

        # File inventory — summary only (ext: count), no per-file listing to save tokens
        inventory_lines = [
            f"  {ext or '(no ext)'}: {count} file(s)"
            for ext, count in sorted(file_summary.items())
        ]
        context_parts.append(
            f"REPOSITORY INVENTORY ({total_files} unique files total):\n"
            + "\n".join(inventory_lines)
        )

        # Image list — capped at 30 to avoid blowing context
        if all_images:
            img_lines = [
                f"  {img['filename']}  (folder: {img['folder']})"
                for img in all_images[:30]
            ]
            if len(all_images) > 30:
                img_lines.append(f"  ... and {len(all_images) - 30} more")
            context_parts.append(
                f"IMAGE FILES ({len(all_images)} total):\n" + "\n".join(img_lines)
            )

        # ── Token budget: keep context under ~4000 words (~5500 tokens) ──────
        # Groq limit is 8k TPM; prompt overhead ~500 tokens; leave 2k for answer
        MAX_CONTEXT_CHARS = 12_000  # ~3000 tokens worth of context chars
        MAX_FILES = 4  # max files to show content for
        MAX_CHUNK_CHARS = 1_500  # max chars per file (truncated if longer)

        # Matched file details — binary stubs first (tiny), then text files
        text_matched = [i for i in matched if i["file_type"] == "text"]
        binary_matched = [i for i in matched if i["file_type"] != "text"]

        for info in binary_matched[:10]:
            fname = info["filename"]
            context_parts.append(
                f"FILE: {fname}  [folder: {info['folder']}]  [type: {info['file_type']}]\n"
                f"  URL: {info['url']}"
            )

        chars_used = sum(len(p) for p in context_parts)
        files_shown = 0
        for info in text_matched[:MAX_FILES]:
            fname = info["filename"]
            lang = _lang_tag(fname)
            combined = "\n\n".join(info["chunks"])
            # Truncate if too long
            if len(combined) > MAX_CHUNK_CHARS:
                combined = combined[:MAX_CHUNK_CHARS] + "\n... [truncated for brevity]"
            snippet = (
                f"FILE: {fname}  [folder: {info['folder']}]\n```{lang}\n{combined}\n```"
            )
            if chars_used + len(snippet) > MAX_CONTEXT_CHARS:
                context_parts.append(
                    f"FILE: {fname} — content omitted (context limit). "
                    f"Ask specifically about this file to see its contents."
                )
                break
            context_parts.append(snippet)
            chars_used += len(snippet)
            files_shown += 1

        context = "\n\n" + ("─" * 60 + "\n\n").join(context_parts)
        logger.debug(
            f"explore_codebase | context chars={len(context)} files_shown={files_shown}"
        )

        # ── 4. LLM answer ──────────────────────────────────────────────────
        from langchain_groq import ChatGroq
        from langchain_core.prompts import ChatPromptTemplate
        from langchain_core.output_parsers import StrOutputParser

        llm = ChatGroq(model=LLM_MODEL, temperature=0)
        prompt = ChatPromptTemplate.from_template(_EXPLORE_PROMPT)
        chain = prompt | llm | StrOutputParser()

        answer = await chain.ainvoke({"context": context, "question": query})

        logger.info(
            f"explore_codebase | matched={matched_filenames} images={len(all_images)}"
        )
        return {
            "answer": answer,
            "matched_files": matched_filenames,
            "file_summary": file_summary,
            "total_files": total_files,
            "images": all_images,
            "query": query,
        }


def register_rag_tools(mcp) -> None:
    """Register both RAG tools: ask_codebase and explore_codebase."""
    register_ask_codebase_tool(mcp)
    register_explore_codebase_tool(mcp)
