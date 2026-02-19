# Deploy Develop Workflow - Gherkin Specifications

This document describes the expected behavior of the Deploy Develop workflow using Gherkin syntax.

---

## Feature: Workflow Trigger

```gherkin
Feature: Deploy Develop Workflow Trigger
  The workflow should respond to issue comments on pull requests with the exact command "develop deploy"

  Scenario: Workflow triggers on exact command in PR comment
    Given an open pull request exists
    When a user comments "develop deploy" on the pull request
    Then the workflow should be triggered
    And the prepare job should start

  Scenario: Workflow does not trigger on similar but different commands
    Given an open pull request exists
    When a user comments "please don't develop deploy" on the pull request
    Then the workflow should not be triggered

  Scenario: Workflow does not trigger on issue comments (non-PR)
    Given a GitHub issue exists (not a pull request)
    When a user comments "develop deploy" on the issue
    Then the workflow should not be triggered

  Scenario: Workflow does not trigger on edited comments
    Given an open pull request exists
    And a comment "develop deploy" already exists
    When the comment is edited
    Then the workflow should not be triggered again

  Scenario: Workflow does not trigger on deleted comments
    Given an open pull request exists
    And a comment "develop deploy" exists
    When the comment is deleted
    Then the workflow should not be triggered
```

---

## Feature: Concurrency Control

```gherkin
Feature: Deploy Develop Concurrency Control
  The workflow should serialize runs to prevent race conditions on the develop_auto branch

  Scenario: Queue concurrent deploy requests
    Given a deploy develop workflow is already running
    When another user comments "develop deploy" on a different pull request
    Then the second workflow should be queued
    And the second workflow should wait for the first to complete
    And the second workflow should not be cancelled

  Scenario: Multiple deploy requests queue in order
    Given a deploy develop workflow is running for PR #1
    When a deploy is requested for PR #2
    And then a deploy is requested for PR #3
    Then the workflows should execute in order: PR #1, PR #2, PR #3
    And each workflow should complete before the next starts
```

---

## Feature: Permission Verification

```gherkin
Feature: Permission Verification
  Only users with write access should be able to trigger deployments

  Scenario: User with write permission triggers deploy
    Given an open pull request exists
    And the commenting user has "write" permission
    When the user comments "develop deploy"
    Then the workflow should continue
    And no permission error should be raised

  Scenario: User with admin permission triggers deploy
    Given an open pull request exists
    And the commenting user has "admin" permission
    When the user comments "develop deploy"
    Then the workflow should continue
    And no permission error should be raised

  Scenario: User with maintain permission triggers deploy
    Given an open pull request exists
    And the commenting user has "maintain" permission
    When the user comments "develop deploy"
    Then the workflow should continue
    And no permission error should be raised

  Scenario: User with read permission cannot trigger deploy
    Given an open pull request exists
    And the commenting user has "read" permission
    When the user comments "develop deploy"
    Then the workflow should fail
    And an error message should indicate insufficient permissions
    And the error should include the user's actual permission level

  Scenario: User with no permission cannot trigger deploy
    Given an open pull request exists
    And the commenting user has "none" permission
    When the user comments "develop deploy"
    Then the workflow should fail
    And an error message should indicate insufficient permissions

  Scenario: Permission check API failure
    Given an open pull request exists
    When the user comments "develop deploy"
    And the GitHub API permission check fails
    Then the workflow should fail
    And an error message should explain the API failure
```

---

## Feature: Fork Pull Request Blocking

```gherkin
Feature: Fork Pull Request Blocking
  Fork pull requests should be blocked from deploying to develop

  Scenario: Block deploy from fork PR
    Given a pull request from a forked repository
    When a user with write access comments "develop deploy"
    Then the workflow should fail
    And a comment should be posted explaining fork PRs are not supported
    And the comment should include the workflow run URL
    And the comment should suggest opening a PR from a branch on the main repo

  Scenario: Allow deploy from same-repo PR
    Given a pull request from a branch in the same repository
    When a user with write access comments "develop deploy"
    Then the workflow should continue
    And no fork warning should be posted

  Scenario: Fork check with null head repo
    Given a pull request where the head repo has been deleted
    When a user with write access comments "develop deploy"
    Then the workflow should fail gracefully
    And appropriate error handling should occur
```

---

## Feature: Workflow Started Notification

```gherkin
Feature: Workflow Started Notification
  Users should be notified when the deployment workflow begins

  Scenario: Post started comment after permission checks pass
    Given an open pull request from the same repository
    And the commenting user has write access
    When the user comments "develop deploy"
    And permission checks pass
    And fork checks pass
    Then a comment should be posted indicating deployment has started
    And the comment should include "Deploy to develop triggered"
    And the comment should mention preparing the develop_auto branch
    And the comment should include the workflow run URL
```

---

## Feature: Develop Auto Reset Approval Workflow

