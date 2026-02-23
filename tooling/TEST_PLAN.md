# Deploy Develop Workflow - Manual Test Plan

This test plan is derived from `deploy-develop.feature` and provides a checklist for manually testing all scenarios.

## Prerequisites

- [ ] Test repository with deploy-develop workflow enabled
- [ ] At least 3 test user accounts with different permission levels
- [ ] Slack workspace configured with bot token and channel
- [ ] Testing environment configured in repository

---

## 1. Workflow Trigger (5 scenarios)

### ✅ Scenario: Exact command triggers workflow
- [ ] Create open PR
- [ ] Comment exactly "develop deploy"
- [ ] Verify workflow starts

### ✅ Scenario: Similar commands don't trigger
- [ ] Create open PR
- [ ] Comment "please don't develop deploy"
- [ ] Verify workflow does NOT start

### ✅ Scenario: Issue comments don't trigger
- [ ] Create regular issue (not PR)
- [ ] Comment "develop deploy"
- [ ] Verify workflow does NOT start

### ✅ Scenario: Edited comments don't re-trigger
- [ ] Create open PR with existing "develop deploy" comment
- [ ] Edit the comment
- [ ] Verify workflow does NOT trigger again

### ✅ Scenario: Deleted comments don't trigger
- [ ] Create open PR with "develop deploy" comment
- [ ] Delete the comment
- [ ] Verify workflow does NOT trigger

---

## 2. Concurrency Control (2 scenarios)

### ✅ Scenario: Queue concurrent deploys
- [ ] Start deploy on PR #1
- [ ] Immediately trigger deploy on PR #2
- [ ] Verify PR #2 waits for PR #1 to complete
- [ ] Verify PR #2 is not cancelled

### ✅ Scenario: Multiple deploys execute in order
- [ ] Trigger deploy on PR #1
- [ ] Trigger deploy on PR #2
- [ ] Trigger deploy on PR #3
- [ ] Verify execution order: #1 → #2 → #3

---

## 3. Permission Verification (5 scenarios)

### ✅ Scenario: Write permission allows deploy
- [ ] User with "write" access comments "develop deploy"
- [ ] Verify workflow continues without permission error

### ✅ Scenario: Admin permission allows deploy
- [ ] User with "admin" access comments "develop deploy"
- [ ] Verify workflow continues without permission error

### ✅ Scenario: Maintain permission allows deploy
- [ ] User with "maintain" access comments "develop deploy"
- [ ] Verify workflow continues without permission error

### ✅ Scenario: Read permission blocks deploy
- [ ] User with "read" access comments "develop deploy"
- [ ] Verify workflow fails with permission error
- [ ] Verify error message shows actual permission level

### ✅ Scenario: No permission blocks deploy
- [ ] User with "none" permission comments "develop deploy"
- [ ] Verify workflow fails with permission error

---

## 4. Fork Pull Request Blocking (3 scenarios)

### ✅ Scenario: Fork PR blocked
- [ ] Create PR from forked repository
- [ ] User with write access comments "develop deploy"
- [ ] Verify workflow fails
- [ ] Verify comment explains fork PRs not supported
- [ ] Verify comment includes workflow URL
- [ ] Verify comment suggests same-repo branch

### ✅ Scenario: Same-repo PR allowed
- [ ] Create PR from branch in same repo
- [ ] User with write access comments "develop deploy"
- [ ] Verify workflow continues
- [ ] Verify no fork warning

### ✅ Scenario: Deleted head repo handled
- [ ] Create PR where head repo has been deleted
- [ ] User with write access comments "develop deploy"
- [ ] Verify workflow fails gracefully

---

## 5. Workflow Started Notification (1 scenario)

### ✅ Scenario: Started comment posted
- [ ] Valid same-repo PR
- [ ] User with write access comments "develop deploy"
- [ ] Verify comment posted: "Deploy to develop triggered"
- [ ] Verify comment mentions preparing develop_auto
- [ ] Verify comment includes workflow URL

---

## 6. Develop Auto Reset Approval (10 scenarios)

