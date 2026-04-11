#!/usr/bin/env python3
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

"""Tests for asyncio event loop handling in the GitHub extension.

Regression tests for GitHub issue #1215, where `sl pr pull` would fail with:
RuntimeError("There is no current event loop in thread 'MainThread'.")

The root cause was using asyncio.get_event_loop() which raises RuntimeError
on Python 3.10+ when no event loop is running. The fix replaces all such
calls with asyncio.run().
"""

import unittest
from unittest.mock import AsyncMock, patch

from sapling.ext.github.github_cli_endpoint import GitHubCLIEndpoint
from sapling.ext.github.pullrequest import PullRequestId
from sapling.result import Err, Ok


class GitHubCLIEndpointTest(unittest.TestCase):
    """Tests for GitHubCLIEndpoint asyncio handling."""

    @patch(
        "sapling.ext.github.github_cli_endpoint.make_request", new_callable=AsyncMock
    )
    def test_graphql_sync_works_without_event_loop(self, mock_make_request):
        """Regression test for #1215: graphql_sync must work without a running event loop."""
        mock_make_request.return_value = Ok({"data": {"test": "value"}})

        endpoint = GitHubCLIEndpoint("github.com")
        result = endpoint.graphql_sync("query { test }", foo="bar")

        self.assertEqual(result, {"data": {"test": "value"}})
        mock_make_request.assert_called_once()

    @patch(
        "sapling.ext.github.github_cli_endpoint.make_request", new_callable=AsyncMock
    )
    def test_rest_works_without_event_loop(self, mock_make_request):
        """Regression test for #1215: rest() must work without a running event loop."""
        mock_make_request.return_value = Ok({"status": "ok"})

        endpoint = GitHubCLIEndpoint("github.com")
        result = endpoint.rest("GET", "/repos/owner/repo")

        self.assertEqual(result, {"status": "ok"})
        mock_make_request.assert_called_once()

    @patch(
        "sapling.ext.github.github_cli_endpoint.make_request", new_callable=AsyncMock
    )
    def test_graphql_sync_raises_on_error(self, mock_make_request):
        mock_make_request.return_value = Err("API error message")

        endpoint = GitHubCLIEndpoint("github.com")
        with self.assertRaises(RuntimeError) as context:
            endpoint.graphql_sync("query { test }")

        self.assertIn("API error message", str(context.exception))

    @patch(
        "sapling.ext.github.github_cli_endpoint.make_request", new_callable=AsyncMock
    )
    def test_rest_raises_on_error(self, mock_make_request):
        mock_make_request.return_value = Err("REST API error")

        endpoint = GitHubCLIEndpoint("github.com")
        with self.assertRaises(RuntimeError) as context:
            endpoint.rest("POST", "/some/endpoint")

        self.assertIn("REST API error", str(context.exception))


_PR_RESPONSE_DATA = {
    "data": {
        "repository": {
            "pullRequest": {
                "id": "PR_123",
                "number": 42,
                "url": "https://github.com/owner/repo/pull/42",
                "title": "Test PR",
                "body": "Test body",
                "isDraft": False,
                "state": "MERGED",
                "closed": True,
                "merged": True,
                "reviewDecision": "APPROVED",
                "commits": {"nodes": []},
                "baseRefName": "main",
                "baseRefOid": "abc123",
                "baseRepository": {"nameWithOwner": "owner/repo"},
                "headRefName": "feature",
                "headRefOid": "def456",
                "headRepository": {"nameWithOwner": "owner/repo"},
            }
        }
    }
}

_TEST_PR_ID = PullRequestId(
    hostname="github.com", owner="owner", name="repo", number=42
)


class GraphQLModuleTest(unittest.TestCase):
    """Tests for graphql.py asyncio handling."""

    @patch("sapling.ext.github.graphql.make_request", new_callable=AsyncMock)
    def test_get_pull_request_data_works_without_event_loop(self, mock_make_request):
        """Regression test: get_pull_request_data must work without a running event loop."""
        from sapling.ext.github.graphql import get_pull_request_data

        mock_make_request.return_value = Ok(_PR_RESPONSE_DATA)

        result = get_pull_request_data(_TEST_PR_ID)

        self.assertIsNotNone(result)
        mock_make_request.assert_called_once()

    @patch("sapling.ext.github.graphql.make_request", new_callable=AsyncMock)
    def test_get_pull_request_data_returns_none_on_error(self, mock_make_request):
        from sapling.ext.github.graphql import get_pull_request_data

        mock_make_request.return_value = Err("API error")

        result = get_pull_request_data(_TEST_PR_ID)

        self.assertIsNone(result)

    def test_get_pull_request_data_list_works_without_event_loop(self):
        """Regression test: get_pull_request_data_list must work without a running event loop."""
        from sapling.ext.github.graphql import get_pull_request_data_list

        pr_response = Ok(_PR_RESPONSE_DATA)

        endpoint = GitHubCLIEndpoint("github.com")
        endpoint.graphql = AsyncMock(return_value=pr_response)

        result = get_pull_request_data_list(endpoint, [_TEST_PR_ID])

        self.assertEqual(len(result), 1)
        self.assertIsNotNone(result[0])


if __name__ == "__main__":
    import silenttestrunner

    silenttestrunner.main(__name__)
