# Testing Infrastructure for Deploy Develop Workflow

This directory contains comprehensive testing tools for the `deploy-develop` GitHub Actions workflow.

## 🚀 Quick Start

```bash
# Run all automated tests (takes ~30 seconds)
./tooling/run-local-tests.sh
```

**Expected output:**
```
================================================
  Deploy Develop Workflow - Local Test Runner
================================================

Total tests: 8
Passed: 8
Failed: 0
```

## 📚 Documentation

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **[QUICK_TEST_REFERENCE.md](QUICK_TEST_REFERENCE.md)** | One-page cheat sheet | Daily reference |
| **[TESTING_SUMMARY.md](TESTING_SUMMARY.md)** | Complete testing guide | Setup & overview |
| **[ACT_TESTING_GUIDE.md](ACT_TESTING_GUIDE.md)** | Detailed `act` usage | Deep dive into local testing |
| **[TEST_PLAN.md](TEST_PLAN.md)** | Manual test checklist (150+ scenarios) | Comprehensive validation |
| **[deploy-develop.feature](deploy-develop.feature)** | Gherkin specification | Behavior reference |

## 🎯 Test Coverage

### Automated Tests (via `act`)

**8 test scenarios covering:**
- ✅ Workflow triggering with exact command
- ✅ Command pattern matching (avoiding false triggers)
- ✅ PR vs Issue detection
- ✅ Action type filtering (created vs edited/deleted)
- ✅ Multiline comment handling

**Run time:** ~30 seconds  
**Coverage:** Trigger conditions only (~5% of total scenarios)

### Manual Tests (via TEST_PLAN.md)

**150+ test scenarios covering:**
- Workflow triggering (5 scenarios)
- Concurrency control (2 scenarios)
- Permission verification (5 scenarios)
- Fork PR blocking (3 scenarios)
- Approval workflows (10 scenarios)
- Branch operations (13 scenarios)
- Merge conflicts (6 scenarios)
- Deploy execution (11 scenarios)
- Notifications (8 scenarios)
- Error handling (10+ scenarios)
- Edge cases (30+ scenarios)
- Integration scenarios (50+ scenarios)

**Run time:** 2-4 hours  
**Coverage:** All workflow functionality (100%)

## 🏗️ What's Included

### Test Runner
- `run-local-tests.sh` - Automated test execution script
- Runs 8 test scenarios using `act`
- Color-coded output
- Individual or batch test execution
- Verbose mode for debugging

### Test Events
- `test-events/*.json` - 8 GitHub event payloads
- Simulate different PR comment scenarios
- Valid and invalid trigger conditions
- Multiline comment variations

### Configuration
- `.actrc` - act configuration (in project root)
- `.secrets.example` - Template for GitHub/Slack tokens
- `.env.example` - Template for environment variables

## 🔧 Usage Examples

### Run All Tests
```bash
./tooling/run-local-tests.sh
```

### Run Specific Test
```bash
./tooling/run-local-tests.sh 01
```

### List Available Tests
```bash
./tooling/run-local-tests.sh --list
```

### Debug a Test
```bash
./tooling/run-local-tests.sh 01 --verbose
```

### Check Test Logs
```bash
cat /tmp/act-test-01.log
```

## ✅ Test Scenarios

| # | Scenario | Expected Result |
|---|----------|----------------|
| 01 | Valid PR comment: `"develop deploy"` | ✅ Triggers workflow |
| 02 | Invalid command: `"please don't develop deploy"` | ❌ Does not trigger |
| 03 | Non-PR issue with `"develop deploy"` | ❌ Does not trigger |
| 04 | Edited comment with `"develop deploy"` | ❌ Does not trigger |
| 05 | Deleted comment with `"develop deploy"` | ❌ Does not trigger |
| 06 | Multiline starting with `"develop deploy"` | ✅ Triggers workflow* |
| 07 | Multiline ending with `"develop deploy"` | ✅ Triggers workflow* |
| 08 | Multiline containing `"develop deploy"` | ✅ Triggers workflow* |