### ✅ Scenario: Approval request sent
- [ ] develop_auto exists with PR changes
- [ ] main has new commits
- [ ] Trigger deploy
- [ ] Verify Slack approval request sent
- [ ] Verify message explains reset
- [ ] Verify message lists PRs to be removed
- [ ] Verify approve/reject buttons present

### ✅ Scenario: Approval approved
- [ ] Get to approval request state
- [ ] Click approve button in Slack
- [ ] Verify workflow continues
- [ ] Verify develop_auto reset to main
- [ ] Verify PR branch merged
- [ ] Verify confirmation comment on PR

### ✅ Scenario: Approval rejected
- [ ] Get to approval request state
- [ ] Click reject button in Slack
- [ ] Verify workflow cancelled
- [ ] Verify develop_auto NOT reset
- [ ] Verify PR branch NOT merged
- [ ] Verify cancellation comment on PR
- [ ] Verify workflow exits with failure

### ✅ Scenario: Approval timeout
- [ ] Get to approval request state
- [ ] Wait for timeout period
- [ ] Verify treated as rejection
- [ ] Verify timeout comment posted to PR

### ✅ Scenario: Cancellation comment format
- [ ] Trigger rejection (user "alice")
- [ ] Verify comment indicates cancellation
- [ ] Verify mentions team member
- [ ] Verify explains develop_auto not modified
- [ ] Verify includes workflow URL
- [ ] Verify includes cancelled emoji

### ✅ Scenario: Approval message includes context
- [ ] develop_auto contains PR #100, #101
- [ ] main has new commits
- [ ] PR #102 triggers deploy
- [ ] Verify Slack message lists removed PRs
- [ ] Verify shows triggering PR
- [ ] Verify includes PR links
- [ ] Verify includes workflow link
- [ ] Verify shows requester

### ✅ Scenario: No approval when develop_auto doesn't exist
- [ ] Delete develop_auto branch
- [ ] Trigger deploy
- [ ] Verify no approval request
- [ ] Verify develop_auto created from main
- [ ] Verify workflow proceeds immediately

### ✅ Scenario: No approval when no reset needed
- [ ] develop_auto exists and synced with main
- [ ] Trigger deploy
- [ ] Verify no approval request
- [ ] Verify main merged normally
- [ ] Verify workflow proceeds immediately

### ✅ Scenario: Multiple approval responses
- [ ] Send approval request
- [ ] Have multiple team members respond
- [ ] Verify first response used
- [ ] Verify subsequent responses ignored
- [ ] Verify only one action taken

### ✅ Scenario: Interactive components format
- [ ] Check approval request message
- [ ] Verify uses Block Kit format
- [ ] Verify has actions block
- [ ] Verify "Approve" button present
- [ ] Verify "Reject" button present
- [ ] Verify unique action IDs
- [ ] Verify workflow context in values

---

## 7. Develop Auto Branch Preparation (5 scenarios)

### ✅ Scenario: Create from main when doesn't exist
- [ ] Delete develop_auto remotely
- [ ] Trigger deploy
- [ ] Verify new branch created from main
- [ ] Verify no merge attempted
- [ ] Verify no approval required

### ✅ Scenario: Sync with main when exists
- [ ] develop_auto exists
- [ ] No reset required
- [ ] Trigger deploy
- [ ] Verify develop_auto checked out
- [ ] Verify main merged in
- [ ] Verify commit message: "chore: sync main into develop_auto [auto]"

### ✅ Scenario: Reset after approval
- [ ] develop_auto exists
- [ ] main has new commits
- [ ] Reset approved
- [ ] Verify develop_auto reset to main
- [ ] Verify previous PR changes discarded
- [ ] Verify no merge from main

### ✅ Scenario: Fast-forward merge
- [ ] develop_auto behind main, no conflicts
- [ ] No reset required
- [ ] Trigger deploy
- [ ] Verify clean merge

### ✅ Scenario: Three-way merge
- [ ] develop_auto diverged from main
- [ ] No conflicts
- [ ] No reset required
- [ ] Trigger deploy
- [ ] Verify three-way merge
- [ ] Verify merge commit created

---

## 8. Main to Develop Auto Merge Conflicts (3 scenarios)

