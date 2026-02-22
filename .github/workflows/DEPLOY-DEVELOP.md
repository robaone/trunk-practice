# Deploy to Develop Workflow

This workflow enables developers to deploy their PR branches to the `develop` environment by commenting `develop deploy` on a pull request.

## How It Works

1. **Trigger**: Comment `develop deploy` on any pull request
2. **Permission Check**: Only users with write/admin/maintain access can trigger deployments
3. **Fork Check**: Fork PRs are blocked for security reasons
4. **Reset Detection**: The workflow checks if `main` has new commits that require resetting `develop_auto`
5. **Approval (if reset needed)**: If PRs will be removed, a Slack approval is requested
6. **Prepare Branch**: `develop_auto` is synced with `main` and your PR branch is merged
7. **Deploy**: The `develop_auto` branch is deployed to the testing environment
8. **Notify**: Success/failure is reported back to the PR

## Slack Approval Process

When `main` has new commits since the last deployment, `develop_auto` must be reset. This removes any previously deployed PRs that haven't been merged to `main` yet.

### When Approval is Required

- `develop_auto` exists and contains previous PR changes
- `main` has new commits requiring a reset
- The reset would remove one or more open PRs from `develop_auto`

### When Approval is NOT Required

- `develop_auto` doesn't exist (first deployment)
- `main` has no new commits (incremental merge)
- No open PRs will be removed

### Approval Message

The Slack message includes:
- List of PRs that will be removed (PR number, branch, author)
- The PR that triggered the deployment
- Link to the workflow run
- Approve/Reject buttons

### Timeout

If no response is received within **10 minutes**, the approval is treated as rejected and the deployment is cancelled.

## Required Configuration

### GitHub Secrets

The following secrets must be configured in your repository settings:

- **`SLACK_APP_TOKEN`** - Slack App-Level Token for Socket Mode (starts with `xapp-`)
  - Required for the approval action to receive button click events
  - Create at: https://api.slack.com/apps → Your App → Basic Information → App-Level Tokens
  - Required scope: `connections:write`

- **`SLACK_BOT_TOKEN`** - Slack Bot User OAuth Token (starts with `xoxb-`)
  - Required for posting messages to Slack
  - Create at: https://api.slack.com/apps → Your App → OAuth & Permissions
  - Required scopes: `chat:write`, `channels:read`, `groups:read`

- **`SLACK_SIGNING_SECRET`** - Slack App Signing Secret
  - Required for validating Slack requests
  - Found at: https://api.slack.com/apps → Your App → Basic Information → App Credentials

- **`SLACK_CHANNEL_ID`** - Slack Channel ID where approval requests are sent
  - Example: `C01234ABCDE`
  - Find by right-clicking channel → View channel details → Copy ID (at bottom)
  - Can also be stored as a repository variable instead of secret

### GitHub Variables

- **`SLACK_APPROVERS`** - Comma-separated list of Slack member IDs who can approve resets
  - Example: `U01234ABCDE,U56789FGHIJ`
  - Find member ID: Click user profile in Slack → More → Copy member ID

### Slack App Configuration

Your Slack app must have:

1. **Socket Mode enabled**
   - Settings → Socket Mode → Enable

2. **Interactivity enabled**
   - Settings → Interactivity & Shortcuts → Enable

3. **Bot Token Scopes** (OAuth & Permissions):
   - `chat:write`
   - `channels:read`
   - `groups:read`

4. **App-Level Token** (Basic Information):
   - Scope: `connections:write`

5. **Install to Workspace**
   - OAuth & Permissions → Install to Workspace
   - Invite bot to your approval channel: `/invite @YourBotName`

## Usage

### Trigger a Deployment

Comment on any pull request:

```
develop deploy
```

The command must be on its own line to trigger the workflow.

### Re-trigger After Conflict

If a merge conflict occurs, the workflow will:
1. Create a conflict resolution branch and PR
2. Comment on your PR with instructions

To re-trigger after resolving:
1. Merge the conflict resolution PR
2. Comment `develop deploy` again on your original PR

### Check Deployment Status

- The workflow posts comments to your PR at each stage
- Click the workflow run link in comments to see detailed logs
- Deployment status is also visible in the PR's "Checks" tab

## Concurrency

The workflow uses a concurrency group (`deploy-develop`) to ensure:
- Only one deployment runs at a time
- Multiple requests are queued (not cancelled)
- This prevents race conditions on the `develop_auto` branch

## Troubleshooting

### "User does not have write access"

Only users with `write`, `admin`, or `maintain` permissions can trigger deployments.

### "Fork PRs are not supported"

Create a branch on the main repository instead of forking.

### "Reset was rejected or timed out"

The Slack approval was not granted within 10 minutes. You can:
- Re-trigger by commenting `develop deploy` again
- Wait for conflicting PRs to be merged to `main`
- Contact a team member to approve the reset

### Merge Conflicts

The workflow automatically creates a conflict resolution PR. Follow the instructions in the PR comment to resolve.

## Examples

### Successful Deployment (No Reset)

```
🚀 Deploy to develop triggered
Preparing develop_auto branch...

✅ Successfully deployed to develop environment!
Branch develop_auto was synced from main, your PR branch was merged in,
and the result was deployed to testing.
```

### Successful Deployment (After Reset Approval)

```
🚀 Deploy to develop triggered
Preparing develop_auto branch...

[Slack approval requested and granted]

✅ Successfully deployed to develop environment!

⚠️ Note: develop_auto was reset to main (new commits detected)

The following PRs were previously deployed but have been cleared:
- PR #100 (@alice)
- PR #101 (@bob)

If they still need testing in develop, they should re-run develop deploy.
```

### Deployment Cancelled (Approval Rejected)

```
🚫 Deploy to develop cancelled

The reset of develop_auto was rejected or timed out during the approval process.

The develop_auto branch was not modified. If you still want to deploy:
1. Wait for the conflicting PRs to be resolved or merged
2. Re-trigger the deployment by commenting develop deploy
```

## Feature Specifications

For detailed feature specifications and test scenarios, see:
- `tooling/deploy-develop.feature` - Complete Gherkin specifications