```gherkin
Feature: Develop Auto Reset Approval Workflow
  Before resetting develop_auto, the workflow should request approval via Slack

  Background:
    Given all permission and fork checks have passed
    And the repository has been checked out with full history
    And the workflow detects develop_auto needs to be reset

  Scenario: Send approval request to Slack before reset
    Given develop_auto exists and contains previous PR changes
    And main has new commits requiring develop_auto reset
    When the prepare step determines a reset is needed
    Then an approval request message should be sent to Slack
    And the message should explain that develop_auto will be reset
    And the message should list which PRs will be removed
    And the message should include approve and reject buttons
    And the workflow should wait for a response

  Scenario: Team member approves reset via Slack
    Given an approval request has been sent to Slack
    When any team member clicks the approve button
    Then the approval should be recorded
    And the workflow should continue with the reset
    And develop_auto should be reset to main
    And the PR branch should be merged
    And the deployment should proceed normally
    And a confirmation comment should be posted to the PR

  Scenario: Team member rejects reset via Slack
    Given an approval request has been sent to Slack
    When any team member clicks the reject button
    Then the rejection should be recorded
    And the workflow should not reset develop_auto
    And the workflow should not overwrite develop_auto
    And the PR branch should not be merged
    And the deployment should be cancelled
    And a cancellation comment should be posted to the PR
    And the workflow should exit with failure status

  Scenario: Approval request timeout
    Given an approval request has been sent to Slack
    When no response is received within the timeout period
    Then the workflow should treat it as a rejection
    And the deployment should be cancelled
    And a timeout comment should be posted to the PR
    And the comment should indicate no response was received

  Scenario: Cancellation comment format
    Given the reset was rejected via Slack
    And the rejecting user was "alice"
    When the cancellation comment is posted
    Then the comment should indicate deployment was cancelled
    And the comment should mention it was rejected by a team member
    And the comment should explain develop_auto was not modified
    And the comment should include the workflow run URL
    And the comment should include a cancelled emoji

  Scenario: Approval message includes context
    Given develop_auto contains PR #100 and PR #101
    And main has new commits
    And PR #102 triggered the deployment
    When the approval request is sent to Slack
    Then the message should list removed PRs: #100, #101
    And the message should indicate triggering PR: #102
    And the message should include links to all PRs
    And the message should include a link to the workflow run
    And the message should show who requested the deployment

  Scenario: No approval needed when develop_auto doesn't exist
    Given develop_auto does not exist on remote
    When the prepare step runs
    Then no approval request should be sent
    And develop_auto should be created from main directly
    And the workflow should proceed without waiting

  Scenario: No approval needed when no reset is required
    Given develop_auto exists
    And main has no new commits since last sync
    When the prepare step runs
    Then no approval request should be sent
    And main should be merged normally into develop_auto
    And the workflow should proceed without waiting

  Scenario: Multiple approval responses handled correctly
    Given an approval request has been sent
    When multiple team members respond
    Then the first response should be used
    And subsequent responses should be ignored
    And only one action should be taken (approve or reject)

  Scenario: Slack approval uses interactive components
    Given the approval request is being constructed
    When the message is sent to Slack
    Then it should use Block Kit format
    And it should include an actions block
    And the actions block should have an "Approve" button
    And the actions block should have a "Reject" button
    And the buttons should have unique action IDs
    And the buttons should include workflow context in values
```

---

## Feature: Develop Auto Branch Preparation

```gherkin
Feature: Develop Auto Branch Preparation
  The workflow should properly prepare the develop_auto branch by syncing with main

  Background:
    Given all permission and fork checks have passed
    And the repository has been checked out with full history
    And the approval workflow has completed (if reset was required)

  Scenario: Create develop_auto from main when it doesn't exist
    Given the develop_auto branch does not exist on the remote
    When the prepare step runs
    Then a new develop_auto branch should be created from main
    And no merge from main should be attempted
    And no approval should be required

  Scenario: Sync develop_auto with main when it exists
    Given the develop_auto branch exists on the remote
    And no reset is required
    When the prepare step runs
    Then develop_auto should be checked out
    And main should be merged into develop_auto
    And the merge commit message should be "chore: sync main into develop_auto [auto]"

  Scenario: Reset develop_auto after approval
    Given the develop_auto branch exists
    And main has new commits requiring reset
    And the reset was approved via Slack
    When the prepare step continues after approval
    Then develop_auto should be reset to main
    And previous PR changes should be discarded
    And no merge from main should be performed

  Scenario: Fast-forward merge of main into develop_auto
    Given the develop_auto branch exists
    And develop_auto is behind main with no conflicts
    And no reset is required
    When the prepare step runs
    Then main should merge cleanly into develop_auto
    And the merge should complete successfully

  Scenario: Three-way merge of main into develop_auto
    Given the develop_auto branch exists
    And develop_auto has diverged from main
    And there are no conflicts
    And no reset is required
    When the prepare step runs
    Then main should be three-way merged into develop_auto
    And the merge should complete successfully
    And a merge commit should be created
```

---

## Feature: Main to Develop Auto Merge Conflicts

```gherkin
Feature: Main to Develop Auto Merge Conflicts
  The workflow should handle conflicts when merging main into develop_auto

  Scenario: Merge conflict when syncing main into develop_auto
    Given the develop_auto branch exists
    And develop_auto has conflicting changes with main
    When the prepare step attempts to merge main
    Then the merge should fail
    And the conflicting files should be identified
    And the merge should be aborted
    And a merge conflict resolution branch should be created
    And a merge conflict resolution pull request should be created
    And the workflow should output conflict details
    And the workflow should set success=false
    And the workflow should set conflict_stage=main_to_develop_auto

  Scenario: Comment posted for main-to-develop_auto conflict
    Given the prepare step detected a main-to-develop_auto conflict
    And the conflicting files are "src/app.js, config.yaml"
    When the comment step runs
    Then a comment should be posted on the PR
    And the comment should indicate merge conflict with main
    And the comment should list the conflicting files
    And the comment should instruct to resolve the conflict in the merge conflict pull request
    And the comment should mention re-triggering with "develop deploy"
    And the comment should include the workflow run URL

  Scenario: Workflow fails after main-to-develop_auto conflict
    Given the prepare step detected a conflict
    And a comment has been posted
    When the fail step runs
    Then the workflow should exit with code 1
    And the prepare job should be marked as failed
    And subsequent jobs should not run
```

---

## Feature: PR Branch Merge into Develop Auto