### ✅ Scenario: Conflict when syncing main
- [ ] develop_auto has conflicting changes with main
- [ ] Trigger deploy
- [ ] Verify merge fails
- [ ] Verify conflicting files identified
- [ ] Verify merge aborted
- [ ] Verify conflict resolution branch created
- [ ] Verify conflict resolution PR created
- [ ] Verify workflow outputs conflict details
- [ ] Verify success=false
- [ ] Verify conflict_stage=main_to_develop_auto

### ✅ Scenario: Comment for main conflict
- [ ] Conflict detected (files: "src/app.js, config.yaml")
- [ ] Verify comment posted on PR
- [ ] Verify indicates merge conflict with main
- [ ] Verify lists conflicting files
- [ ] Verify instructs to resolve in conflict PR
- [ ] Verify mentions re-triggering with "develop deploy"
- [ ] Verify includes workflow URL

### ✅ Scenario: Workflow fails after conflict
- [ ] Conflict detected
- [ ] Comment posted
- [ ] Verify workflow exits with code 1
- [ ] Verify prepare job marked failed
- [ ] Verify subsequent jobs don't run

---

## 9. PR Branch Merge into Develop Auto (3 scenarios)

### ✅ Scenario: Clean merge
- [ ] develop_auto synced with main
- [ ] PR branch has no conflicts
- [ ] Verify clean merge
- [ ] Verify commit message references PR branch
- [ ] Verify commit message includes "[auto]"

### ✅ Scenario: Fast-forward merge
- [ ] develop_auto is ancestor of PR branch
- [ ] Verify fast-forward merge
- [ ] Verify success

### ✅ Scenario: Three-way merge
- [ ] Both branches have unique commits
- [ ] No conflicts
- [ ] Verify three-way merge
- [ ] Verify merge commit created

---

## 10. PR Branch to Develop Auto Merge Conflicts (3 scenarios)

### ✅ Scenario: Conflict merging PR branch
- [ ] develop_auto synced with main
- [ ] PR branch has conflicts
- [ ] Verify merge fails
- [ ] Verify conflicting files identified
- [ ] Verify conflict resolution branch created
- [ ] Verify conflict resolution PR created
- [ ] Verify merge aborted
- [ ] Verify workflow outputs conflict details
- [ ] Verify success=false
- [ ] Verify conflict_stage=pr_branch_to_develop_auto

### ✅ Scenario: Comment for PR conflict
- [ ] PR branch "feature/new-api" conflicts
- [ ] Conflicting file: "api/routes.js"
- [ ] Verify comment posted
- [ ] Verify indicates PR branch conflict
- [ ] Verify lists conflicting files
- [ ] Verify instructs to resolve in conflict PR
- [ ] Verify mentions pushing changes and re-triggering
- [ ] Verify includes workflow URL

### ✅ Scenario: Workflow fails after PR conflict
- [ ] PR conflict detected
- [ ] Comment posted
- [ ] Verify workflow exits with code 1
- [ ] Verify prepare job marked failed
- [ ] Verify deploy job doesn't run

---

## 11. Push Develop Auto Branch (3 scenarios)

### ✅ Scenario: Force-with-lease after successful merges
- [ ] main merged successfully
- [ ] PR branch merged successfully
- [ ] Verify develop_auto pushed to origin
- [ ] Verify --force-with-lease used
- [ ] Verify prepare job outputs success=true

### ✅ Scenario: Force-with-lease prevents overwrites
- [ ] Prepare develop_auto locally
- [ ] Another process pushes to remote develop_auto
- [ ] Verify push fails
- [ ] Verify workflow fails
- [ ] Verify branch not overwritten

### ✅ Scenario: Push after creating new branch
- [ ] develop_auto created from main
- [ ] PR branch merged
- [ ] Verify new branch pushed successfully

---

## 12. Deploy Job Execution (5 scenarios)

### ✅ Scenario: Deploy waits for prepare
- [ ] Prepare job running
- [ ] Prepare completes successfully
- [ ] Verify deploy job starts
- [ ] Verify runs in testing environment

### ✅ Scenario: Deploy checks out develop_auto
- [ ] Prepare completed
- [ ] Deploy job starts
- [ ] Verify develop_auto branch checked out
- [ ] Verify uses develop_auto ref

