# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

"""make calls to GitHub's GraphQL API"""

import asyncio
from typing import Dict, Iterable, List, Optional, Union

from .github_endpoint import GitHubEndpoint
from .github_gh_cli import make_request
from .pullrequest import GraphQLPullRequest, PullRequestId


PULL_REQUEST_QUERY = """
query PullRequestQuery($owner: String!, $name: String!, $number: Int!) {
  repository(name: $name, owner: $owner) {
    pullRequest(number: $number) {
      id
      number
      url
      title
      body

      isDraft
      state
      closed
      merged
      reviewDecision

      commits(last: 1) {
        nodes {
          commit {
            statusCheckRollup {
              state
            }
          }
        }
      }

      baseRefName
      baseRefOid
      baseRepository {
        nameWithOwner
      }
      headRefName
      headRefOid
      headRepository {
        nameWithOwner
      }
    }
  }
}
"""


def get_pull_request_data(pr: PullRequestId) -> Optional[GraphQLPullRequest]:
    params = _generate_params(pr)
    result = asyncio.run(make_request(params, hostname=pr.get_hostname()))
    if result.is_err():
        # Log error?
        return None

    pr = result.unwrap()["data"]["repository"]["pullRequest"]
    return GraphQLPullRequest(pr)


async def _gather_pull_request_data(
    github: GitHubEndpoint,
    pr_list: Iterable[PullRequestId],
) -> List[object]:
    requests = [
        github.graphql(PULL_REQUEST_QUERY, **_generate_params(pr)) for pr in pr_list
    ]
    return await asyncio.gather(*requests)


def get_pull_request_data_list(
    github: GitHubEndpoint,
    pr_list: Iterable[PullRequestId],
) -> List[Optional[GraphQLPullRequest]]:
    responses = asyncio.run(_gather_pull_request_data(github, pr_list))
    result = []
    for resp in responses:
        if resp.is_err():
            result.append(None)
        else:
            pr_data = resp.unwrap()["data"]["repository"]["pullRequest"]
            result.append(GraphQLPullRequest(pr_data))
    return result


def _generate_params(pr: PullRequestId) -> Dict[str, Union[str, int, bool]]:
    return {
        "owner": pr.owner,
        "name": pr.name,
        "number": pr.number,
    }
