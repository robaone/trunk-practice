#!/usr/bin/env node

/**
 * This script generates a matrix object string from a list of files.
 * It detects which projects in the project/ folder have been modified
 * and generates a GitHub Actions matrix for parallel job execution.
 * 
 * Supports .depends files for cross-project dependency detection.
 * 
 * Usage: cat file_list.txt | node generate_matrix.js
 * 
 * Environment Variables:
 *   PROJECT_ROOT - The folder containing projects (default: 'project')
 *   IGNORE_LIST  - Space-separated list of folders to ignore
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
const PROJECT_ROOT = process.env.PROJECT_ROOT || 'project';
const IGNORE_LIST = process.env.IGNORE_LIST ? process.env.IGNORE_LIST.split(' ') : [];

function gitRoot() {
  return execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
}

function folderExists(folderPath) {
  try {
    return fs.statSync(folderPath).isDirectory();
  } catch (error) {
    return false;
  }
}

function getProjectsWithDependsFile() {
  const projectsFolder = path.join(gitRoot(), PROJECT_ROOT);
  const projects = [];
  
  try {
    // Try to read the directory - if it doesn't exist, readdirSync will throw
    // This is more reliable than checking folderExists first
    const files = fs.readdirSync(projectsFolder);
    for (const file of files) {
      const projectPath = path.join(projectsFolder, file);
      const dependsPath = path.join(projectPath, '.depends');
      if (fs.existsSync(dependsPath)) {
        projects.push(file);
      }
    }
  } catch (error) {
    // If folder doesn't exist or can't be read, return empty array
    // Only log if it's an unexpected error (not ENOENT or TypeError from mock)
    if (error.code !== 'ENOENT' && error.name !== 'TypeError') {
      console.error('Error reading projects folder:', error.message);
    }
  }
  
  return projects;
}

function checkDependencies(fileList, projects) {
  const triggeredProjects = new Set();
  const projectsFolder = path.join(gitRoot(), PROJECT_ROOT);
  
  for (const project of projects) {
    const dependsPath = path.join(projectsFolder, project, '.depends');
    
    try {
      const dependsContent = fs.readFileSync(dependsPath, 'utf8');
      const dependsPatterns = dependsContent.split('\n').filter(line => line.trim());
      
      for (const file of fileList) {
        for (const pattern of dependsPatterns) {
          // Convert glob pattern to regex
          const regexPattern = '^' + pattern
            .replace(/\./g, '\\.')
            .replace(/\*\*/g, '(.+)')
            .replace(/\*/g, '([^/]+)') + '$';
          const regex = new RegExp(regexPattern);
          if (regex.test(file)) {
            triggeredProjects.add(project);
            break;
          }
        }
      }
    } catch (error) {
      console.error(`Error reading .depends file for ${project}:`, error.message);
    }
  }
  
  return Array.from(triggeredProjects);
}

function parseFileListForProjects(fileList) {
  // Read PROJECT_ROOT from env each time to handle test changes
  const currentProjectRoot = process.env.PROJECT_ROOT || 'project';
  const folders = new Set();
  
  // Extract folders from file paths
  for (const file of fileList) {
    if (currentProjectRoot === '.') {
      const firstFolder = file.split('/')[0];
      if (firstFolder) {
        folders.add(firstFolder);
      }
    } else {
      if (file.startsWith(currentProjectRoot + '/')) {
        const parts = file.split('/');
        if (parts.length >= 2) {
          folders.add(parts[0] + '/' + parts[1]);
        }
      }
    }
  }
  
  // Get dependency-triggered folders
  // Note: getProjectsWithDependsFile uses module-level PROJECT_ROOT, but that's OK
  // since it's only used to find the projects folder, not for filtering
  const projectsWithDepends = getProjectsWithDependsFile();
  const dependsFolders = checkDependencies(fileList, projectsWithDepends);
  
  // Track which folders came from dependencies (these are trusted to exist)
  const dependencyTriggeredFolders = new Set();
  
  // Combine and remove duplicates
  for (const folder of dependsFolders) {
    let folderPath;
    if (currentProjectRoot === '.') {
      folderPath = folder;
    } else {
      folderPath = currentProjectRoot + '/' + folder;
    }
    folders.add(folderPath);
    dependencyTriggeredFolders.add(folderPath);
  }
  
  // Filter out non-existent folders and ignored folders
  const ignoreList = [...IGNORE_LIST];
  if (currentProjectRoot === '.') {
    ignoreList.push('.github');
  }
  
  // Add non-existent folders to ignore list (but trust dependency-triggered folders)
  for (const folder of folders) {
    if (!dependencyTriggeredFolders.has(folder)) {
      // Always join with git root to get absolute path for existence check
      const checkPath = path.join(gitRoot(), folder);
      if (!folderExists(checkPath)) {
        ignoreList.push(folder);
      }
    }
  }
  
  const validFolders = [];
  for (const folder of folders) {
    // Dependency-triggered folders are trusted to exist, others need verification
    const isDependencyTriggered = dependencyTriggeredFolders.has(folder);
    // Always join with git root to get absolute path for existence check
    const checkPath = path.join(gitRoot(), folder);
    const exists = isDependencyTriggered || folderExists(checkPath);
    
    // Check if folder should be ignored - check both full path and project name
    // First check if the project name (from original IGNORE_LIST) matches
    // Read IGNORE_LIST from env each time to handle test changes
    const currentIgnoreList = process.env.IGNORE_LIST ? process.env.IGNORE_LIST.split(' ') : [];
    let shouldIgnore = false;
    if (currentProjectRoot !== '.') {
      const projectName = folder.replace(currentProjectRoot + '/', '');
      shouldIgnore = currentIgnoreList.includes(projectName);
    }
    // Also check if full folder path is in ignore list (for non-existent folders)
    if (!shouldIgnore) {
      shouldIgnore = ignoreList.includes(folder);
    }
    
    if (!shouldIgnore && exists) {
      if (currentProjectRoot === '.') {
        validFolders.push(folder);
      } else {
        validFolders.push(folder.replace(currentProjectRoot + '/', ''));
      }
    }
  }
  
  return validFolders;
}

function generateMatrix(projects) {
  const matrixObject = {
    include: [
      { project: '.' },
      ...projects.map(project => ({ project }))
    ]
  };
  
  return JSON.stringify(matrixObject);
}

// Main execution
function main() {
  try {
    // Read input from stdin
    const input = fs.readFileSync(0, 'utf8').trim();
    
    if (!input) {
      // No files changed, return empty matrix with just root
      console.log(JSON.stringify({ include: [{ project: '.' }] }));
      return;
    }
    
    // Check if PROJECT_ROOT exists
    const projectRootPath = path.join(gitRoot(), PROJECT_ROOT);
    if (!folderExists(projectRootPath)) {
      // PROJECT_ROOT doesn't exist, return matrix with just root
      console.log(JSON.stringify({ include: [{ project: '.' }] }));
      return;
    }
    
    // Parse file list into projects
    const fileList = input.split('\n').filter(line => line.trim());
    const projects = parseFileListForProjects(fileList);
    
    // Generate matrix object
    const matrixObject = generateMatrix(projects);
    
    // Output the matrix object
    console.log(matrixObject);
    
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

// Run the script
if (require.main === module) {
  main();
}

module.exports = {
  parseFileListForProjects,
  generateMatrix,
  getProjectsWithDependsFile,
  checkDependencies
};

