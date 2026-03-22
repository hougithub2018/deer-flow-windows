"""
DuckDuckGo Web Search Tool - Free web search using DuckDuckGo.

No API key required. Uses the ddgs library which is already a dependency
of DeerFlow (used by image_search).
"""

import json
import logging
import time

from langchain.tools import tool

from deerflow.config import get_app_config

logger = logging.getLogger(__name__)


def _search_web(
    query: str,
    max_results: int = 5,
    region: str = "wt-wt",
    safesearch: str = "moderate",
    backend: str = "html",
) -> list[dict]:
    """
    Execute web search using DuckDuckGo.

    Args:
        query: Search keywords
        max_results: Maximum number of results to return
        region: Search region (e.g. "wt-wt" for worldwide, "cn-zh" for China)
        safesearch: Safe search level ("off", "moderate", "strict")
        backend: DDG backend ("html" for full results, "api" for instant answers)

    Returns:
        List of search result dicts with title, href, body fields
    """
    try:
        from ddgs import DDGS
    except ImportError:
        logger.error("ddgs library not installed. Run: pip install ddgs")
        return []

    ddgs = DDGS(timeout=15)

    try:
        logger.info(f"[DDG Search] Starting: query='{query}', max={max_results}, region={region}")
        t0 = time.time()
        results = ddgs.text(
            query,
            region=region,
            safesearch=safesearch,
            max_results=max_results,
            backend=backend,
        )
        result_list = list(results) if results else []
        elapsed = time.time() - t0
        logger.info(f"[DDG Search] Done: {len(result_list)} results in {elapsed:.1f}s for '{query}'")
        return result_list

    except Exception as e:
        logger.error(f"[DDG Search] Failed for '{query}': {e}")
        return []


@tool("web_search", parse_docstring=True)
def web_search_tool(query: str) -> str:
    """Search the web for information.

    Use this tool to find current information, news, facts, or any topic
    that requires up-to-date knowledge. Returns search results with titles,
    URLs, and brief content snippets.

    Args:
        query: The search query to look up. Be specific for better results,
            e.g. "AI agent adoption trends 2026" rather than just "AI trends".
    """
    config = get_app_config().get_tool_config("web_search")
    max_results = 5
    region = "wt-wt"

    if config is not None:
        if "max_results" in config.model_extra:
            max_results = config.model_extra.get("max_results", max_results)
        if "region" in config.model_extra:
            region = config.model_extra.get("region", region)

    t_start = time.time()
    logger.info(f"[web_search_tool] Called with query='{query}'")

    results = _search_web(
        query=query,
        max_results=max_results,
        region=region,
    )

    elapsed = time.time() - t_start

    if not results:
        return json.dumps(
            {"error": "No results found", "query": query, "elapsed_ms": round(elapsed * 1000)},
            ensure_ascii=False,
        )

    normalized_results = [
        {
            "title": r.get("title", ""),
            "url": r.get("href", ""),
            "snippet": r.get("body", ""),
        }
        for r in results
    ]

    logger.info(f"[web_search_tool] Returning {len(normalized_results)} results in {elapsed:.1f}s")
    return json.dumps(
        {"results": normalized_results, "query": query, "elapsed_ms": round(elapsed * 1000)},
        indent=2,
        ensure_ascii=False,
    )