### ✅ Scenario: Deploy with package.json and script
- [ ] develop_auto checked out
- [ ] package.json exists with "deploy:testing" script
- [ ] Verify npm install executed
- [ ] Verify npm run deploy:testing executed

### ✅ Scenario: Deploy with package.json but no script
- [ ] develop_auto checked out
- [ ] package.json exists without "deploy:testing"
- [ ] Verify npm install executed
- [ ] Verify simulated deploy message displayed
- [ ] Verify job completes successfully

### ✅ Scenario: Deploy without package.json
- [ ] develop_auto checked out
- [ ] No package.json exists
- [ ] Verify npm install skipped
- [ ] Verify simulated deploy message displayed
- [ ] Verify job completes successfully

---

## 13. Deploy Job Failure Scenarios (3 scenarios)

### ✅ Scenario: npm install fails
- [ ] package.json exists
- [ ] npm install returns non-zero exit
- [ ] Verify deploy job fails
- [ ] Verify subsequent steps don't run

### ✅ Scenario: deploy:testing script fails
- [ ] npm install succeeded
- [ ] deploy:testing script returns non-zero exit
- [ ] Verify deploy job fails
- [ ] Verify job marked as failed

### ✅ Scenario: Checkout fails
- [ ] Prepare completed
- [ ] Checkout action fails
- [ ] Verify deploy job fails
- [ ] Verify subsequent steps don't run

---

## 14. Deployment Success Notification (2 scenarios)

### ✅ Scenario: Success comment posted
- [ ] Prepare succeeded
- [ ] Deploy succeeded
- [ ] Verify success comment on PR
- [ ] Verify indicates successful deployment
- [ ] Verify explains process (synced, merged, deployed)
- [ ] Verify includes workflow URL
- [ ] Verify includes success emoji

### ✅ Scenario: Notify only if prepare succeeded
- [ ] Prepare failed
- [ ] Verify notify job skipped
- [ ] Verify no notification comment posted

---

## 15. Deployment Failure Notification (2 scenarios)

### ✅ Scenario: Failure comment posted
- [ ] Prepare succeeded
- [ ] Deploy failed
- [ ] Verify failure comment on PR
- [ ] Verify indicates deployment failed
- [ ] Verify instructs to check workflow logs
- [ ] Verify includes workflow URL
- [ ] Verify includes failure emoji

### ✅ Scenario: Notify has PR context
- [ ] Prepare succeeded
- [ ] Deploy failed
- [ ] Verify notify job has pull-requests write permission
- [ ] Verify has issues write permission
- [ ] Verify comment posted to correct PR number

---

## 16. Deployment Cancelled Notification (2 scenarios)

### ✅ Scenario: Cancelled comment posted
- [ ] Prepare succeeded
- [ ] Deploy cancelled by user
- [ ] Verify cancelled comment on PR
- [ ] Verify indicates deployment cancelled
- [ ] Verify includes workflow URL
- [ ] Verify includes warning emoji

### ✅ Scenario: Cancel during npm install
- [ ] Deploy job running
- [ ] npm install in progress
- [ ] User cancels workflow
- [ ] Verify deploy job stops
- [ ] Verify notify job runs
- [ ] Verify cancelled notification posted

---

## 17. Notify Job Execution Conditions (5 scenarios)

### ✅ Scenario: Notify on success + success
- [ ] prepare: success, deploy: success
- [ ] Verify notify runs
- [ ] Verify success comment posted

### ✅ Scenario: Notify on success + failure
- [ ] prepare: success, deploy: failure
- [ ] Verify notify runs
- [ ] Verify failure comment posted

### ✅ Scenario: Notify on success + cancelled
- [ ] prepare: success, deploy: cancelled
- [ ] Verify notify runs
- [ ] Verify cancelled comment posted

### ✅ Scenario: No notify on prepare failure
- [ ] prepare: failure
- [ ] Verify notify skipped
- [ ] Verify no notification posted

### ✅ Scenario: No notify on prepare cancelled
- [ ] prepare: cancelled
- [ ] Verify notify skipped

---

## 18. Complete Workflow Success Paths (2 scenarios)