```gherkin
Feature: PR Branch Merge into Develop Auto
  After syncing with main, the PR branch should be merged into develop_auto

  Background:
    Given the develop_auto branch has been synced with main successfully

  Scenario: Clean merge of PR branch into develop_auto
    Given the PR branch has no conflicts with develop_auto
    When the PR branch merge step runs
    Then the PR branch should merge cleanly into develop_auto
    And the merge commit message should reference the PR branch name
    And the merge commit message should include "[auto]"

  Scenario: Fast-forward merge of PR branch
    Given the develop_auto branch is an ancestor of the PR branch
    When the PR branch merge step runs
    Then the PR branch should merge via fast-forward
    And the merge should complete successfully

  Scenario: Three-way merge of PR branch
    Given both develop_auto and PR branch have unique commits
    And there are no conflicts
    When the PR branch merge step runs
    Then a three-way merge should occur
    And a merge commit should be created
    And the merge should complete successfully
```

---

## Feature: PR Branch to Develop Auto Merge Conflicts

```gherkin
Feature: PR Branch to Develop Auto Merge Conflicts
  The workflow should handle conflicts when merging the PR branch into develop_auto

  Scenario: Merge conflict when merging PR branch
    Given develop_auto has been synced with main
    And the PR branch has conflicting changes with develop_auto
    When the PR branch merge step runs
    Then the merge should fail
    And the conflicting files should be identified
    And a merge conflict resolution branch should be created
    And a pull request should be created from the conflict resolution branch to develop_auto
    And the merge should be aborted
    And the workflow should output conflict details
    And the merge conflict resolution PR link should be included in the output
    And the workflow should set success=false
    And the workflow should set conflict_stage=pr_branch_to_develop_auto

  Scenario: Comment posted for PR-to-develop_auto conflict
    Given the prepare step detected a pr_branch_to_develop_auto conflict
    And the PR branch name is "feature/new-api"
    And the conflicting files are "api/routes.js"
    When the comment step runs
    Then a comment should be posted on the PR
    And the comment should indicate conflict merging the PR branch
    And the comment should list the conflicting files
    And the comment should instruct to resolve the conflict in the conflict resolution pull request
    And the comment should mention pushing changes and re-triggering
    And the comment should include the workflow run URL

  Scenario: Workflow fails after PR branch conflict
    Given the PR branch merge detected a conflict
    And a comment has been posted
    When the fail step runs
    Then the workflow should exit with code 1
    And the prepare job should be marked as failed
    And the deploy job should not run
```

---

## Feature: Push Develop Auto Branch

```gherkin
Feature: Push Develop Auto Branch
  After successful merges, develop_auto should be pushed to the remote

  Scenario: Force-with-lease push after successful merges
    Given main has been merged into develop_auto successfully
    And the PR branch has been merged into develop_auto successfully
    When the push step runs
    Then develop_auto should be pushed to origin
    And the push should use --force-with-lease flag
    And the prepare job should output success=true

  Scenario: Force-with-lease prevents overwriting concurrent changes
    Given the local develop_auto has been prepared
    But another process has pushed to remote develop_auto concurrently
    When the push step runs
    Then the push should fail due to --force-with-lease protection
    And the workflow should fail
    And the branch should not be overwritten

  Scenario: Push after creating new develop_auto branch
    Given develop_auto was created from main
    And the PR branch was merged
    When the push step runs
    Then the new develop_auto branch should be pushed to origin
    And the push should succeed
```

---

## Feature: Deploy Job Execution

```gherkin
Feature: Deploy Job Execution
  After prepare job succeeds, the deployment should run

  Scenario: Deploy job waits for prepare job
    Given the prepare job is running
    When the prepare job completes successfully
    Then the deploy job should start
    And the deploy job should run in the testing environment

  Scenario: Deploy job checks out develop_auto
    Given the prepare job has completed successfully
    When the deploy job starts
    Then the develop_auto branch should be checked out
    And the checkout should use the develop_auto ref

  Scenario: Deploy with package.json present and deploy script exists
    Given develop_auto has been checked out
    And a package.json file exists in the root
    And package.json contains a "deploy:testing" script
    When the deploy step runs
    Then npm install should be executed
    And npm run deploy:testing should be executed

  Scenario: Deploy with package.json but no deploy script
    Given develop_auto has been checked out
    And a package.json file exists in the root
    But package.json does not contain a "deploy:testing" script
    When the deploy step runs
    Then npm install should be executed
    And a simulated deploy message should be displayed
    And the job should complete successfully

  Scenario: Deploy without package.json
    Given develop_auto has been checked out
    And no package.json file exists in the root
    When the deploy step runs
    Then npm install should be skipped
    And a simulated deploy message should be displayed
    And the job should complete successfully

  Scenario: Deploy job uses Node.js 22.x
    Given the deploy job is running
    When Node.js is set up
    Then Node.js version 22.x should be installed
```

---

## Feature: Deploy Job Failure Scenarios

```gherkin
Feature: Deploy Job Failure Scenarios
  The deploy job should handle various failure conditions

  Scenario: npm install fails
    Given develop_auto has been checked out
    And a package.json file exists
    When npm install is executed
    And npm install returns a non-zero exit code
    Then the deploy job should fail
    And subsequent deploy steps should not run

  Scenario: deploy:testing script fails
    Given npm install completed successfully
    And package.json contains a "deploy:testing" script
    When npm run deploy:testing is executed
    And the script returns a non-zero exit code
    Then the deploy job should fail
    And the job should be marked as failed

  Scenario: Checkout of develop_auto fails
    Given the prepare job completed successfully
    When the deploy job attempts to checkout develop_auto
    And the checkout action fails
    Then the deploy job should fail
    And subsequent steps should not run
```

---

## Feature: Deployment Success Notification

