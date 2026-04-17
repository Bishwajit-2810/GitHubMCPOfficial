"""GitHub MCP Server — Main Entry Point.

A modular GitHub API MCP server built on FastMCP.  Registers 12 tools that
cover repository management, GitHub Projects v2 board operations, and
AI-powered RAG Q&A over an indexed GitHub repository.

Environment variables (loaded from .env via config.py):
    GITHUB_TOKEN  — Personal Access Token with repo + project scopes.
    GITHUB_OWNER  — Default repository owner / org.
    GITHUB_REPO   — Default repository name.
    PROJECT_ID    — Default Projects v2 board number.

Tools registered:
    1.  list_files          — browse repo directory contents
    2.  create_branch       — create a branch from a source ref
    3.  create_file         — create or update a file with a commit
    4.  create_pull_request — open a PR (supports draft)
    5.  create_project_task — create issue/draft on Projects v2 board
    6.  list_project_tasks  — list board items with offset pagination
    7.  assign_task         — assign users + labels to an issue
    8.  update_task_status  — change Status column on the board
    9.  create_project_field— add text/number/date field to a project
    10. set_task_fields     — set custom field values on a board item
    11. ask_codebase        — RAG Q&A over the indexed repo (Groq + PGVector/ChromaDB)
    12. explore_codebase    — file-level explorer backed by the vector store

Usage:
    python server.py [--port PORT] [--host HOST]
    python server.py --port 8090          # default
"""

from loguru import logger
from fastmcp import FastMCP

from github_mcp.config import (
    GITHUB_TOKEN,
    DEFAULT_OWNER,
    DEFAULT_REPO,
    DEFAULT_PROJECT,
    validate_config,
)
from github_mcp.tools import register_all_tools

# Initialize FastMCP server
mcp = FastMCP("github-mcp")

# Register all tools (1-10 GitHub tools + 11 ask_codebase RAG tool)
register_all_tools(mcp)


# ============================================================
# Entry point
# ============================================================
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="GitHub FastMCP server")
    parser.add_argument(
        "--port", type=int, default=8090, help="SSE port (default 8090)"
    )
    parser.add_argument("--host", default="0.0.0.0", help="Bind host (default 0.0.0.0)")
    args = parser.parse_args()

    logger.info(f"GitHub MCP server starting → http://{args.host}:{args.port}/sse")
    logger.info(f"Token   : {'loaded' if GITHUB_TOKEN else 'MISSING'}")
    logger.info(f"Owner   : {DEFAULT_OWNER   or 'MISSING'}")
    logger.info(f"Repo    : {DEFAULT_REPO    or 'MISSING'}")
    logger.info(f"Project : {DEFAULT_PROJECT or 'MISSING'}")
    logger.info(f"RAG     : run ingest.py first if ask_codebase is needed")

    mcp.run(transport="sse", host=args.host, port=args.port)
