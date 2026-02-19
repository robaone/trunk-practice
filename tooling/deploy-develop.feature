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

## Feature: Develop Auto Branch Preparation

```gherkin
Feature: Develop Auto Branch Preparation
  The workflow should properly prepare the develop_auto branch by syncing with main

  Background:
    Given all permission and fork checks have passed
    And the repository has been checked out with full history

  Scenario: Create develop_auto from main when it doesn't exist
    Given the develop_auto branch does not exist on the remote
    When the prepare step runs
    Then a new develop_auto branch should be created from main
    And no merge from main should be attempted

  Scenario: Sync develop_auto with main when it exists
    Given the develop_auto branch exists on the remote
    When the prepare step runs
    Then develop_auto should be checked out
    And main should be merged into develop_auto
    And the merge commit message should be "chore: sync main into develop_auto [auto]"

  Scenario: Fast-forward merge of main into develop_auto
    Given the develop_auto branch exists
    And develop_auto is behind main with no conflicts
    When the prepare step runs
    Then main should merge cleanly into develop_auto
    And the merge should complete successfully

  Scenario: Three-way merge of main into develop_auto
    Given the develop_auto branch exists
    And develop_auto has diverged from main
    And there are no conflicts
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

  Scenario: Successful deployment with existing develop_auto branch
    Given an open pull request #124 from branch "feature/new-api"
    And the PR is from the same repository
    And develop_auto branch exists on remote
    And develop_auto is 3 commits behind main
    And a user with admin access comments "develop deploy"
    When the workflow executes
    Then permission verification passes
    And develop_auto is checked out
    And main is merged into develop_auto (3 commits)
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

  Scenario: Failure due to main merge conflict
    Given an open pull request #127 from branch "feature/refactor"
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
    Given an open pull request #128 from branch "feature/ui-update"
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
    Given an open pull request #129 from branch "feature/backend"
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