```gherkin
Feature: Deployment Success Notification
  Users should be notified when deployment succeeds

  Scenario: Success comment posted after successful deploy
    Given the prepare job completed successfully
    And the deploy job completed successfully
    When the notify job runs
    Then a success comment should be posted on the PR
    And the comment should indicate successful deployment to develop
    And the comment should explain the process (synced main, merged PR, deployed)
    And the comment should include the workflow run URL
    And the comment should include a success emoji

  Scenario: Notify job only runs if prepare succeeded
    Given the prepare job failed
    When the notify job condition is evaluated
    Then the notify job should be skipped
    And no notification comment should be posted
```

---

## Feature: Deployment Failure Notification

```gherkin
Feature: Deployment Failure Notification
  Users should be notified when deployment fails

  Scenario: Failure comment posted after deploy job fails
    Given the prepare job completed successfully
    And the deploy job failed
    When the notify job runs
    Then a failure comment should be posted on the PR
    And the comment should indicate deployment failed
    And the comment should instruct to check workflow logs
    And the comment should include the workflow run URL
    And the comment should include a failure emoji

  Scenario: Notify job has access to PR context
    Given the prepare job completed successfully
    And the deploy job failed
    When the notify job runs
    Then the notify job should have pull-requests write permission
    And the notify job should have issues write permission
    And the comment should be posted to the correct PR number
```

---

## Feature: Deployment Cancelled Notification

```gherkin
Feature: Deployment Cancelled Notification
  Users should be notified when deployment is cancelled

  Scenario: Cancelled comment posted after deploy job cancelled
    Given the prepare job completed successfully
    And the deploy job was cancelled by a user
    When the notify job runs
    Then a cancelled comment should be posted on the PR
    And the comment should indicate deployment was cancelled
    And the comment should include the workflow run URL
    And the comment should include a warning emoji

  Scenario: Deploy cancelled during npm install
    Given the deploy job is running
    And npm install is in progress
    When a user cancels the workflow
    Then the deploy job should stop
    And the notify job should run
    And a cancelled notification should be posted
```

---

## Feature: Notify Job Execution Conditions

```gherkin
Feature: Notify Job Execution Conditions
  The notify job should run under specific conditions

  Scenario: Notify runs when prepare succeeds and deploy succeeds
    Given the prepare job result is "success"
    And the deploy job result is "success"
    When the workflow completes
    Then the notify job should run
    And a success comment should be posted

  Scenario: Notify runs when prepare succeeds and deploy fails
    Given the prepare job result is "success"
    And the deploy job result is "failure"
    When the workflow completes
    Then the notify job should run
    And a failure comment should be posted

  Scenario: Notify runs when prepare succeeds and deploy is cancelled
    Given the prepare job result is "success"
    And the deploy job result is "cancelled"
    When the workflow completes
    Then the notify job should run
    And a cancelled comment should be posted

  Scenario: Notify does not run when prepare fails
    Given the prepare job result is "failure"
    When the workflow completes
    Then the notify job should be skipped
    And no deployment notification should be posted

  Scenario: Notify does not run when prepare is cancelled
    Given the prepare job result is "cancelled"
    When the workflow completes
    Then the notify job should be skipped
```

---

## Feature: Complete Workflow Success Path

```gherkin
Feature: Complete Workflow Success Path
  Full end-to-end successful deployment scenario

  Scenario: Successful deployment with new develop_auto branch
    Given an open pull request #123 from branch "feature/add-login"
    And the PR is from the same repository
    And develop_auto branch does not exist
    And a user with write access comments "develop deploy"
    When the workflow executes
    Then permission verification passes
    And fork check passes
    And a "deployment started" comment is posted
    And develop_auto is created from main
    And "feature/add-login" is merged into develop_auto
    And develop_auto is pushed to origin
    And develop_auto is checked out in deploy job
    And the application is deployed to testing environment
    And a "deployment succeeded" comment is posted
    And the workflow completes with success status

  Scenario: Successful deployment with existing develop_auto branch and approval
    Given an open pull request #124 from branch "feature/new-api"
    And the PR is from the same repository
    And develop_auto branch exists on remote
    And develop_auto is 3 commits behind main
    And develop_auto contains previous PR changes
    And a user with admin access comments "develop deploy"
    When the workflow executes
    Then permission verification passes
    And a reset is detected as needed
    And an approval request is sent to Slack
    And a team member approves the reset
    And develop_auto is reset to main
    And "feature/new-api" is merged into develop_auto
    And develop_auto is force-with-lease pushed to origin
    And develop_auto is deployed to testing environment
    And a success comment is posted
```

---

## Feature: Complete Workflow Failure Paths