### ✅ Scenario: Success with new develop_auto
- [ ] PR #123 from "feature/add-login" (same repo)
- [ ] develop_auto doesn't exist
- [ ] User with write access comments "develop deploy"
- [ ] Verify permission passes
- [ ] Verify fork check passes
- [ ] Verify "deployment started" comment
- [ ] Verify develop_auto created from main
- [ ] Verify PR branch merged
- [ ] Verify develop_auto pushed
- [ ] Verify deployed to testing
- [ ] Verify "deployment succeeded" comment
- [ ] Verify workflow success status

### ✅ Scenario: Success with existing develop_auto and approval
- [ ] PR #124 from "feature/new-api" (same repo)
- [ ] develop_auto exists, 3 commits behind main
- [ ] develop_auto contains previous PR changes
- [ ] User with admin comments "develop deploy"
- [ ] Verify permission passes
- [ ] Verify reset detected
- [ ] Verify approval request to Slack
- [ ] Team member approves
- [ ] Verify develop_auto reset to main
- [ ] Verify PR branch merged
- [ ] Verify force-with-lease push
- [ ] Verify deployed
- [ ] Verify success comment

---

## 19. Complete Workflow Failure Paths (6 scenarios)

### ✅ Scenario: Insufficient permissions
- [ ] PR #125 from "feature/update"
- [ ] User with read-only comments "develop deploy"
- [ ] Verify permission check fails
- [ ] Verify workflow exits with failure
- [ ] Verify no comments posted
- [ ] Verify develop_auto not modified

### ✅ Scenario: Fork PR
- [ ] PR #126 from forked repo
- [ ] User with write access comments "develop deploy"
- [ ] Verify fork check fails
- [ ] Verify error comment posted
- [ ] Verify workflow exits with failure
- [ ] Verify develop_auto not modified

### ✅ Scenario: Rejected reset approval
- [ ] PR #127 from "feature/new-feature"
- [ ] develop_auto needs reset
- [ ] User with write access comments "develop deploy"
- [ ] Verify approval request sent
- [ ] Team member rejects
- [ ] Verify cancellation comment posted
- [ ] Verify workflow exits with failure
- [ ] Verify develop_auto not reset
- [ ] Verify PR branch not merged

### ✅ Scenario: Approval timeout
- [ ] PR #128 from "feature/update"
- [ ] develop_auto needs reset
- [ ] User with write access comments "develop deploy"
- [ ] Verify approval request sent
- [ ] No response within timeout
- [ ] Verify timeout cancellation comment
- [ ] Verify workflow exits with failure
- [ ] Verify develop_auto not modified

### ✅ Scenario: Main merge conflict
- [ ] PR #129 from "feature/refactor"
- [ ] develop_auto conflicts with main in "config.yaml"
- [ ] User with write access comments "develop deploy"
- [ ] Verify main merge fails
- [ ] Verify conflicting files identified
- [ ] Verify conflict resolution branch/PR created
- [ ] Verify conflict comment with file list and PR link
- [ ] Verify workflow exits with failure
- [ ] Verify develop_auto not pushed

### ✅ Scenario: PR branch merge conflict
- [ ] PR #130 from "feature/ui-update"
- [ ] develop_auto synced with main
- [ ] PR conflicts with develop_auto in "styles.css"
- [ ] User with write access comments "develop deploy"
- [ ] Verify PR merge fails
- [ ] Verify conflicting files identified
- [ ] Verify conflict resolution branch/PR created
- [ ] Verify conflict comment with conflict PR link
- [ ] Verify workflow exits with failure
- [ ] Verify develop_auto not pushed

---

## 20. Additional Features

For the remaining features (Order of Operations, Concurrency and Race Conditions, Git Configuration, Error Messages, Environment Protection, Develop Auto Reset, Notification for Removed PRs, Slack Integration, Workflow Outputs, Permissions, Idempotency), follow similar testing patterns as above.

---

## Testing Progress

- **Total Features:** 26
- **Total Scenarios:** ~150+
- **Completed:** 0
- **Failed:** 0
- **Blocked:** 0

## Notes

Use this section to document any deviations from expected behavior, bugs found, or areas that need clarification.
