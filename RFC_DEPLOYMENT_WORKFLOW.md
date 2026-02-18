# RFC: Unified CI/CD Pipeline for Trunk-Based Development

## Status
- **Status**: Documented
- **Last Updated**: 2026-02-18
- **Author**: AI Assistant

## Abstract
This document outlines the CI/CD pipeline implemented across two GitHub Actions workflows:

- **`.github/workflows/trunk.yml`** — the primary CI/CD pipeline for automated testing and environment promotions.
- **`.github/workflows/deploy-develop.yaml`** — an on-demand workflow that lets developers deploy a PR branch to the develop (testing) environment by commenting on the pull request.

The pipeline supports a monorepo-style structure where multiple projects can coexist, and only modified projects are tested and deployed. It follows Trunk-Based Development principles, using a single `main` branch as the source of truth for all deployments.

## Goals
- **Project Isolation**: Detect changes at the project level and only run tests/deploys for modified projects.
- **Environment Parity**: Support distinct `testing`, `staging`, and `production` environments with specific promotion criteria.
- **Automated Validation**: Ensure unit and feature tests pass before any deployment.
- **Controlled Releases**: Implement a manual approval gate for production deployments via Slack integration.
- **AI-Enhanced Metadata**: Automatically generate PR descriptions to improve reviewer context.
- **On-Demand Develop Deploys**: Allow developers to preview any PR branch in the testing environment without merging to a shared branch.

## Workflow Overview

### trunk.yml — Automated Pipeline

#### 1. Initialization & Matrix Generation
The `initialize` job determines which projects have changed relative to the base branch or previous release. It uses a custom Node.js script (`tooling/scripts/generate_matrix.js`) to produce a JSON matrix of projects that require action.

#### 2. Testing Phases
Tests are executed in parallel across the projects identified in the matrix:
- **Unit Tests**: Project-specific unit testing logic defined in local actions or root `package.json`.
- **Feature Tests**: End-to-end or integration tests to ensure system-level stability.

#### 3. Deployment Strategy

##### Testing Environment
- **Trigger**: Pushes to `main` or Pull Requests labeled with `deploy`.
- **Purpose**: Rapid feedback for developers and QA on the latest changes.

##### Staging Environment
- **Trigger**: Creation of a GitHub Release marked as a **Prerelease**.
- **Purpose**: Final verification in a production-like environment before a full release.

##### Production Environment
- **Trigger**: Creation of a full GitHub Release (not a prerelease).
- **Gate**: Requires explicit approval via Slack (using the `TigerWest/slack-approval` action).
- **Purpose**: Serving live traffic to users.

---

### deploy-develop.yaml — On-Demand PR Deploy

This workflow enables any developer with write access to deploy their PR branch to the testing environment without merging to `main` or tagging a release. It is triggered by a PR comment and manages a dedicated `develop_auto` branch to prevent the shared develop branch from drifting out of sync with `main`.

#### How to trigger

Comment exactly the following on a pull request:

```
develop deploy
```

The workflow will post back to the PR at each stage (started, conflict, success/failure).

#### Branch management strategy

1. If `develop_auto` does not exist, it is created from `main`.
2. If `develop_auto` already exists, `main` is merged into it first to ensure it is up to date.
3. The PR branch is then merged into `develop_auto`.
4. If any merge step produces a conflict, the workflow fails immediately and posts a comment to the PR listing the conflicting files with instructions to resolve and re-trigger.
5. On success, `develop_auto` is force-pushed (with lease) and the deploy job runs against it.

#### Safety & security controls

- **Exact command match**: The trigger is a strict equality check on the comment body, preventing accidental triggers from comments that merely contain the phrase.
- **Permission gate**: Only collaborators with `write`, `maintain`, or `admin` access can trigger a deployment.
- **Fork PR block**: PRs opened from forks are rejected immediately with an explanatory comment. This prevents environment secrets from being exposed to untrusted code.
- **Concurrency serialization**: A workflow-level `concurrency` group ensures concurrent triggers queue rather than race, preventing non-deterministic state on the shared `develop_auto` branch.

#### Job pipeline

| Job | Runs on | Purpose |
| :--- | :--- | :--- |
| `prepare` | `ubuntu-latest` | Validates permissions, checks for forks, manages `develop_auto`, reports conflicts |
| `deploy` | `ubuntu-latest` | Checks out `develop_auto` and runs the deploy against the `testing` environment |
| `notify` | `ubuntu-latest` | Posts the final success, failure, or cancellation result back to the PR |

---

## Detailed Job Specifications

### trunk.yml

| Job | Description | Environment | Trigger |
| :--- | :--- | :--- | :--- |
| `initialize` | Generates the project matrix and identifies the latest release. | N/A | Push, PR, Release |
| `unit-tests` | Runs unit tests for each modified project. | N/A | Matrix matches |
| `feature-tests` | Runs E2E tests for each modified project. | N/A | Matrix matches |
| `update-pr-description` | Uses Gemini AI to update PR descriptions based on changes. | N/A | PR with `auto-pr-description` label |
| `deploy-to-testing` | Deploys modified projects to the testing environment. | `testing` | Push to `main` or `deploy` label |
| `deploy-to-staging` | Deploys to staging for pre-release verification. | `staging` | Prerelease created |
| `request-production-approval` | Sends a Slack notification for manual production approval. | N/A | Full Release created |
| `deploy-to-production` | Deploys to production after Slack approval. | `production` | Full Release + Approval |

### deploy-develop.yaml

| Job | Description | Environment | Trigger |
| :--- | :--- | :--- | :--- |
| `prepare` | Verifies permissions, blocks forks, manages `develop_auto`, reports merge conflicts. | N/A | PR comment `develop deploy` |
| `deploy` | Deploys `develop_auto` to the testing environment. | `testing` | `prepare` success |
| `notify` | Posts deployment result back to the PR. | N/A | Always (after `prepare` succeeds) |

---

## Infrastructure & Configuration
- **Node.js Version**: 22.x
- **Secrets Required**:
    - `GITHUB_TOKEN`: For repository interactions and branch management.
    - `GEMINI_API_KEY`: For AI description generation.
    - `SLACK_APP_TOKEN`, `SLACK_BOT_TOKEN`, etc.: For production approval workflow.
- **Variables**:
    - `SLACK_MEMBER_ID`: ID of the designated production approver.

## Future Considerations
- **Canary Deploys**: Implementing traffic shifting for production releases.
- **Automated Rollbacks**: Detecting post-deploy failures and reverting to the previous stable release.
- **Enhanced Matrix Logic**: Support for dependency tracking between projects to ensure downstream impacts are tested.
- **develop_auto cleanup**: Automatically delete or reset the `develop_auto` branch after a PR is merged or closed.
