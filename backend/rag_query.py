"""Standalone RAG Chain Tester.

Tests the LCEL RAG pipeline against the persisted vector store (PGVector or
ChromaDB) outside of the MCP server.  Useful for verifying that ingestion
succeeded and that the Groq API key is working before starting the server.

The target repository is read from GITHUB_OWNER / GITHUB_REPO in .env so
the LLM is grounded to the correct codebase.

Usage:
    python rag_query.py                      # run 3 built-in test questions
    python rag_query.py "your question"      # ask a custom question

Required .env keys:
    GROQ_API_KEY  — free at console.groq.com
    RAG_VECTOR_DB — chroma | pgvector | both  (default: pgvector)
    POSTGRES_URL  — required when RAG_VECTOR_DB=pgvector or both

Run ingest.py first to populate the vector store.
"""

import os
import sys
from dotenv import load_dotenv
from loguru import logger

load_dotenv()

from langchain_chroma import Chroma
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough, RunnableLambda

# ── Config ─────────────────────────────────────────────────────────────────────
CHROMA_DIR = os.environ.get("RAG_CHROMA_DIR", "./chroma_store")
POSTGRES_URL = os.environ.get("POSTGRES_URL", "")
EMBED_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
LLM_MODEL = "openai/gpt-oss-120b"
RETRIEVER_K = 5
# RAG_VECTOR_DB: chroma | pgvector | both  (default: pgvector)
VECTOR_DB = os.environ.get("RAG_VECTOR_DB", "pgvector").lower()

TEST_QUESTIONS = [
    "How do I add a new MCP tool?",
    "What environment variables are required?",
    "How does GitHub API authentication work?",
]

_GITHUB_OWNER = os.environ.get("GITHUB_OWNER", "")
_GITHUB_REPO = os.environ.get("GITHUB_REPO", "")
_TARGET_REPO = (
    f"{_GITHUB_OWNER}/{_GITHUB_REPO}"
    if _GITHUB_OWNER and _GITHUB_REPO
    else "the indexed repository"
)

RAG_PROMPT = ChatPromptTemplate.from_template(
    f"""You are a helpful code assistant answering questions about the **{_TARGET_REPO}** GitHub repository.

Answer the question using ONLY the context provided below. Do not use any outside knowledge.
For every fact you state, cite the source filename in brackets like [filename.py] or [README.md].
If the context does not contain enough information to answer, say "Not enough context to answer."

Context:
{{context}}

Question: {{question}}

Answer (with cited filenames):"""
)


def _format_docs(docs: list) -> str:
    parts = []
    for doc in docs:
        source = doc.metadata.get("source", doc.metadata.get("path", "unknown"))
        filename = source.split("/")[-1] if "/" in source else source
        parts.append(f"[{filename}]\n{doc.page_content}")
    return "\n\n---\n\n".join(parts)


def _load_retriever(embeddings):
    """Load retriever based on RAG_VECTOR_DB setting."""
    ret_kwargs = {"search_type": "similarity", "search_kwargs": {"k": RETRIEVER_K}}

    if VECTOR_DB == "pgvector":
        if not POSTGRES_URL:
            logger.error("RAG_VECTOR_DB=pgvector but POSTGRES_URL not set in .env")
            sys.exit(1)
        from langchain_postgres import PGVector

        pg_url = POSTGRES_URL.replace("postgresql://", "postgresql+psycopg://", 1)
        vs = PGVector(
            embeddings=embeddings, connection=pg_url, collection_name="github_mcp_docs"
        )
        logger.info("Retriever: PGVector ✅")
        return vs.as_retriever(**ret_kwargs)

    if VECTOR_DB == "both":
        chroma_vs = Chroma(
            persist_directory=CHROMA_DIR,
            embedding_function=embeddings,
            collection_name="github_mcp_docs",
        )
        chroma_ret = chroma_vs.as_retriever(**ret_kwargs)
        if POSTGRES_URL:
            from langchain_postgres import PGVector

            try:
                from langchain.retrievers import MergerRetriever
            except ImportError:
                from langchain_community.retrievers import MergerRetriever
            pg_url = POSTGRES_URL.replace("postgresql://", "postgresql+psycopg://", 1)
            pg_vs = PGVector(
                embeddings=embeddings,
                connection=pg_url,
                collection_name="github_mcp_docs",
            )
            pg_ret = pg_vs.as_retriever(**ret_kwargs)
            logger.info("Retriever: MergerRetriever (ChromaDB + PGVector) ✅")
            return MergerRetriever(retrievers=[chroma_ret, pg_ret])
        logger.warning(
            "RAG_VECTOR_DB=both but POSTGRES_URL not set — using ChromaDB only"
        )
        return chroma_ret

    # Default: chroma
    if not os.path.exists(CHROMA_DIR):
        logger.error(
            f"ChromaDB store not found at '{CHROMA_DIR}'. Run ingest.py first."
        )
        sys.exit(1)
    vs = Chroma(
        persist_directory=CHROMA_DIR,
        embedding_function=embeddings,
        collection_name="github_mcp_docs",
    )
    logger.info("Retriever: ChromaDB ✅")
    return vs.as_retriever(**ret_kwargs)


def build_chain():
    """Build the LCEL RAG chain: retriever | format_docs | prompt | llm | parser."""
    logger.info(f"Vector DB: {VECTOR_DB.upper()}")
    logger.info("Loading embeddings ...")
    embeddings = HuggingFaceEmbeddings(
        model_name=EMBED_MODEL,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )
    retriever = _load_retriever(embeddings)
    logger.info(f"Loading LLM: {LLM_MODEL} via Groq ...")
    llm = ChatGroq(model=LLM_MODEL, temperature=0)
    chain = (
        {
            "context": retriever | RunnableLambda(_format_docs),
            "question": RunnablePassthrough(),
        }
        | RAG_PROMPT
        | llm
        | StrOutputParser()
    )
    logger.info("Chain ready ✅")
    return chain


def run_question(chain, question: str) -> str:
    print(f"\n{'─' * 60}")
    print(f"Q: {question}")
    print("─" * 60)
    answer = chain.invoke(question)
    print(f"A: {answer}")
    return answer


def main() -> None:
    if not os.environ.get("GROQ_API_KEY"):
        logger.error("GROQ_API_KEY not set in .env")
        sys.exit(1)

    logger.info("=" * 60)
    logger.info("GitHub MCP RAG Query")
    logger.info("=" * 60)

    chain = build_chain()

    questions = [" ".join(sys.argv[1:])] if len(sys.argv) > 1 else TEST_QUESTIONS
    for q in questions:
        run_question(chain, q)

    print(f"\n{'=' * 60}")


if __name__ == "__main__":
    main()