```gherkin
Feature: Complete Workflow Failure Paths
  End-to-end failure scenarios

  Scenario: Failure due to insufficient permissions
    Given an open pull request #125 from branch "feature/update"
    And a user with read-only access comments "develop deploy"
    When the workflow executes
    Then the permission check fails
    And the workflow exits with failure
    And no comments are posted to the PR
    And develop_auto is not modified

  Scenario: Failure due to fork PR
    Given a pull request #126 from a forked repository
    And a user with write access comments "develop deploy"
    When the workflow executes
    Then the fork check fails
    And an error comment is posted explaining fork limitation
    And the workflow exits with failure
    And develop_auto is not modified

  Scenario: Failure due to rejected reset approval
    Given an open pull request #127 from branch "feature/new-feature"
    And develop_auto exists and needs to be reset
    And a user with write access comments "develop deploy"
    When the workflow executes
    Then an approval request is sent to Slack
    And a team member rejects the reset
    And a cancellation comment is posted to the PR
    And the workflow exits with failure
    And develop_auto is not reset
    And develop_auto is not overwritten
    And the PR branch is not merged

  Scenario: Failure due to approval timeout
    Given an open pull request #128 from branch "feature/update"
    And develop_auto exists and needs to be reset
    And a user with write access comments "develop deploy"
    When the workflow executes
    Then an approval request is sent to Slack
    And no response is received within the timeout period
    And a timeout cancellation comment is posted to the PR
    And the workflow exits with failure
    And develop_auto is not modified

  Scenario: Failure due to main merge conflict
    Given an open pull request #129 from branch "feature/refactor"
    And develop_auto exists with conflicting changes to main in "config.yaml"
    And a user with write access comments "develop deploy"
    When the workflow executes
    Then main merge into develop_auto fails
    And conflicting files are identified
    And a merge conflict resolution branch and PR are created
    And a conflict comment is posted with file list and PR link
    And the workflow exits with failure
    And develop_auto is not pushed

  Scenario: Failure due to PR branch merge conflict
    Given an open pull request #130 from branch "feature/ui-update"
    And develop_auto has been synced with main successfully
    And "feature/ui-update" conflicts with develop_auto in "styles.css"
    And a user with write access comments "develop deploy"
    When the workflow executes
    Then PR branch merge into develop_auto fails
    And conflicting files are identified
    And a merge conflict resolution branch and PR are created
    And a conflict comment is posted with link to the merge conflict PR
    And the workflow exits with failure
    And develop_auto is not pushed

  Scenario: Failure during deployment
    Given an open pull request #131 from branch "feature/backend"
    And all merges complete successfully
    And develop_auto is pushed to origin
    And npm run deploy:testing fails with exit code 1
    When the workflow executes
    Then the deploy job fails
    And a deployment failure comment is posted
    And the workflow completes with failure status
    But develop_auto remains updated on remote
```

---

## Feature: Order of Operations

```gherkin
Feature: Order of Operations
  The workflow steps must execute in the correct order

  Scenario: Verify step execution order in prepare job
    Given the workflow is triggered
    When the prepare job runs
    Then steps should execute in this order:
      | Step                                    |
      | Verify commenter has write access       |
      | Get PR info and block fork PRs          |
      | Post workflow started comment           |
      | Checkout repository                     |
      | Configure git identity                  |
      | Check if develop_auto reset is needed   |
      | Send approval request to Slack (if reset needed) |
      | Wait for approval response (if reset needed) |
      | Cancel if rejected (if applicable)      |
      | Prepare develop_auto and merge branches |
      | Comment on merge conflict (if needed)   |
      | Fail job on merge conflict (if needed)  |

  Scenario: Verify job execution order
    Given the workflow is triggered with valid conditions
    When the workflow runs
    Then jobs should execute in this order:
      | Job     | Dependencies                |
      | prepare | none                        |
      | deploy  | prepare (success)           |
      | notify  | prepare (success), deploy (always) |

  Scenario: Verify branch merge order in prepare step
    Given the prepare develop_auto step is running
    When branches are being merged
    Then operations should occur in this order:
      | Operation                                      |
      | Fetch all remote branches                      |
      | Check if develop_auto exists remotely          |
      | Checkout or create develop_auto from main      |
      | Merge main into develop_auto (if exists)       |
      | Merge PR branch into develop_auto              |
      | Push develop_auto to origin with force-with-lease |

  Scenario: Git operations maintain atomicity
    Given the prepare step is performing merges
    When a merge conflict occurs
    Then the merge should be aborted
    And the branch state should be clean
    And no partial changes should be pushed
    And subsequent merge operations should not run
```

---

## Feature: Concurrency and Race Conditions

```gherkin
Feature: Concurrency and Race Conditions
  The workflow should handle multiple concurrent requests safely

  Scenario: Sequential execution prevents branch corruption
    Given deploy is requested for PR #100 at time T0
    And deploy is requested for PR #101 at time T1 (T1 > T0)
    When both workflows attempt to run
    Then PR #100 workflow should acquire the lock
    And PR #101 workflow should wait in queue
    And PR #100 should complete all steps
    And only after PR #100 completes, PR #101 should start
    And develop_auto should contain changes from both PRs in order

  Scenario: Force-with-lease prevents concurrent push conflicts
    Given PR #200 workflow has prepared develop_auto locally
    And PR #201 workflow is queued
    But PR #201 somehow bypasses the queue and pushes first
    When PR #200 attempts to push
    Then the force-with-lease push should fail
    And the workflow should fail with an error
    And PR #200 should not overwrite PR #201's changes

  Scenario: Multiple comments on same PR queue correctly
    Given PR #300 is open
    And user A comments "develop deploy" at time T0
    And user B comments "develop deploy" at time T1 (T1 > T0)
    When both workflows are triggered
    Then the first workflow (T0) should execute
    And the second workflow (T1) should wait
    And the second workflow should see develop_auto with first workflow's changes
    And both deployments should succeed sequentially
```

---

## Feature: Git Configuration and Repository State

```gherkin
Feature: Git Configuration and Repository State
  Git operations should be performed with correct configuration

  Scenario: Git identity is configured for bot commits
    Given the prepare job is running
    When git identity is configured
    Then git user.name should be "github-actions[bot]"
    And git user.email should be "github-actions[bot]@users.noreply.github.com"

  Scenario: Repository is checked out with full history
    Given the prepare job is running
    When the repository is checked out
    Then fetch-depth should be 0 (full history)
    And all branches and tags should be available
    And git fetch --all should succeed

  Scenario: Merge commits have appropriate messages
    Given develop_auto is being prepared
    When main is merged into develop_auto
    Then the merge commit message should be "chore: sync main into develop_auto [auto]"
    And the merge should use --no-edit flag

  Scenario: PR branch merge has appropriate message
    Given the PR branch "feature/test" is being merged
    When the PR branch is merged into develop_auto
    Then the commit message should be "chore: merge feature/test into develop_auto for deploy [auto]"
    And the merge should use --no-edit flag
```

