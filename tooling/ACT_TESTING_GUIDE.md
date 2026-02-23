# Local Testing with `act` - Quick Start Guide

This guide helps you test the deploy-develop workflow locally using `act`.

## Prerequisites

✅ `act` is already installed (`/opt/homebrew/bin/act`)

## Quick Start

### 1. List Available Tests

```bash
./tooling/run-local-tests.sh --list
```

### 2. Run All Tests

```bash
./tooling/run-local-tests.sh
```

### 3. Run a Specific Test

```bash
./tooling/run-local-tests.sh 01
```

### 4. Run with Verbose Output

```bash
./tooling/run-local-tests.sh 01 --verbose
```

## What Gets Tested

The test runner validates **workflow trigger conditions**:

| Test | Scenario | Should Trigger |
|------|----------|----------------|
| 01 | Valid PR comment "develop deploy" | ✅ YES |
| 02 | Wrong command "please don't develop deploy" | ❌ NO |
| 03 | Non-PR issue with "develop deploy" | ❌ NO |
| 04 | Edited comment with "develop deploy" | ❌ NO |
| 05 | Deleted comment with "develop deploy" | ❌ NO |

## Understanding Results

### Test Passes When:
- ✅ Workflow should trigger AND it does trigger
- ✅ Workflow should NOT trigger AND it doesn't trigger

### Test Fails When:
- ❌ Workflow should trigger but it doesn't
- ❌ Workflow should NOT trigger but it does

## Important Limitations

`act` runs workflows locally but has limitations:

### ✅ What Works
- Workflow trigger conditions (on.issue_comment)
- Job conditional logic (if statements)
- Basic environment variable expansion
- Workflow structure validation

### ❌ What Doesn't Work (Needs Real GitHub)
- **GitHub API calls** (permission checks, PR fetching)
- **Slack API calls** (approval requests, notifications)
- **Git push operations** (to remote repository)
- **Real authentication** (GitHub tokens, Slack tokens)

### Expected Failures
When running tests, you'll see steps fail with errors like:
- "HttpError: Not Found" (GitHub API calls)
- "Failed to verify permissions" (API authentication)

**This is expected!** Focus on whether the workflow triggered at all.

## Advanced Usage

### Run Specific Job Only

```bash
act issue_comment \
  -e tooling/test-events/01-valid-pr-comment.json \
  -W .github/workflows/deploy-develop.yaml \
  -j check-reset-needed
```

### Run with Secrets (for testing API calls)

1. Copy example files:
   ```bash
   cp .secrets.example .secrets
   cp .env.example .env
   ```

2. Edit `.secrets` with real tokens:
   ```
   GITHUB_TOKEN=ghp_your_token_here
   SLACK_BOT_TOKEN=xoxb_your_token_here
   ```

3. Run with secrets:
   ```bash
   act issue_comment \
     -e tooling/test-events/01-valid-pr-comment.json \
     -W .github/workflows/deploy-develop.yaml \
     --secret-file .secrets \
     --env-file .env
   ```

### Dry Run (see what would happen)

```bash
act issue_comment \
  -e tooling/test-events/01-valid-pr-comment.json \
  -W .github/workflows/deploy-develop.yaml \
  --dryrun
```

### List All Jobs That Would Run

```bash
act issue_comment \
  -e tooling/test-events/01-valid-pr-comment.json \
  -W .github/workflows/deploy-develop.yaml \
  --list
```

## Manual Testing with `act`

You can also run `act` manually for more control:

```bash
# Basic run
act issue_comment -e tooling/test-events/01-valid-pr-comment.json

# With specific workflow
act issue_comment \
  -e tooling/test-events/01-valid-pr-comment.json \
  -W .github/workflows/deploy-develop.yaml

# Verbose output
act issue_comment \
  -e tooling/test-events/01-valid-pr-comment.json \
  -W .github/workflows/deploy-develop.yaml \
  -v

# Reuse containers (faster for repeated runs)
act issue_comment \
  -e tooling/test-events/01-valid-pr-comment.json \
  --reuse
```

## Creating Custom Test Events

Create new test scenarios in `tooling/test-events/`:

```json
{
  "action": "created",
  "issue": {
    "number": 999,
    "title": "My Test PR",
    "pull_request": {
      "url": "https://api.github.com/repos/VirdocsSoftware/trunk-practice/pulls/999"
    }
  },
  "comment": {
    "body": "develop deploy",
    "user": {
      "login": "test-user"
    }
  },
  "repository": {
    "name": "trunk-practice",
    "full_name": "VirdocsSoftware/trunk-practice",
    "owner": {
      "login": "VirdocsSoftware"
    }
  }
}
```

Then run:
```bash
act issue_comment -e tooling/test-events/my-custom-test.json
```

## Troubleshooting

### "Error: container not found"
```bash
# Pull the required image
docker pull catthehacker/ubuntu:act-latest
```

### "Error: no event available"
Check that the event file exists and has valid JSON:
```bash
cat tooling/test-events/01-valid-pr-comment.json | jq .
```

### "Workflow does not have anything to run"
This is actually a test passing! It means the workflow correctly skipped because conditions weren't met.

### Steps fail with API errors
This is expected for local testing. The important part is whether the workflow/job triggered.

## Next Steps

For comprehensive testing of all scenarios in `deploy-develop.feature`:

1. **Local trigger tests** (this guide) - Test if workflows trigger correctly
2. **Manual integration tests** - Use `tooling/TEST_PLAN.md` for real GitHub testing
3. **Create test PRs** - Test in a real repository environment with actual API calls

## Resources

- [act documentation](https://github.com/nektos/act)
- [GitHub Actions events](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows)
- Test event examples: `tooling/test-events/README.md`
- Full test plan: `tooling/TEST_PLAN.md`
