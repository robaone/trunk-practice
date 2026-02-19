# Deploy Develop - Quick Reference

## Decision Tree: Reset vs Merge

```
┌─────────────────────────────────────┐
│ User comments "develop deploy"      │
└──────────────┬──────────────────────┘
               │
               ▼
    ┌──────────────────────┐
    │ Does develop_auto    │────No───┐
    │ exist?               │         │
    └──────────┬───────────┘         │
               │Yes                  │
               ▼                     ▼
    ┌──────────────────────┐  ┌─────────────────┐
    │ Does main have new   │  │ Create from main│
    │ commits?             │  │ (fresh start)   │
    │                      │  │                 │
    │ git log develop_auto │  │ WAS_RESET=true  │
    │   ..main             │  └────────┬────────┘
    └──────────┬───────────┘           │
               │                       │
       ┌───────┴────────┐              │
       │                │              │
      Yes              No              │
       │                │              │
       ▼                ▼              │
┌──────────────┐  ┌────────────────┐  │
│ RESET        │  │ MERGE          │  │
│              │  │                │  │
│ Checkout     │  │ Merge main →   │  │
│ from main    │  │ develop_auto   │  │
│              │  │                │  │
│ WAS_RESET=   │  │ WAS_RESET=     │  │
│ true         │  │ false          │  │
└──────┬───────┘  └────────┬───────┘  │
       │                   │          │
       └───────────┬───────┘          │
                   │                  │
                   ▼                  │
       ┌───────────────────────┐     │
       │ Merge PR branch →     │◄────┘
       │ develop_auto          │
       └───────────┬───────────┘
                   │
                   ▼
       ┌───────────────────────┐
       │ Push to remote        │
       └───────────┬───────────┘
                   │
                   ▼
       ┌───────────────────────┐
       │ Deploy to testing     │
       └───────────┬───────────┘
                   │
                   ▼
       ┌───────────────────────┐
       │ Notify via GitHub     │
       │ comment & Slack       │
       └───────────────────────┘
```

## When Does Reset Happen?

| Condition | Action | Result |
|-----------|--------|--------|
| develop_auto doesn't exist | **Create** from main | WAS_RESET=true |
| develop_auto exists, main unchanged | **Merge** main into develop_auto | WAS_RESET=false |
| develop_auto exists, main has new commits | **Reset** to main | WAS_RESET=true |

## What Happens to Removed PRs?

### Scenario: PR #100 deployed, then abandoned

```
Time 0: PR #100 deploys
  develop_auto = main + PR#100

Time 1: PR #100 closed (not merged)
  develop_auto = main + PR#100  (unchanged)

Time 2: PR #200 merged to main
  main = [new commits]
  develop_auto = [old main] + PR#100

Time 3: PR #300 deploys ← RESET TRIGGERED
  1. Detect: main has new commits
  2. Before reset: identify PR #100 in develop_auto
  3. Query GitHub: PR #100 still open? → Yes
  4. Reset: develop_auto = [new main]
  5. Merge: develop_auto = [new main] + PR#300
  6. Notify: "PR #100 removed from develop"
```

## Notification Matrix

| Reset? | Removed PRs? | GitHub Comment | Slack Notification |
|--------|--------------|----------------|-------------------|
| No | N/A | ✅ Standard success message | ❌ None |
| Yes | None | ✅ "develop_auto reset" message | ❌ None |
| Yes | One or more | ✅ Lists removed PRs | ✅ Sent to channel |

## GitHub Comment Examples

### Case 1: Normal merge (no reset)
```
✅ Successfully deployed to develop environment!

Branch `develop_auto` was synced from `main`, your PR branch 
was merged in, and the result was deployed to `testing`.

Workflow run: [link]
```

### Case 2: Reset with no removed PRs
```
✅ Successfully deployed to develop environment!

Branch `develop_auto` was reset to `main` (new commits detected) 
and your PR was deployed.

Workflow run: [link]
```

### Case 3: Reset with removed PRs
```
✅ Successfully deployed to develop environment!

⚠️ Note: `develop_auto` was reset to `main` (new commits detected)

The following PRs were previously deployed but have been cleared:
- PR #100 (@alice)
- PR #101 (@bob)

If they still need testing in develop, they should re-run `develop deploy`.

Workflow run: [link]
```

## Slack Message Format

Only sent when: `WAS_RESET=true` AND `REMOVED_PRs > 0`