---

## Feature: Error Messages and User Feedback

```gherkin
Feature: Error Messages and User Feedback
  Users should receive clear, actionable error messages

  Scenario: Permission error includes permission level
    Given a user with "triage" permission comments "develop deploy"
    When the permission check runs
    Then the error should state the user lacks write access
    And the error should mention the actual permission level "triage"
    And the error should list required permission levels

  Scenario: Fork PR error provides clear guidance
    Given a fork PR receives "develop deploy" comment
    When the fork check runs
    Then the comment should clearly state fork PRs are not supported
    And the comment should explain why (security/branch access)
    And the comment should suggest opening PR from same-repo branch
    And the workflow run URL should be included

  Scenario: Merge conflict error lists conflicting files
    Given a merge conflict occurs
    When the conflict comment is posted
    Then the comment should list each conflicting file
    And the comment should indicate which merge stage failed
    And the comment should provide resolution instructions
    And the comment should mention re-triggering after fix

  Scenario: Merge conflict error creates branch and pull request
    Given a merge conflict occurs
    When the conflict is detected
    Then a merge conflict resolution branch should be created
    And a merge conflict resolution pull request should be created
    And the pull request should explain it is a merge conflict resolution branch

  Scenario: Deployment failure provides troubleshooting info
    Given the deploy job fails
    When the failure comment is posted
    Then the comment should link to workflow logs
    And the comment should indicate which step failed
    And the workflow run URL should be prominent
```

---

## Feature: Environment Protection

```gherkin
Feature: Environment Protection
  The testing environment should provide appropriate protection

  Scenario: Deploy job runs in testing environment
    Given the deploy job is executing
    Then the job should target the "testing" environment
    And environment-specific protection rules should apply
    And environment secrets should be available

  Scenario: Testing environment does not block deployment
    Given the prepare job succeeded
    When the deploy job starts
    Then the testing environment should not require manual approval
    And deployment should proceed automatically
```

---

## Feature: Develop Auto Reset on Main Changes

```gherkin
Feature: Develop Auto Reset on Main Changes
  develop_auto should reset to main when new commits are detected in main

  Scenario: Reset develop_auto when main has new commits
    Given develop_auto exists and contains PR #100 and PR #101 changes
    And main has been updated with new merged PRs since last sync
    When a new deploy is triggered for PR #102
    Then the workflow should detect main has new commits
    And develop_auto should be reset to main (not merged)
    And previous PR changes (#100, #101) should be discarded
    And only PR #102 should be merged into the fresh develop_auto
    And the reset should be logged in workflow output

  Scenario: Merge main when main is unchanged
    Given develop_auto exists and contains PR #200 changes
    And main has no new commits since last sync
    When a new deploy is triggered for PR #201
    Then the workflow should detect main is unchanged
    And main should be merged into develop_auto (preserving PR #200)
    And PR #201 should be merged
    And develop_auto should contain both PR #200 and PR #201

  Scenario: Comment indicates reset occurred
    Given develop_auto was reset due to main changes
    When the deployment succeeds
    Then the success comment should mention develop_auto was reset
    And the comment should list that only the current PR was deployed
    And the comment should suggest re-deploying other PRs if needed

  Scenario: Comment indicates incremental merge
    Given develop_auto was incrementally updated (no reset)
    When the deployment succeeds
    Then the success comment should indicate develop_auto contains multiple PRs
    And the comment should note this is testing multiple changes together

  Scenario: First deployment after main update removes abandoned PR
    Given PR #300 was deployed to develop_auto
    And PR #300 was later closed without merging
    And develop_auto still contains PR #300 changes
    When a commit is merged to main
    And a new deploy is triggered for PR #301
    Then develop_auto should be reset to main
    And PR #300 changes should be removed automatically
    And only PR #301 should be present in develop_auto
```

---

## Feature: Notification for Removed PRs

