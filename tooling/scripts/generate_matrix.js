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
    if (!folderExists(projectsFolder)) {
      return projects;
    }
    const files = fs.readdirSync(projectsFolder);
    for (const file of files) {
      const projectPath = path.join(projectsFolder, file);
      const dependsPath = path.join(projectPath, '.depends');
      if (fs.existsSync(dependsPath)) {
        projects.push(file);
      }
    }
  } catch (error) {
    console.error('Error reading projects folder:', error.message);
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
          const regexPattern = pattern
            .replace(/\./g, '\\.')
            .replace(/\*/g, '.*');
          
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
  const folders = new Set();
  
  // Extract folders from file paths
  for (const file of fileList) {
    if (PROJECT_ROOT === '.') {
      const firstFolder = file.split('/')[0];
      if (firstFolder) {
        folders.add(firstFolder);
      }
    } else {
      if (file.startsWith(PROJECT_ROOT + '/')) {
        const parts = file.split('/');
        if (parts.length >= 2) {
          folders.add(parts[0] + '/' + parts[1]);
        }
      }
    }
  }
  
  // Get dependency-triggered folders
  const projectsWithDepends = getProjectsWithDependsFile();
  const dependsFolders = checkDependencies(fileList, projectsWithDepends);
  
  // Combine and remove duplicates
  for (const folder of dependsFolders) {
    if (PROJECT_ROOT === '.') {
      folders.add(folder);
    } else {
      folders.add(PROJECT_ROOT + '/' + folder);
    }
  }
  
  // Filter out non-existent folders and ignored folders
  const ignoreList = [...IGNORE_LIST];
  if (PROJECT_ROOT === '.') {
    ignoreList.push('.github');
  }
  
  // Add non-existent folders to ignore list
  for (const folder of folders) {
    if (!folderExists(folder)) {
      ignoreList.push(folder);
    }
  }
  
  const validFolders = [];
  for (const folder of folders) {
    if (!ignoreList.includes(folder) && folderExists(folder)) {
      if (PROJECT_ROOT === '.') {
        validFolders.push(folder);
      } else {
        validFolders.push(folder.replace(PROJECT_ROOT + '/', ''));
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

