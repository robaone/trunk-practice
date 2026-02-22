# Slack Integration Setup Guide

This guide walks you through setting up Slack notifications for the deploy-develop workflow.

## Step 1: Create a Slack App

1. Go to https://api.slack.com/apps
2. Click "Create New App"
3. Choose "From scratch"
4. Name: `Deploy Develop Bot` (or your preferred name)
5. Choose your workspace
6. Click "Create App"

## Step 2: Configure Bot Permissions

1. In your app settings, go to **OAuth & Permissions**
2. Scroll down to **Scopes**
3. Under **Bot Token Scopes**, add:
   - `chat:write` - Send messages as the bot
   - `chat:write.public` - Post to public channels without joining
4. Scroll up and click **Install to Workspace**
5. Review permissions and click **Allow**
6. Copy the **Bot User OAuth Token** (starts with `xoxb-`)
   - Save this securely - you'll need it for GitHub

## Step 3: Add Bot to Channel (Optional)

If posting to a private channel:
1. Open the channel in Slack
2. Click the channel name at the top
3. Go to **Integrations** tab
4. Click **Add apps**
5. Find and add your `Deploy Develop Bot`

For public channels, the bot can post without being added (due to `chat:write.public` scope).

## Step 4: Get Channel ID

1. Open the Slack channel where you want notifications
2. Click the channel name at the top
3. Scroll down in the modal that appears
4. Copy the **Channel ID** (e.g., `C01234ABCDE`)
   - It's at the bottom of the "About" section

## Step 5: Configure GitHub Repository

### Add Secret (Bot Token)

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `SLACK_BOT_TOKEN`
5. Value: Paste your bot token (starts with `xoxb-`)
6. Click **Add secret**

### Add Variable (Channel ID)

1. In the same settings area, click the **Variables** tab
2. Click **New repository variable**
3. Name: `SLACK_CHANNEL_ID`
4. Value: Paste your channel ID (e.g., `C01234ABCDE`)
5. Click **Add variable**

## Step 6: Test the Integration

### Option 1: Trigger a Real Deploy

1. Create or use an existing PR
2. Deploy it with `develop deploy` comment
3. Merge something to main
4. Deploy another PR (this will trigger a reset and notification)

### Option 2: Test the Script Directly

Create a test script:

```bash
#!/bin/bash

export SLACK_BOT_TOKEN="xoxb-your-token-here"
export SLACK_CHANNEL_ID="C01234ABCDE"

# Test with sample data
.github/scripts/notify-slack-removed-prs.sh \
  "123|feature/test|alice|Test Feature" \
  "456" \
  "feature/new-thing" \
  "bob" \
  "New Thing" \
  "https://github.com/your-org/your-repo/actions/runs/123" \
  "https://github.com/your-org/your-repo"
```

Run it:
```bash
chmod +x test-slack.sh
./test-slack.sh
```

Check your Slack channel for the test message.

## Verification Checklist

- [ ] Slack app created with correct scopes
- [ ] Bot token copied (starts with `xoxb-`)
- [ ] Channel ID copied (starts with `C` or `G`)
- [ ] `SLACK_BOT_TOKEN` secret added to GitHub
- [ ] `SLACK_CHANNEL_ID` variable added to GitHub
- [ ] Bot added to channel (if private)
- [ ] Test message received in Slack

## Troubleshooting

### "⚠️ Slack configuration missing"

**Cause**: `SLACK_BOT_TOKEN` or `SLACK_CHANNEL_ID` not set
**Fix**: Verify both are configured in GitHub repository settings

### "Slack notification failed: channel_not_found"

**Cause**: Bot doesn't have access to the channel
**Fix**: 
- For private channels: Add the bot to the channel
- For public channels: Verify `chat:write.public` scope is granted
- Verify the channel ID is correct

### "Slack notification failed: invalid_auth"

**Cause**: Bot token is invalid or expired
**Fix**: 
- Verify the token starts with `xoxb-`
- Regenerate the token in Slack app settings if needed
- Update the GitHub secret

### "Slack notification failed: missing_scope"

**Cause**: Bot doesn't have required permissions
**Fix**: 
- Add `chat:write` and `chat:write.public` scopes
- Reinstall the app to workspace
- Update the bot token in GitHub (reinstalling generates a new token)

### No Slack notification sent, but workflow succeeds

**Cause**: This is expected behavior when:
- No reset occurred (`was_reset=false`)
- Reset occurred but no open PRs were removed
- Slack step failed silently (check logs)

**Check**: Look in workflow logs for:
```
📤 Sending Slack notification to channel...
✅ Slack notification sent successfully
```

Or error messages like:
```
⚠️ Slack notification failed: [error]
```

### "jq: command not found"

**Cause**: GitHub Actions runner should have `jq` installed by default
**Fix**: This shouldn't happen, but if it does, the script will still attempt to send (may show less detailed error logging)

## Advanced: Testing with curl

Test the bot token directly:

```bash
curl -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer xoxb-your-token-here" \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "C01234ABCDE",
    "text": "Test message from Deploy Develop Bot"
  }'
```

Expected response:
```json
{
  "ok": true,
  "channel": "C01234ABCDE",
  "ts": "1234567890.123456",
  "message": { ... }
}
```

Error response:
```json
{
  "ok": false,
  "error": "channel_not_found"
}
```

## Security Notes

- **Never commit** the bot token to the repository
- Bot token gives access to post messages as the app
- Use GitHub secrets (encrypted) for the token
- Channel ID is not sensitive and can use variables
- Rotate the bot token periodically for security
- If token is compromised, regenerate in Slack app settings

## Optional: Customize the Message

Edit `.github/scripts/notify-slack-removed-prs.sh` to customize:

- **Message text**: Modify the `blocks` array (lines 49-102)
- **Button text**: Change `"View Workflow Run"` (line 95)
- **Emoji**: Change `⚠️` in the header (line 54)
- **Colors**: Add a `color` field to the attachment
- **Additional fields**: Add more blocks to the array

Refer to [Slack Block Kit Builder](https://app.slack.com/block-kit-builder) for designing custom layouts.

## Need Help?

Common issues:
1. **Bot tokens vs User tokens**: Make sure you're using the Bot User OAuth Token (starts with `xoxb-`), not a User OAuth Token or other token type
2. **Workspace vs Channel ID**: The channel ID is per-channel, not per-workspace
3. **Public vs Private**: Private channels require the bot to be explicitly added

Still stuck? Check:
- Slack API documentation: https://api.slack.com/
- GitHub Actions logs for detailed error messages
- Slack app's **OAuth & Permissions** page for token status
