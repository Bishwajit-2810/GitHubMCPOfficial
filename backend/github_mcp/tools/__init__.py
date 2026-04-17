"""Tools module for GitHub MCP Server.

This module exports all tool registration functions.
"""

from .files import register_list_files_tool
from .branches import register_create_branch_tool
from .file_operations import register_create_file_tool
from .pull_requests import register_create_pull_request_tool
from .tasks import register_create_project_task_tool
from .task_list import register_list_project_tasks_tool
from .task_assign import register_assign_task_tool
from .task_status import register_update_task_status_tool
from .project_fields import register_create_project_field_tool
from .task_fields import register_set_task_fields_tool
from .rag_query import register_ask_codebase_tool, register_explore_codebase_tool

__all__ = [
    "register_list_files_tool",
    "register_create_branch_tool",
    "register_create_file_tool",
    "register_create_pull_request_tool",
    "register_create_project_task_tool",
    "register_list_project_tasks_tool",
    "register_assign_task_tool",
    "register_update_task_status_tool",
    "register_create_project_field_tool",
    "register_set_task_fields_tool",
    "register_ask_codebase_tool",
    "register_explore_codebase_tool",
]


def register_all_tools(mcp):
    """Register all GitHub MCP tools with the FastMCP server.

    Args:
        mcp: FastMCP instance to register tools with
    """
    register_list_files_tool(mcp)
    register_create_branch_tool(mcp)
    register_create_file_tool(mcp)
    register_create_pull_request_tool(mcp)
    register_create_project_task_tool(mcp)
    register_list_project_tasks_tool(mcp)
    register_assign_task_tool(mcp)
    register_update_task_status_tool(mcp)
    register_create_project_field_tool(mcp)
    register_set_task_fields_tool(mcp)
    register_ask_codebase_tool(mcp)
    register_explore_codebase_tool(mcp)