```gherkin
Feature: Notification for Removed PRs
  When develop_auto is reset, developers should be notified of removed PRs

  Background:
    Given the workflow uses git history to track deployed PRs
    And merge commits follow the pattern "chore: merge <branch> into develop_auto for deploy [auto]"

  Scenario: Identify removed PRs from git history
    Given develop_auto contains merge commits for branches: feature/a, feature/b, feature/c
    And main has new commits requiring reset
    When the prepare step detects the reset condition
    Then the workflow should parse git log between main and develop_auto
    And extract branch names from merge commit messages
    And the extracted branches should be: feature/a, feature/b, feature/c

  Scenario: Query GitHub to find open PRs for removed branches
    Given removed branches are: feature/a, feature/b, feature/c
    When the workflow queries GitHub for these branches
    Then it should find PR numbers for each branch
    And it should check if each PR is still open
    And only open PRs should be included in notifications

  Scenario: Filter out closed/merged PRs from notifications
    Given develop_auto contained PR #100 (open), PR #101 (closed), PR #102 (merged)
    And all three are being removed due to reset
    When the workflow identifies PRs to notify
    Then PR #100 should be included in notifications
    And PR #101 should be excluded (closed)
    And PR #102 should be excluded (merged)

  Scenario: Comment on triggering PR about reset
    Given develop_auto was reset due to main changes
    And removed open PRs are: #100, #101, #102
    When the deployment succeeds
    And the success comment is posted on the triggering PR
    Then the comment should indicate develop_auto was reset
    And the comment should list removed PR numbers with authors
    And the comment should explain why the reset happened
    And the comment should suggest affected developers re-deploy if needed

  Scenario: Post Slack notification about removed PRs
    Given develop_auto was reset due to main changes
    And removed open PRs are: #100 (@alice), #101 (@bob)
    And the triggering PR is #200 (@charlie)
    When the notification step runs
    Then a Slack message should be posted to the configured channel
    And the message should mention the reset occurred
    And the message should list removed PRs with author mentions
    And the message should indicate which PR triggered the reset
    And the message should link to the workflow run
    And the message should link to each removed PR

  Scenario: No notification when no PRs are removed
    Given develop_auto is reset to main
    But no other PRs were previously deployed
    When the deployment succeeds
    Then the success comment should indicate fresh deploy
    And no Slack notification about removed PRs should be sent
    And the comment should not mention removed PRs

  Scenario: No notification when develop_auto is not reset
    Given main has no new commits
    And develop_auto is merged incrementally (not reset)
    When the deployment succeeds
    Then the comment should indicate incremental merge
    And no Slack notification about removed PRs should be sent

  Scenario: Handle GitHub API failures gracefully
    Given develop_auto was reset
    And removed branches are identified
    When querying GitHub API for PR numbers fails
    Then the workflow should log the error
    And the deployment should still succeed
    And the PR comment should mention unable to identify removed PRs
    And no Slack notification should be sent

  Scenario: Slack notification includes all context
    Given PR #100 (feature/auth) by @alice is removed
    And PR #101 (feature/payments) by @bob is removed
    And PR #200 (feature/search) by @charlie triggered the reset
    When the Slack notification is sent
    Then the message format should be:
      """
      ⚠️ Develop Environment Reset

      The `develop_auto` branch was reset to `main` due to new merges.

      **Removed PRs:**
      • PR #100 - feature/auth (@alice) - [View PR](...)
      • PR #101 - feature/payments (@bob) - [View PR](...)

      **Triggered by:** PR #200 - feature/search (@charlie) - [View PR](...)

      **Action needed:** If you still need to test in develop, comment `develop deploy` on your PR.

      [View Workflow Run](...)
      """

  Scenario: Comment format for removed PRs
    Given PR #100 by @alice and PR #101 by @bob are removed
    When the success comment is posted on the triggering PR
    Then the comment should include a section:
      """
      ⚠️ **Note:** `develop_auto` was reset to `main` (new commits detected)

      The following PRs were previously deployed but have been cleared:
      - PR #100 (@alice)
      - PR #101 (@bob)

      If they still need testing in develop, they should re-run `develop deploy`.
      """
```

---

## Feature: Slack Approval Integration

```gherkin
Feature: Slack Approval Integration
  Approval requests should use Slack interactive components and webhooks

  Background:
    Given the workflow has access to SLACK_BOT_TOKEN secret
    And the workflow has access to SLACK_CHANNEL_ID variable
    And the workflow has access to SLACK_WEBHOOK_URL for responses
    And the Slack bot has permission to post in the channel

  Scenario: Send approval request with interactive buttons
    Given a reset is required
    When the approval request is sent
    Then it should POST to https://slack.com/api/chat.postMessage
    And it should include "Authorization: Bearer <token>" header
    And it should target the channel specified in SLACK_CHANNEL_ID
    And the message should use Block Kit format
    And it should include approve and reject buttons with action IDs

  Scenario: Handle approval button click
    Given an approval request message is posted
    When a team member clicks the "Approve" button
    Then Slack should send a payload to the configured webhook URL
    And the payload should include the action_id
    And the payload should include the user who clicked
    And the workflow should receive the approval response
    And the workflow should continue with the reset

  Scenario: Handle rejection button click
    Given an approval request message is posted
    When a team member clicks the "Reject" button
    Then Slack should send a payload to the configured webhook URL
    And the payload should include the rejection action
    And the payload should include the user who clicked
    And the workflow should receive the rejection response
    And the workflow should cancel the deployment

  Scenario: Update approval message after response
    Given an approval request is sent
    When a team member responds (approve or reject)
    Then the original message should be updated
    And the buttons should be disabled or removed
    And the message should show who responded
    And the message should show the decision (approved/rejected)
    And the message should include a timestamp

  Scenario: Store approval state for workflow to check
    Given an approval request is sent
    When a response is received via webhook
    Then the response should be stored in a database or state file
    And the workflow should poll or wait for this state
    And the state should include: approved/rejected status
    And the state should include: responding user
    And the state should include: timestamp

  Scenario: Approval request includes workflow context
    Given a reset approval is needed
    When constructing the Slack message
    Then the message should include workflow run ID
    And the message should include repository name
    And the message should include PR number
    And the message should include triggering user
    And this context should be passed with button actions

  Scenario: Webhook validates request authenticity
    Given the webhook receives a Slack payload
    When processing the request
    Then it should verify the Slack signing secret
    And it should validate the request timestamp
    And it should reject invalid or replayed requests
    And it should only process legitimate Slack requests

  Scenario: Approval timeout mechanism
    Given an approval request is sent at time T
    When no response is received within configured timeout (e.g., 10 minutes)
    Then the workflow should check elapsed time
    And if timeout exceeded, treat as rejection
    And update the Slack message to show timeout
    And post cancellation comment to PR
```

---

## Feature: Slack Integration for Removed PR Notifications

