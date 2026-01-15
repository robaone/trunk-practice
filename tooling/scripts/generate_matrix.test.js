#!/usr/bin/env node

/**
 * Unit tests for generate_matrix.js
 * 
 * Run with: npm test
 */

// Mock modules before importing the script
jest.mock('fs');
jest.mock('child_process');

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const {
  parseFileListForProjects,
  generateMatrix,
  getProjectsWithDependsFile,
  checkDependencies
} = require('./generate_matrix');

describe('generate_matrix.js', () => {
  const mockGitRoot = '/mock/repo';
  const mockProjectRoot = 'project';
  const mockProjectsPath = path.join(mockGitRoot, mockProjectRoot);

  beforeEach(() => {
    jest.clearAllMocks();
    // Reset environment variables
    delete process.env.PROJECT_ROOT;
    delete process.env.IGNORE_LIST;
    
    // Mock git rev-parse to return the mock git root
    execSync.mockImplementation((command) => {
      if (command === 'git rev-parse --show-toplevel') {
        return mockGitRoot;
      }
      return '';
    });
    
    // Default mock for fs.statSync - return directory for projects folder
    fs.statSync.mockImplementation((filePath) => {
      if (filePath === mockProjectsPath || filePath.startsWith(mockProjectsPath + '/')) {
        return { isDirectory: () => true };
      }
      return { isDirectory: () => false };
    });
  });

  describe('generateMatrix', () => {
    it('should generate matrix with root project and provided projects when includeRoot is true', () => {
      const projects = ['project1', 'project2'];
      const result = generateMatrix(projects, true);
      const parsed = JSON.parse(result);
      
      expect(parsed).toEqual({
        include: [
          { project: '.' },
          { project: 'project1' },
          { project: 'project2' }
        ]
      });
    });

    it('should generate matrix without root project when includeRoot is false', () => {
      const projects = ['project1', 'project2'];
      const result = generateMatrix(projects, false);
      const parsed = JSON.parse(result);
      
      expect(parsed).toEqual({
        include: [
          { project: 'project1' },
          { project: 'project2' }
        ]
      });
    });

    it('should generate matrix with only root when no projects provided and includeRoot is true', () => {
      const projects = [];
      const result = generateMatrix(projects, true);
      const parsed = JSON.parse(result);
      
      expect(parsed).toEqual({
        include: [{ project: '.' }]
      });
    });

    it('should generate empty matrix when no projects provided and includeRoot is false', () => {
      const projects = [];
      const result = generateMatrix(projects, false);
      const parsed = JSON.parse(result);
      
      expect(parsed).toEqual({
        include: []
      });
    });

    it('should handle single project with root', () => {
      const projects = ['single-project'];
      const result = generateMatrix(projects, true);
      const parsed = JSON.parse(result);
      
      expect(parsed.include).toHaveLength(2);
      expect(parsed.include[0]).toEqual({ project: '.' });
      expect(parsed.include[1]).toEqual({ project: 'single-project' });
    });

    it('should handle single project without root', () => {
      const projects = ['single-project'];
      const result = generateMatrix(projects, false);
      const parsed = JSON.parse(result);
      
      expect(parsed.include).toHaveLength(1);
      expect(parsed.include[0]).toEqual({ project: 'single-project' });
    });
  });

  describe('getProjectsWithDependsFile', () => {
    it('should return projects that have .depends file', () => {
      const mockFiles = ['project1', 'project2', 'project3'];
      const mockStats = {
        isDirectory: () => true
      };

      fs.statSync.mockReturnValue(mockStats);
      fs.readdirSync.mockReturnValue(mockFiles);
      fs.existsSync.mockImplementation((filePath) => {
        return filePath.includes('project1') || filePath.includes('project2');
      });

      const result = getProjectsWithDependsFile();
      
      expect(result).toEqual(['project1', 'project2']);
      expect(fs.readdirSync).toHaveBeenCalledWith(mockProjectsPath);
    });

    it('should return empty array when projects folder does not exist', () => {
      fs.readdirSync.mockImplementation(() => {
        const error = new Error('ENOENT');
        error.code = 'ENOENT';
        throw error;
      });

      const result = getProjectsWithDependsFile();
      
      expect(result).toEqual([]);
    });

    it('should return empty array when no projects have .depends file', () => {
      const mockFiles = ['project1', 'project2'];
      const mockStats = {
        isDirectory: () => true
      };

      fs.statSync.mockReturnValue(mockStats);
      fs.readdirSync.mockReturnValue(mockFiles);
      fs.existsSync.mockReturnValue(false);

      const result = getProjectsWithDependsFile();
      
      expect(result).toEqual([]);
    });

    it('should handle errors when reading projects folder', () => {
      const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
      
      fs.statSync.mockReturnValue({ isDirectory: () => true });
      fs.readdirSync.mockImplementation(() => {
        throw new Error('Permission denied');
      });

      const result = getProjectsWithDependsFile();
      
      expect(result).toEqual([]);
      expect(consoleErrorSpy).toHaveBeenCalledWith(
        'Error reading projects folder:',
        'Permission denied'
      );
      
      consoleErrorSpy.mockRestore();
    });
  });

  describe('checkDependencies', () => {
    it('should return projects triggered by file patterns in .depends', () => {
      const fileList = [
        'project/tooling/scripts/generate_matrix.js',
        'project/other-project/file.js'
      ];
      const projects = ['project1', 'project2'];
      
      // Mock .depends files
      fs.readFileSync.mockImplementation((filePath) => {
        if (filePath.includes('project1')) {
          return 'project/tooling/**\nproject/shared/**';
        }
        if (filePath.includes('project2')) {
          return 'project/other-project/**';
        }
        return '';
      });

      const result = checkDependencies(fileList, projects);
      
      expect(result).toContain('project1');
      expect(result).toContain('project2');
      expect(result.length).toBe(2);
    });

    it('should handle glob patterns correctly', () => {
      const fileList = [
        'project/shared/utils.js',
        'project/tooling/scripts/test.js'
      ];
      const projects = ['project1'];
      
      fs.readFileSync.mockReturnValue('project/shared/**\nproject/tooling/*.js');

      const result = checkDependencies(fileList, projects);
      
      expect(result).toContain('project1');
    });

    it('should handle single asterisk patterns', () => {
      const fileList = ['project/shared/file.js'];
      const projects = ['project1'];
      
      fs.readFileSync.mockReturnValue('project/shared/*.js');

      const result = checkDependencies(fileList, projects);
      
      expect(result).toContain('project1');
    });

    it('should handle double asterisk patterns', () => {
      const fileList = ['project/shared/nested/deep/file.js'];
      const projects = ['project1'];
      
      fs.readFileSync.mockReturnValue('project/shared/**');

      const result = checkDependencies(fileList, projects);
      
      expect(result).toContain('project1');
    });

    it('should return empty array when no dependencies match', () => {
      const fileList = ['project/unrelated/file.js'];
      const projects = ['project1'];
      
      fs.readFileSync.mockReturnValue('project/shared/**');

      const result = checkDependencies(fileList, projects);
      
      expect(result).toEqual([]);
    });

    it('should handle errors reading .depends files', () => {
      const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
      const fileList = ['project/file.js'];
      const projects = ['project1'];
      
      fs.readFileSync.mockImplementation(() => {
        throw new Error('File not found');
      });

      const result = checkDependencies(fileList, projects);
      
      expect(result).toEqual([]);
      expect(consoleErrorSpy).toHaveBeenCalledWith(
        'Error reading .depends file for project1:',
        'File not found'
      );
      
      consoleErrorSpy.mockRestore();
    });

    it('should handle empty .depends files', () => {
      const fileList = ['project/file.js'];
      const projects = ['project1'];
      
      fs.readFileSync.mockReturnValue('');

      const result = checkDependencies(fileList, projects);
      
      expect(result).toEqual([]);
    });

    it('should handle .depends files with blank lines', () => {
      const fileList = ['project/shared/file.js'];
      const projects = ['project1'];
      
      fs.readFileSync.mockReturnValue('project/shared/**\n\n\nproject/tooling/**');

      const result = checkDependencies(fileList, projects);
      
      expect(result).toContain('project1');
    });
  });

  describe('parseFileListForProjects', () => {
    beforeEach(() => {
      // Default mocks for folder existence
      fs.statSync.mockImplementation((folderPath) => {
        if (folderPath.includes('project1') || folderPath.includes('project2')) {
          return { isDirectory: () => true };
        }
        return { isDirectory: () => false };
      });
      
      fs.readdirSync.mockReturnValue([]);
      fs.existsSync.mockReturnValue(false);
    });

    it('should extract project folders from file paths', () => {
      const fileList = [
        'project/project1/file.js',
        'project/project2/file.js',
        'project/project1/another.js'
      ];

      const result = parseFileListForProjects(fileList);
      
      expect(result).toContain('project1');
      expect(result).toContain('project2');
    });

    it('should handle files in project root', () => {
      const fileList = [
        'project/project1/file.js',
        'project/README.md'
      ];

      const result = parseFileListForProjects(fileList);
      
      // Should only include project1, not root-level files
      expect(result).toContain('project1');
    });

    it('should include dependency-triggered projects', () => {
      const fileList = [
        'project/shared/common.js'
      ];
      
      fs.readdirSync.mockReturnValue(['project1']);
      fs.existsSync.mockImplementation((filePath) => {
        return filePath.includes('project1') && filePath.endsWith('.depends');
      });
      fs.readFileSync.mockReturnValue('project/shared/**');

      const result = parseFileListForProjects(fileList);
      
      expect(result).toContain('project1');
    });

    it('should filter out non-existent folders', () => {
      const fileList = [
        'project/nonexistent/file.js',
        'project/project1/file.js'
      ];
      
      fs.statSync.mockImplementation((folderPath) => {
        if (folderPath.includes('nonexistent')) {
          throw new Error('ENOENT');
        }
        if (folderPath.includes('project1')) {
          return { isDirectory: () => true };
        }
        return { isDirectory: () => false };
      });

      const result = parseFileListForProjects(fileList);
      
      expect(result).toContain('project1');
      expect(result).not.toContain('nonexistent');
    });

    it('should filter out ignored folders', () => {
      process.env.IGNORE_LIST = 'project1 project2';
      const fileList = [
        'project/project1/file.js',
        'project/project2/file.js',
        'project/project3/file.js'
      ];

      // Ensure folders exist (default mock should handle this, but be explicit)
      fs.readdirSync.mockReturnValue([]);
      // The default mock in beforeEach should make project/* folders exist
      // But ensure project3 specifically exists
      fs.statSync.mockImplementation((filePath) => {
        if (filePath === mockProjectsPath || filePath.startsWith(mockProjectsPath + '/')) {
          return { isDirectory: () => true };
        }
        return { isDirectory: () => false };
      });

      const result = parseFileListForProjects(fileList);
      
      expect(result).not.toContain('project1');
      expect(result).not.toContain('project2');
      expect(result).toContain('project3');
    });

    it('should always ignore .github folder when PROJECT_ROOT is "."', () => {
      process.env.PROJECT_ROOT = '.';
      const fileList = [
        '.github/workflows/test.yml',
        'project1/file.js'
      ];
      
      // Mock getProjectsWithDependsFile to return empty (no dependency projects)
      // When PROJECT_ROOT is '.', getProjectsWithDependsFile reads from git root
      fs.readdirSync.mockImplementation((dirPath) => {
        if (dirPath === mockGitRoot) {
          return [];
        }
        return [];
      });
      // Reset and set mock to handle paths for PROJECT_ROOT = '.'
      fs.statSync.mockReset();
      fs.statSync.mockImplementation((folderPath) => {
        // Normalize paths for comparison
        const normalized = path.normalize(String(folderPath));
        const project1FullPath = path.normalize(path.join(mockGitRoot, 'project1'));
        const githubFullPath = path.normalize(path.join(mockGitRoot, '.github'));
        const normalizedGitRoot = path.normalize(mockGitRoot);
        
        // Handle absolute paths (joined with git root) and relative paths
        if (normalized === project1FullPath || normalized === githubFullPath ||
            normalized === normalizedGitRoot || normalized === 'project1' || normalized === '.github' ||
            normalized.endsWith(path.sep + 'project1') || normalized.endsWith(path.sep + '.github')) {
          return { isDirectory: () => true };
        }
        return { isDirectory: () => false };
      });

      const result = parseFileListForProjects(fileList);
      
      expect(result).toContain('project1');
      expect(result).not.toContain('.github');
    });

    it('should handle PROJECT_ROOT environment variable', () => {
      process.env.PROJECT_ROOT = 'custom';
      const fileList = [
        'custom/project1/file.js'
      ];
      
      execSync.mockImplementation((command) => {
        if (command === 'git rev-parse --show-toplevel') {
          return mockGitRoot;
        }
        return '';
      });
      fs.readdirSync.mockReturnValue([]);
      fs.statSync.mockReset();
      fs.statSync.mockImplementation((folderPath) => {
        const strPath = String(folderPath);
        const customProject1Path = path.join(mockGitRoot, 'custom', 'project1');
        const customPath = path.join(mockGitRoot, 'custom');
        
        if (strPath === customProject1Path || strPath === customPath || strPath === mockGitRoot ||
            strPath.endsWith('/custom/project1') || strPath.endsWith('custom/project1') ||
            (strPath.includes('custom') && strPath.includes('project1'))) {
          return { isDirectory: () => true };
        }
        return { isDirectory: () => false };
      });

      const result = parseFileListForProjects(fileList);
      
      expect(result).toContain('project1');
    });

    it('should return empty array when no valid projects found', () => {
      const fileList = [
        'README.md',
        'package.json'
      ];

      const result = parseFileListForProjects(fileList);
      
      expect(result).toEqual([]);
    });

    it('should handle empty file list', () => {
      const fileList = [];

      const result = parseFileListForProjects(fileList);
      
      expect(result).toEqual([]);
    });

    it('should remove duplicate projects', () => {
      const fileList = [
        'project/project1/file1.js',
        'project/project1/file2.js',
        'project/shared/common.js'
      ];
      
      fs.readdirSync.mockReturnValue(['project1']);
      fs.existsSync.mockImplementation((filePath) => {
        return filePath.includes('project1') && filePath.endsWith('.depends');
      });
      fs.readFileSync.mockReturnValue('project/shared/**');

      const result = parseFileListForProjects(fileList);
      
      // project1 should only appear once even though it matches both directly and via dependency
      const project1Count = result.filter(p => p === 'project1').length;
      expect(project1Count).toBe(1);
    });
  });

  describe('integration scenarios', () => {
    it('should handle complex dependency scenario', () => {
      const fileList = [
        'project/shared/common.js',
        'project/tooling/scripts/generate_matrix.js',
        'project/project1/specific.js'
      ];
      
      fs.readdirSync.mockReturnValue(['project1', 'project2', 'project3']);
      fs.existsSync.mockImplementation((filePath) => {
        return filePath.includes('project1') || filePath.includes('project2');
      });
      fs.readFileSync.mockImplementation((filePath) => {
        if (filePath.includes('project1')) {
          return 'project/shared/**';
        }
        if (filePath.includes('project2')) {
          return 'project/tooling/**';
        }
        return '';
      });
      fs.statSync.mockImplementation((folderPath) => {
        if (folderPath.includes('project1') || folderPath.includes('project2') || folderPath.includes('project3')) {
          return { isDirectory: () => true };
        }
        return { isDirectory: () => false };
      });

      const result = parseFileListForProjects(fileList);
      
      // project1 should be included (direct match + dependency)
      // project2 should be included (dependency match)
      // project3 should not be included (no match)
      expect(result).toContain('project1');
      expect(result).toContain('project2');
      expect(result).not.toContain('project3');
    });
  });
});