```
╔══════════════════════════════════════════╗
║ ⚠️  Develop Environment Reset            ║
╠══════════════════════════════════════════╣
║                                          ║
║ The `develop_auto` branch was reset to   ║
║ `main` due to new merges.                ║
║                                          ║
║ Removed PRs:                             ║
║ • PR #100 - feature/auth (alice)         ║
║ • PR #101 - feature/payments (bob)       ║
║                                          ║
║ Triggered by: PR #200 - feature/search  ║
║               (charlie)                  ║
║                                          ║
║ 💡 Action needed: If you still need to   ║
║    test in develop, comment              ║
║    `develop deploy` on your PR.          ║
║                                          ║
║ [View Workflow Run]                      ║
╚══════════════════════════════════════════╝
```

## Commands Quick Reference

| Command | Triggers | Result |
|---------|----------|--------|
| `develop deploy` | Exact match in PR comment | Full deploy workflow |
| `please don't develop deploy` | Contains but not exact | No trigger |

## Multi-PR Testing

### Between main merges (accumulation)
```
T0: PR #1 deploys → develop_auto = main + PR#1
T1: PR #2 deploys → develop_auto = main + PR#1 + PR#2
T2: PR #3 deploys → develop_auto = main + PR#1 + PR#2 + PR#3
```

### After main merge (reset)
```
T3: Someone merges PR #10 to main
T4: PR #4 deploys → develop_auto = main(new) + PR#4
    (PR #1, #2, #3 removed from develop_auto)
```

## Configuration Checklist

### Required (for basic functionality)
- [x] GitHub Actions enabled
- [x] Workflow file deployed
- [x] Write access permissions for users

### Optional (for Slack notifications)
- [ ] Slack bot created
- [ ] `SLACK_BOT_TOKEN` secret configured
- [ ] `SLACK_CHANNEL_ID` variable configured
- [ ] Bot added to channel (if private)

## Troubleshooting

### "Why wasn't my PR removed from develop_auto?"

- Main hasn't advanced yet (no new commits)
- Your PR will be removed when the next person deploys *after* main changes

### "I want to re-test my PR after it was removed"

- Comment `develop deploy` again on your PR
- It will be merged into the fresh develop_auto

### "Can I prevent the reset?"

- Not currently - it's automatic when main advances
- This is by design to keep develop_auto clean

### "How do I know if my PR is currently in develop_auto?"

Check git history:
```bash
git log origin/main..origin/develop_auto --oneline
```

Look for your branch name in merge commits.

## Workflow Outputs Reference

Use these in other workflows or for debugging:

| Output | Example Value | Description |
|--------|---------------|-------------|
| `pr_branch` | `feature/new-api` | Branch being deployed |
| `pr_number` | `123` | PR number |
| `pr_author` | `alice` | PR author username |
| `pr_title` | `Add API endpoint` | PR title |
| `was_reset` | `true` | Whether reset occurred |
| `removed_pr_count` | `2` | Number of removed PRs |
| `removed_pr_data` | `100\|feat/a\|alice\|...` | Pipe-delimited PR data |

## Best Practices

1. **Deploy early, deploy often** - Don't wait until your PR is "perfect"
2. **Check notifications** - If main advances, you may need to re-deploy
3. **Close abandoned PRs** - They'll still be tracked until main advances
4. **Re-test after removal** - If your PR was removed, re-deploy to verify compatibility with new main

## Common Patterns

### Pattern 1: Feature branch workflow
```
1. Create PR from feature branch
2. Comment "develop deploy" to test
3. Main advances (someone else's PR merges)
4. Get notified your test was removed
5. Comment "develop deploy" again to re-test
6. Merge to main
```

### Pattern 2: Testing multiple features together
```
1. Deploy PR #1 → develop has feature A
2. Deploy PR #2 → develop has feature A + B
3. Deploy PR #3 → develop has feature A + B + C
4. Test integration of all three
5. Main advances → all three removed
6. Deploy individually or re-deploy set
```

### Pattern 3: Long-running feature
```
1. Deploy PR #500 on Monday
2. Tuesday: main advances → PR #500 removed
3. Re-deploy PR #500 (now with Tuesday's main)
4. Wednesday: main advances → PR #500 removed
5. Re-deploy PR #500 (now with Wednesday's main)
6. Keeps PR #500 compatible with latest main
```