```gherkin
Feature: Slack Integration for Removed PR Notifications
  Slack notifications should be sent using bot token to a configured channel

  Background:
    Given the workflow has access to SLACK_BOT_TOKEN secret
    And the workflow has access to SLACK_CHANNEL_ID variable
    And the Slack bot has permission to post in the channel

  Scenario: Slack bot token authentication
    Given the SLACK_BOT_TOKEN is configured
    When the workflow sends a Slack notification
    Then it should use the Slack Web API
    And it should POST to https://slack.com/api/chat.postMessage
    And it should include "Authorization: Bearer <token>" header
    And it should target the channel specified in SLACK_CHANNEL_ID

  Scenario: Slack message uses block kit format
    Given removed PRs exist to notify about
    When building the Slack message payload
    Then the message should use Block Kit JSON format
    And it should include a header block with warning emoji
    And it should include section blocks for removed PRs
    And it should include a context block for action instructions
    And it should include a button linking to the workflow run

  Scenario: Slack message without user mentions
    Given PR #100 by alice and PR #101 by bob are removed
    When the Slack message is formatted
    Then it should display usernames as plain text
    And it should not use Slack user ID mentions
    And usernames should appear as "alice" not "<@U123ABC>"

  Scenario: Slack notification sent after successful deployment
    Given the prepare job completed with reset
    And removed PRs were identified
    And the deploy job succeeded
    When the notify job runs
    Then it should post the GitHub comment first
    And then it should send the Slack notification
    And the Slack send should be a separate step

  Scenario: Slack notification fails silently
    Given the notify job needs to send Slack notification
    When the Slack API call fails
    Then the error should be logged
    And the workflow should continue
    And the overall job should still succeed
    And the GitHub comment should still be posted

  Scenario: Slack notification skipped when no removed PRs
    Given develop_auto was not reset
    Or no open PRs were removed
    When the notify job runs
    Then the Slack notification step should be skipped
    And no API call to Slack should be made

  Scenario: Slack notification step uses continue-on-error
    Given the Slack notification step is defined
    Then it should have continue-on-error set to true
    And step failure should not affect job status
    And subsequent steps should still run

  Scenario: Missing Slack configuration handled gracefully
    Given SLACK_BOT_TOKEN is not configured
    Or SLACK_CHANNEL_ID is not configured
    When the Slack notification step runs
    Then it should detect missing configuration
    And it should log a warning
    And it should skip the notification
    And the workflow should continue successfully

  Scenario: Slack message includes all required information
    Given PR #100 (feature/auth, alice) and PR #101 (feature/pay, bob) removed
    And PR #200 (feature/search, charlie) triggered the reset
    And the workflow run ID is 123456
    And the repository is org/repo
    When the Slack message is constructed
    Then it should include:
      | Field                    | Value                                           |
      | Header                   | ⚠️ Develop Environment Reset                   |
      | Explanation              | develop_auto reset to main due to new merges    |
      | Removed PR #100          | PR #100 - feature/auth (alice) with link        |
      | Removed PR #101          | PR #101 - feature/pay (bob) with link           |
      | Triggering PR            | PR #200 - feature/search (charlie) with link    |
      | Action instruction       | Comment "develop deploy" to redeploy            |
      | Workflow link button     | Link to github.com/org/repo/actions/runs/123456 |

  Scenario: Slack API response validation
    Given a Slack notification is sent
    When the Slack API responds
    Then the workflow should check response.ok field
    And if ok is false, it should log the error message
    And if ok is true, it should log success
    And response validation should not throw errors

  Scenario: Channel ID format validation
    Given SLACK_CHANNEL_ID is set
    When the notification step starts
    Then it should accept channel IDs starting with C
    And it should accept channel IDs starting with G (private channels)
    And it should log the channel ID being used (for debugging)
```

---

## Feature: Workflow Outputs and Artifacts

```gherkin
Feature: Workflow Outputs and Artifacts
  Jobs should produce and consume outputs correctly

  Scenario: Prepare job outputs PR branch name
    Given the prepare job is running
    When PR info is retrieved
    Then the PR branch name should be set as job output "pr_branch"
    And the output should be available to dependent jobs

  Scenario: Merge step outputs success status
    Given the merge step is running
    When merges complete or fail
    Then the output "success" should be set to "true" or "false"
    And subsequent steps should check this output

  Scenario: Merge step outputs conflict details
    Given a merge conflict occurs
    When the merge is aborted
    Then the output should include "conflict_stage"
    And the output should include "conflict_files"
    And the output should include a link to the merge conflict resolution pull request
    And these outputs should be used in the comment step
```

---

## Feature: Permissions and Access Control

```gherkin
Feature: Permissions and Access Control
  Jobs should have appropriate GitHub permissions

  Scenario: Prepare job has required permissions
    Given the prepare job is running
    Then it should have "contents: write" permission
    And it should have "pull-requests: write" permission
    And it should have "issues: write" permission

  Scenario: Deploy job has minimal permissions
    Given the deploy job is running
    Then it should have default read permissions
    And it should not have write access to PRs or issues

  Scenario: Notify job has comment permissions
    Given the notify job is running
    Then it should have "pull-requests: write" permission
    And it should have "issues: write" permission
    And it should not have "contents: write" permission
```

---

## Feature: Idempotency and Retry Scenarios

```gherkin
Feature: Idempotency and Retry Scenarios
  Re-running the workflow should be safe and predictable

  Scenario: Re-trigger after resolving merge conflict
    Given a previous deploy failed with merge conflict in "app.js"
    And the developer resolved the conflict and pushed to PR branch
    When the user comments "develop deploy" again
    Then the workflow should run from the beginning
    And the merge should now succeed
    And deployment should complete successfully

  Scenario: Re-trigger on same PR without changes
    Given a deploy succeeded for PR #400
    And no new commits have been pushed to the PR
    When the user comments "develop deploy" again
    Then the workflow should run again
    And develop_auto should be re-synced with main
    And the PR branch should be merged again
    And deployment should succeed
    And develop_auto should be updated with latest main changes

  Scenario: Multiple users trigger same PR
    Given user A triggers deploy on PR #500
    And the workflow is running
    And user B triggers deploy on the same PR #500
    When both workflows are in queue
    Then the second workflow should wait for the first
    And both workflows should complete successfully
    And the second workflow should incorporate any main changes since first workflow
```
