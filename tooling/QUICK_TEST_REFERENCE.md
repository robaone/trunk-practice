# 🧪 Quick Test Reference

## Run Tests

```bash
# All tests (30 seconds)
./tooling/run-local-tests.sh

# Specific test
./tooling/run-local-tests.sh 01

# List tests
./tooling/run-local-tests.sh --list

# Verbose output
./tooling/run-local-tests.sh 01 --verbose
```

## Test Results Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Test passed |
| ❌ | Test failed |
| ⚠️ | Known `act` limitation (expected behavior) |

## Current Test Suite

| # | Test | Expected | Coverage |
|---|------|----------|----------|
| 01 | Valid PR comment `"develop deploy"` | ✅ Triggers | Workflow trigger |
| 02 | Wrong command `"don't develop deploy"` | ❌ Skips | Command matching |
| 03 | Non-PR issue comment | ❌ Skips | PR detection |
| 04 | Edited comment | ❌ Skips | Action filtering |
| 05 | Deleted comment | ❌ Skips | Action filtering |
| 06 | Multiline start `"develop deploy\n..."` | ✅ Triggers ⚠️ | Pattern matching |
| 07 | Multiline end `"...\ndevelop deploy"` | ✅ Triggers ⚠️ | Pattern matching |
| 08 | Multiline middle `"...\ndevelop deploy\n..."` | ✅ Triggers ⚠️ | Pattern matching |

⚠️ = `act` limitation documented, real GitHub behaves correctly

## Quick Diagnosis

### All tests pass
✅ Workflow trigger logic is working correctly

### Test 01 fails
❌ Basic trigger is broken - check workflow `on:` section

### Test 02 fails
❌ Command matching too loose - check conditional patterns

### Tests 03-05 have notes
⚠️ Expected - `act` doesn't fully evaluate job conditionals

### Tests 06-08 have notes
⚠️ Expected - `act` doesn't handle multiline string functions

## What's Not Tested Locally

- ❌ GitHub API calls (permissions, PR data)
- ❌ Slack API integration
- ❌ Git push operations
- ❌ Branch merging logic
- ❌ Conflict resolution
- ❌ Deployment execution
- ❌ Concurrency control

**→ Use `tooling/TEST_PLAN.md` for these scenarios**

## File Locations

```
tooling/
├── run-local-tests.sh          ← Run this
├── TESTING_SUMMARY.md          ← Full guide
├── TEST_PLAN.md                ← Manual tests
├── ACT_TESTING_GUIDE.md        ← act details
├── deploy-develop.feature      ← Specification
└── test-events/*.json          ← Test data
```

## Common Commands

```bash
# Run before committing
./tooling/run-local-tests.sh

# Debug a failure
./tooling/run-local-tests.sh 01 --verbose

# Check logs
cat /tmp/act-test-01.log

# Validate JSON
cat tooling/test-events/01-valid-pr-comment.json | jq .

# Manual run with act
act issue_comment -e tooling/test-events/01-valid-pr-comment.json
```

## When to Use Each Approach

| Task | Use |
|------|-----|
| Before commit | `./tooling/run-local-tests.sh` |
| Trigger changes | Local tests + Test 01 |
| Branch logic changes | Manual TEST_PLAN.md |
| Slack integration | Manual TEST_PLAN.md |
| New feature | Add to all three |
| Quick validation | Local tests only |
| Pre-release | Full manual testing |

## Success Criteria

✅ **Setup works:** All 8 tests pass  
✅ **Basic function:** Test 01 passes  
✅ **Command matching:** Test 02 passes  
✅ **Full validation:** Complete TEST_PLAN.md  

## Get Help

- Full guide: `tooling/TESTING_SUMMARY.md`
- act details: `tooling/ACT_TESTING_GUIDE.md`
- Manual tests: `tooling/TEST_PLAN.md`
- Specification: `tooling/deploy-develop.feature`