\* `act` has limitations with multiline string functions; tests account for this

## ⚠️ Known Limitations

### Local Testing with `act`

1. **Job conditionals** - `act` doesn't fully evaluate conditions like `github.event.issue.pull_request != null`
   - Tests 03-05 account for this
   - Real GitHub behaves correctly

2. **Multiline string functions** - `startsWith()`, `endsWith()`, `contains()` don't work properly in `act`
   - Tests 06-08 account for this
   - Real GitHub behaves correctly

3. **API calls fail** - GitHub API and Slack API calls won't work locally
   - Permission checks
   - PR data fetching
   - Slack notifications
   - Use manual tests for these scenarios

4. **No real git operations** - Branch pushes, merges happen locally only
   - Use manual tests for integration validation

## 📖 Workflow Under Test

**File:** `.github/workflows/deploy-develop.yaml`

**Purpose:** Deploy PR branches to develop environment

**Trigger:** Comment `"develop deploy"` on a pull request

**Key Features:**
- Permission verification
- Fork PR blocking
- Branch preparation with reset detection
- Slack approval workflow
- Merge conflict handling
- Automated deployment
- Status notifications

## 🎓 Learning Path

1. **Start here:** Run `./tooling/run-local-tests.sh`
2. **Understand results:** Read `QUICK_TEST_REFERENCE.md`
3. **Dive deeper:** Review `ACT_TESTING_GUIDE.md`
4. **Manual testing:** Use `TEST_PLAN.md` for comprehensive validation
5. **Understand behavior:** Study `deploy-develop.feature`

## 🔄 Development Workflow

### Before Committing
```bash
./tooling/run-local-tests.sh
```

### After Workflow Changes
```bash
# Run local tests
./tooling/run-local-tests.sh

# Test on real PR if significant changes
# Use TEST_PLAN.md for comprehensive validation
```

### Adding New Features
1. Add scenario to `deploy-develop.feature`
2. Create test event in `test-events/` (if applicable)
3. Update `run-local-tests.sh` with new test
4. Add checklist item to `TEST_PLAN.md`
5. Document any new limitations

## 📊 Test Results

Current status: **✅ All tests passing (8/8)**

```
================================================
Test Summary
================================================
Total tests: 8
Passed: 8
Failed: 0
```

## 🆘 Troubleshooting

### Tests won't run
```bash
# Check act is installed
which act

# Make script executable
chmod +x tooling/run-local-tests.sh

# Check Docker is running
docker ps
```

### Test fails unexpectedly
```bash
# Run with verbose output
./tooling/run-local-tests.sh 01 --verbose

# Check the log file
cat /tmp/act-test-01.log

# Validate event JSON
cat tooling/test-events/01-valid-pr-comment.json | jq .
```

### Act pulls wrong image
```bash
# Check .actrc configuration
cat .actrc

# Manually pull image
docker pull catthehacker/ubuntu:act-latest
```

## 🔗 Related Files

- `.github/workflows/deploy-develop.yaml` - The workflow being tested
- `.github/workflows/DEPLOY-DEVELOP.md` - Workflow documentation
- `.actrc` - act configuration
- `.gitignore` - Excludes test logs and secrets

## 📝 Contributing

When modifying the workflow:

1. ✅ Run local tests
2. ✅ Update feature spec if behavior changes
3. ✅ Update test plan if new scenarios added
4. ✅ Test manually for API-dependent changes
5. ✅ Document any new limitations

## Questions?

- **Quick ref:** `QUICK_TEST_REFERENCE.md`
- **Full guide:** `TESTING_SUMMARY.md`
- **act details:** `ACT_TESTING_GUIDE.md`
- **Manual tests:** `TEST_PLAN.md`
- **Specification:** `deploy-develop.feature`
