#!/bin/bash
# Send Slack notification about removed PRs when develop_auto is reset

set +e  # Don't exit on error (silent failure)

# Validate configuration
if [ -z "$SLACK_BOT_TOKEN" ] || [ -z "$SLACK_CHANNEL_ID" ]; then
  echo "⚠️ Slack configuration missing (SLACK_BOT_TOKEN or SLACK_CHANNEL_ID), skipping notification"
  exit 0
fi

# Parse input parameters
REMOVED_PR_DATA="$1"
TRIGGERING_PR="$2"
TRIGGERING_BRANCH="$3"
TRIGGERING_AUTHOR="$4"
TRIGGERING_TITLE="$5"
WORKFLOW_URL="$6"
REPO_URL="$7"

if [ -z "$REMOVED_PR_DATA" ]; then
  echo "No removed PRs to notify about"
  exit 0
fi

echo "📤 Building Slack notification..."

# Build removed PRs text in Slack mrkdwn format
REMOVED_TEXT=""
while IFS='|' read -r pr_num branch author title; do
  [ -z "$pr_num" ] && continue
  PR_URL="$REPO_URL/pull/$pr_num"
  REMOVED_TEXT+="• <$PR_URL|PR #$pr_num> - $branch ($author)\\n"
done <<< "$REMOVED_PR_DATA"

# Remove trailing \n
REMOVED_TEXT="${REMOVED_TEXT%\\n}"

# Build Slack message payload using Block Kit (jq for correct JSON escaping)
jq -n \
  --arg channel "$SLACK_CHANNEL_ID" \
  --arg removed_text "$REMOVED_TEXT" \
  --arg repo_url "$REPO_URL" \
  --arg triggering_pr "$TRIGGERING_PR" \
  --arg triggering_branch "$TRIGGERING_BRANCH" \
  --arg triggering_author "$TRIGGERING_AUTHOR" \
  --arg workflow_url "$WORKFLOW_URL" \
  '{
    channel: $channel,
    text: "Develop Environment Reset - PRs removed from develop_auto",
    blocks: [
      { type: "header", text: { type: "plain_text", text: "⚠️ Develop Environment Reset", emoji: true } },
      { type: "section", text: { type: "mrkdwn", text: "The `develop_auto` branch was reset to `main` due to new merges." } },
      { type: "section", text: { type: "mrkdwn", text: ("*Removed PRs:*\n" + $removed_text) } },
      { type: "section", text: { type: "mrkdwn", text: ("*Triggered by:* <" + $repo_url + "/pull/" + $triggering_pr + "|PR #" + $triggering_pr + "> - " + $triggering_branch + " (" + $triggering_author + ")") } },
      { type: "context", elements: [{ type: "mrkdwn", text: "💡 *Action needed:* If you still need to test in develop, comment `develop deploy` on your PR." }] },
      { type: "actions", elements: [{ type: "button", text: { type: "plain_text", text: "View Workflow Run", emoji: true }, url: $workflow_url }] }
    ]
  }' > /tmp/slack-payload.json

if [ "$SLACK_DEBUG" = "true" ]; then
  echo "Slack payload:"
  cat /tmp/slack-payload.json
fi

# Send to Slack
echo ""
echo "📤 Sending Slack notification to channel $SLACK_CHANNEL_ID..."
RESPONSE=$(curl -s -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d @/tmp/slack-payload.json)

# Validate response
OK=$(echo "$RESPONSE" | jq -r '.ok // false' 2>/dev/null || echo "false")
if [ "$OK" = "true" ]; then
  echo "✅ Slack notification sent successfully"
else
  ERROR=$(echo "$RESPONSE" | jq -r '.error // "unknown error"' 2>/dev/null || echo "unknown error")
  echo "⚠️ Slack notification failed: $ERROR"
  echo "Response: $RESPONSE"
fi

# Clean up
rm -f /tmp/slack-payload.json

# Always exit 0 (silent failure)
exit 0
