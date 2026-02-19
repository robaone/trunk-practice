# trunk-practice

## Overview

Testing trunk based workflows.

## Introduction

This repository is designed to test out workflows where the only protected branch is `main` and the default branch is `main`.  This means that `main` is the source of truth.

## I want to add functionality!

## Repository Configuration

To enable the automated conflict resolution workflow, you must allow GitHub Actions to create pull requests:

1.  **Navigate to the repository on GitHub** (e.g., `https://github.com/robaone/trunk-practice`).
2.  Click on the **Settings** tab in the top navigation bar.
3.  In the left sidebar, click on **Actions**, then select **General**.
4.  Scroll down to the **Workflow permissions** section.
5.  Ensure **Read and write permissions** is selected.
6.  **Crucially**, check the box that says **Allow GitHub Actions to create and approve pull requests**.
7.  Click the **Save** button.

## Feature Tests

A feature test file explains all of the functionality
