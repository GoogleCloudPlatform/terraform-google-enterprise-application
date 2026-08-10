// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package utils

import (
	"bytes"
	"io/fs"
	"os"
	"path/filepath"
)

const (
	TerraformTempDir  = ".terraform"
	TerraformLockFile = ".terraform.lock.hcl"
)

// CopyFile copies a single file from the src path to the dest path
func CopyFile(src string, dest string) error {
	s, err := os.Stat(src)
	if err != nil {
		return err
	}
	buf, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dest, buf, s.Mode())
}

// DeleteFile deletes a single file from the src path to the dest path
func DeleteFile(src string) error {
	_, err := os.Stat(src)
	if err != nil {
		return err
	}
	err = os.RemoveAll(src)
	return err
}

// CopyDirectory copies a directory and the files and directories under it. It will skip symbolic links
func CopyDirectory(src string, dest string) error {
	err := os.MkdirAll(dest, 0755)
	if err != nil {
		return err
	}
	files, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	for _, f := range files {
		if f.Name() == TerraformTempDir || f.Name() == TerraformLockFile {
			continue
		}
		if f.IsDir() {
			err = CopyDirectory(filepath.Join(src, f.Name()), filepath.Join(dest, f.Name()))
			if err != nil {
				return err
			}
		} else if !isSymlinkToDir(filepath.Join(src, f.Name())) {
			err = CopyFile(filepath.Join(src, f.Name()), filepath.Join(dest, f.Name()))
			if err != nil {
				return err
			}
		}
	}
	return nil
}

// isSymlinkToDir checks if the given path is a symbolic link
// AND if its resolved target is a valid directory.
func isSymlinkToDir(path string) bool {
	// 1. Verify if the file itself is a symlink using os.Lstat.
	// os.Lstat does NOT follow the symlink, returning info about the link itself.
	lstatInfo, err := os.Lstat(path)
	if err != nil {
		return false
	}

	// Check if the os.ModeSymlink bit is present.
	if lstatInfo.Mode()&os.ModeSymlink == 0 {
		// It's a regular file or directory, not a symlink.
		return false
	}

	// 2. Verify the target. os.Stat automatically follows the symlink.
	statInfo, err := os.Stat(path)
	if err != nil {
		// This commonly fails if the symlink is broken (target does not exist),
		// if there is a symlink loop, or due to permission denied (e.g., target is restricted).
		return false
	}

	// Return true only if the resolved target is a directory.
	return statInfo.IsDir()
}

// ReplaceStringInFile replaces a string in a file with a new value.
func ReplaceStringInFile(filename, old, new string) error {
	s, err := os.Stat(filename)
	f, err := os.ReadFile(filename)
	if err != nil {
		return err
	}
	return os.WriteFile(filename, bytes.Replace(f, []byte(old), []byte(new), -1), s.Mode())
}

// FindFiles find files with the given filename under the directory skipping terraform temp dir.
func FindFiles(dir, filename string) ([]string, error) {
	found := []string{}
	err := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if d.IsDir() && d.Name() == TerraformTempDir {
			return filepath.SkipDir
		}
		if d.Name() == filename {
			found = append(found, path)
		}
		return nil
	})
	return found, err
}

// FileExists check if a give file exists
func FileExists(filename string) (bool, error) {
	_, err := os.Stat(filename)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}
