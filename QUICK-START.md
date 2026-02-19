# Deploy-Develop Quick Start Guide

## For Developers

### Deploy Your PR

Comment on your PR:
```
develop deploy
```

That's it! The workflow will:
1. ✅ Check your permissions
2. ✅ Check if reset is needed
3. ✅ Request approval if needed (via Slack)
4. ✅ Merge your branch to `develop_auto`
5. ✅ Deploy to testing environment
6. ✅ Comment back with results

### If Approval is Needed

You'll see a message in your PR:
```
🚀 Deploy to develop triggered
Preparing develop_auto branch...
```

A team member will receive a Slack message with Approve/Reject buttons.

### If Deployment Succeeds

```
✅ Successfully deployed to develop environment!

Branch develop_auto was synced from main, your PR branch was merged in,
and the result was deployed to testing.
```

### If Approval is Rejected

```
🚫 Deploy to develop cancelled

The reset of develop_auto was rejected or timed out.

Options:
1. Wait for other PRs to be merged to main
2. Coordinate with team in Slack
3. Re-trigger with "develop deploy" later
```

## For Approvers (Team Leads)

### When You'll Get a Slack Message

When someone triggers a deploy and:
- `main` has new commits
- `develop_auto` has other PRs that will be removed

### What the Message Shows

```
🔄 Reset develop_auto branch?

Main has new commits. Resetting develop_auto will remove:
• PR #100 - feature/auth (@alice)
• PR #101 - feature/payments (@bob)

Triggered by: PR #123 (@charlie)

[Approve] [Reject]
```

### Decision Guidelines

**Approve if:**
- ✅ Removed PRs are already merged or closed
- ✅ Authors have been notified
- ✅ Triggering PR is high priority
- ✅ Removed PRs can be re-deployed later

**Reject if:**
- ❌ Removed PRs are still in active testing
- ❌ Authors haven't been notified
- ❌ Better to wait for merges to main first

### After You Respond

- Slack message updates to show your decision
- PR gets commented with result
- Workflow continues or cancels automatically

## For Admins

### Initial Setup Required

1. **Create Slack App** (one-time)
   - Go to https://api.slack.com/apps
   - Create new app
   - Enable Socket Mode
   - Enable Interactivity
   - Add bot scopes: `chat:write`, `channels:read`, `groups:read`
   - Create app-level token with `connections:write` scope
   - Install to workspace

2. **Configure GitHub Secrets**

Go to Repository Settings → Secrets and variables → Actions → New secret:

```
Name: SLACK_APP_TOKEN
Value: xapp-1-xxxxx (from Slack app)

Name: SLACK_BOT_TOKEN
Value: xoxb-xxxxx (from Slack app)

Name: SLACK_SIGNING_SECRET
Value: xxxxx (from Slack app)

Name: SLACK_CHANNEL_ID
Value: C01234ABCDE (your deployment channel ID)
```

3. **Configure GitHub Variables**

Go to Repository Settings → Secrets and variables → Actions → Variables → New variable:

```
Name: SLACK_APPROVERS
Value: U01234ABCDE,U56789FGHIJ (comma-separated member IDs)
```

4. **Invite Bot to Channel**

In your Slack channel:
```
/invite @YourBotName
```

### Troubleshooting

**Approval not working:**
- Check bot is in channel
- Verify all secrets are set
- Check Slack app has correct scopes
- Ensure Socket Mode is enabled

**False triggers:**
- Workflow only triggers on exact "develop deploy" on its own line
- Comments like "don't develop deploy" won't trigger

**Stuck workflows:**
- Check concurrency - only one runs at a time
- Others queue automatically

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ 1. check-reset-needed                                   │
│    - Verify permissions                                 │
│    - Block forks                                        │
│    - Detect if reset needed                             │
│    - Identify removed PRs                               │
└──────────────┬──────────────────────────────────────────┘
               │
               ├─ reset needed? ─→ YES ─┐
               │                         │
               └─ reset needed? ─→ NO ──┼─────┐
                                         │     │
                      ┌──────────────────┘     │
                      │                        │
               ┌──────▼──────────────────┐     │
               │ 2. request-reset-approval│     │
               │    - Send Slack message  │     │
               │    - Wait for response   │     │
               │    - Timeout: 10 min     │     │
               └──────┬──────────────────┘     │
                      │                        │
                      ├─ approved ─────────────┼─────┐
                      │                        │     │
                      └─ rejected ────┐        │     │
                                      │        │     │
                            ┌─────────▼────────▼─────▼─────┐
                            │ 3. prepare                    │
                            │    - Reset or merge main      │
                            │    - Merge PR branch          │
                            │    - Push develop_auto        │
                            └─────────┬─────────────────────┘
                                      │
                            ┌─────────▼─────────┐
                            │ 4. deploy         │
                            │    - Checkout     │
                            │    - npm install  │
                            │    - npm deploy   │
                            └─────────┬─────────┘
                                      │
                            ┌─────────▼─────────┐
                            │ 5. notify         │
                            │    - Comment PR   │
                            │    - Slack notify │
                            └───────────────────┘

                            ┌───────────────────────────────┐
                            │ notify-approval-rejected      │
                            │    (runs if approval fails)   │
                            └───────────────────────────────┘
```

## More Info

- Full documentation: `.github/workflows/DEPLOY-DEVELOP.md`
- Feature specs: `tooling/deploy-develop.feature`
- Implementation details: `IMPLEMENTATION-SUMMARY.md`
