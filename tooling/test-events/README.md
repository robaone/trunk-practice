# Test Events for Deploy Develop Workflow

This directory contains GitHub event payloads for testing the deploy-develop workflow locally using `act`.

## Event Files

### Workflow Trigger Tests

1. **01-valid-pr-comment.json** - Valid PR comment with "develop deploy"
   - Should trigger the workflow
   - Tests basic happy path

2. **02-wrong-command.json** - PR comment with "please don't develop deploy"
   - Should NOT trigger the workflow
   - Tests command matching logic

3. **03-non-pr-issue.json** - Regular issue (not PR) with "develop deploy"
   - Should NOT trigger the workflow
   - Tests PR detection

4. **04-edited-comment.json** - Edited comment with "develop deploy"
   - Should NOT trigger the workflow
   - Tests action type filtering (only "created")

6. **06-multiline-comment-start.json** - PR comment with "develop deploy\nwith context"
   - Should trigger the workflow
   - Tests startsWith pattern matching

7. **07-multiline-comment-end.json** - PR comment with "context\ndevelop deploy"
   - Should trigger the workflow
   - Tests endsWith pattern matching

8. **08-multiline-comment-middle.json** - PR comment with "before\ndevelop deploy\nafter"
   - Should trigger the workflow
   - Tests contains pattern matching

## Usage

Run tests using the provided test runner script:

```bash
# Run all tests
./tooling/run-local-tests.sh

# Run a specific test
./tooling/run-local-tests.sh 01

# Run with verbose output
./tooling/run-local-tests.sh --verbose

# List available tests
./tooling/run-local-tests.sh --list
```

Or run manually with `act`:

```bash
# Run with a specific event file
act issue_comment -e tooling/test-events/01-valid-pr-comment.json -W .github/workflows/deploy-develop.yaml

# Run with secrets (if needed)
act issue_comment -e tooling/test-events/01-valid-pr-comment.json -W .github/workflows/deploy-develop.yaml --secret-file .secrets

# Run specific job
act issue_comment -e tooling/test-events/01-valid-pr-comment.json -W .github/workflows/deploy-develop.yaml -j check-reset-needed
```

## Limitations of Local Testing

### What Works
- Basic workflow trigger conditions
- Job conditionals (if statements)
- Basic shell scripts
- Some GitHub Actions (context variables, outputs)

### What Doesn't Work / Needs Mocking
- **GitHub API calls** - `actions/github-script` will fail without real API
- **Slack API calls** - Need mock Slack endpoints
- **Real git operations** - Branch pushes to remote won't work
- **Permissions checks** - `getCollaboratorPermissionLevel` API call will fail
- **PR data fetching** - `pulls.get` API call will fail

### Workarounds

1. **Mock GitHub API calls**: Create a local mock server or use `--container-options` with act
2. **Use environment variables**: Set test values for API responses
3. **Skip API-dependent jobs**: Focus on testing trigger logic and conditionals
4. **Integration tests**: Some scenarios need real GitHub environment

## Environment Setup

For tests that need environment variables or secrets:

1. Create `.secrets` file in project root:
```
GITHUB_TOKEN=your_test_token
SLACK_BOT_TOKEN=xoxb-test-token
SLACK_CHANNEL_ID=C12345678
```

2. Create `.env` file for variables:
```
SLACK_CHANNEL_ID=C12345678
```

3. Run with secrets:
```bash
act issue_comment -e tooling/test-events/01-valid-pr-comment.json --secret-file .secrets --env-file .env
```

## Expected Results

| Test | Should Trigger | Jobs to Run | Expected Outcome |
|------|---------------|-------------|------------------|
| 01-valid-pr-comment | ✅ Yes | check-reset-needed | Workflow starts, permission check attempted |
| 02-wrong-command | ❌ No | None | Workflow skipped |
| 03-non-pr-issue | ❌ No | None | Workflow skipped |
| 04-edited-comment | ❌ No | None | Workflow skipped (wrong action) |
| 05-deleted-comment | ❌ No | None | Workflow skipped (wrong action) |
| 06-multiline-start | ✅ Yes | check-reset-needed | Workflow starts (startsWith match) |
| 07-multiline-end | ✅ Yes | check-reset-needed | Workflow starts (endsWith match) |
| 08-multiline-middle | ✅ Yes | check-reset-needed | Workflow starts (contains match) |

## Interpreting Results

- **Workflow triggered**: Look for "Workflow ID" in output
- **Workflow skipped**: You'll see "Skipping job..." messages
- **Job ran**: Check for job logs and step outputs
- **Job skipped**: Look for condition evaluation in logs

## Next Steps

For more comprehensive testing:
1. Set up integration tests against a test repository
2. Create mock GitHub API server
3. Use the manual test plan in `tooling/TEST_PLAN.md`
4. Test in a real PR environment for full coverage
