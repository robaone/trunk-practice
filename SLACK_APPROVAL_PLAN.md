# Plan: Slack Interactive Approval

I will implement an interactive Slack approval step that pauses the production deployment until a user clicks "Approve" or "Reject" directly in Slack.

## Proposed Changes

### 1. Add Approval Job to [.github/workflows/trunk.yml](.github/workflows/trunk.yml)

    I will add a new `request-production-approval` job that runs after tests pass but before the production deployment starts. This job will use the `TigerWest/slack-approval` action.

### 2. Update Production Deployment Dependency

I will update the `deploy-to-production` job to depend on the `request-production-approval` job, ensuring it only starts after approval is received via Slack.

## Implementation Details

### Workflow Modification

I will insert the following job into the `jobs` section:

```yaml
  request-production-approval:
    name: Request Production Approval
    needs: [initialize, unit-tests, feature-tests]
    runs-on: ubuntu-latest
    timeout-minutes: 5
    # Only run for full releases (not pre-releases)
    if: github.event_name == 'release' && github.event.release.prerelease == false && fromJson(needs.initialize.outputs.matrix).include[0] != null
    steps:
      - name: Slack Approval
        uses: TigerWest/slack-approval@v1
        env:
          SLACK_APP_TOKEN: ${{ secrets.SLACK_APP_TOKEN }}
          SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
          SLACK_SIGNING_SECRET: ${{ secrets.SLACK_SIGNING_SECRET }}
          SLACK_CHANNEL_ID: ${{ secrets.SLACK_CHANNEL_ID }}
        with:
          approvers: ${{ vars.SLACK_MEMBER_ID }}

      - name: Handle Timeout/Cancellation
        if: cancelled() || failure()
        uses: slackapi/slack-github-action@v1.24.0
        with:
          payload: |
            {
              "text": "🚫 Deployment approval request timed out or was cancelled. Tag: ${{ github.event.release.tag_name }}"
            }
        env:
          SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
```

### Update Production Job

```yaml
  deploy-to-production:
    # ...
    needs: [initialize, unit-tests, feature-tests, request-production-approval]
    # ...
```

## Necessary Setup (Action Required)

To make this work, you will need to:

1.  **Create a Slack App** with `app_mentions:read`, `channels:join`, `chat:write`, and `users:read` permissions.
2.  **Enable Interactivity and Socket Mode** in your Slack App settings.
3.  **Add the following secrets** to your GitHub repository:
    *   `SLACK_BOT_TOKEN` (starts with `xoxb-`)
    *   `SLACK_APP_TOKEN` (starts with `xapp-`)
    *   `SLACK_SIGNING_SECRET` (Found in "Basic Information" under "App Credentials")
    *   `SLACK_CHANNEL_ID` (The ID of the channel where the message should be sent)
4.  **Add the following variable** (or secret) to your GitHub repository:
    *   `SLACK_MEMBER_ID` (The Slack user ID of the person(s) who can approve, comma-separated)
