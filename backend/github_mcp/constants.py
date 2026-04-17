"""Constants for GitHub MCP Server.

Contains API URLs, GraphQL queries, and other constant values.
"""

# GitHub API endpoints
GITHUB_API = "https://api.github.com"
GRAPHQL_URL = "https://api.github.com/graphql"

# GraphQL Fragments
PROJECT_FIELDS_FRAGMENT = """
  id title
  fields(first: 50) {
    nodes {
      __typename
      ... on ProjectV2Field           { id name dataType }
      ... on ProjectV2SingleSelectField {
        id name
        options { id name }
      }
      ... on ProjectV2IterationField  { id name }
    }
  }
"""

# GraphQL Queries
USER_PROJECT_QUERY = (
    """
query($login: String!, $number: Int!) {
  user(login: $login) {
    projectV2(number: $number) {
      """
    + PROJECT_FIELDS_FRAGMENT
    + """
    }
  }
}
"""
)

ORG_PROJECT_QUERY = (
    """
query($login: String!, $number: Int!) {
  organization(login: $login) {
    projectV2(number: $number) {
      """
    + PROJECT_FIELDS_FRAGMENT
    + """
    }
  }
}
"""
)

# Page size for pagination
PAGE_SIZE = 100

# Built-in project field names (not custom fields)
BUILTIN_FIELDS = {
    "title",
    "assignees",
    "labels",
    "linked pull requests",
    "milestone",
    "repository",
    "reviewers",
    "status",
}
