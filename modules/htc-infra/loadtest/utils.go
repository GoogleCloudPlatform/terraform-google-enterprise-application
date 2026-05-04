// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bufio"
	"compress/gzip"
	"context"
	crand "crypto/rand"
	"fmt"
	"io"
	"io/fs"
	"iter"
	"log/slog"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"cloud.google.com/go/storage"
	"github.com/schollz/progressbar/v3"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
)

// Run the work, applied to a sequence, with a pool of parallel workers.
//
// The first error will stop the processing of new work, and, once the workers
// are all finished, the first non-nil error is returned.
//
// If there are no errors nil is returned.
func ApplyParallel[V any](seq iter.Seq[V], workers int, work func(v V) error) (err error) {
	err = nil

	if workers <= 0 {
		workers = runtime.NumCPU()
	}

	err_ch := make(chan error, workers)

	working := 0

	for v := range seq {

		// If at limit, pull an error first.
		if working == workers {
			last_err := <-err_ch
			if last_err != nil {
				working--
				err = last_err
				break
			}
		} else {
			working++
		}

		// Dispatch the work
		go func() {
			err_ch <- work(v)
		}()
	}

	for working > 0 {
		last_err := <-err_ch
		working--
		if last_err != nil && err == nil {
			err = last_err
		}
	}

	return
}

// An extension of ApplyParallel, except with a totalWork metric and workFunc needs to return
// the portion of work done as well as error.
//
// A Progress bar is shown if totalWork is > 0. Statistics are logged with elapsed time, total elapsed time (across all workers),
// and overall statistics.
func ApplyParallelWithStats[V any](seq iter.Seq[V], workers int, totalWork int64, workFunc func(v V) (int64, error)) (err error) {

	// Progress bar
	var bar *progressbar.ProgressBar
	if totalWork > 0 {
		bar = progressbar.DefaultBytes(totalWork)
		defer func() {
			if err := bar.Clear(); err != nil {
				slog.Warn("progressbar Clear() error", "error", err)
			}
		}()
	}

	startTime := time.Now()
	ioTime := atomic.Int64{}
	ops := atomic.Int64{}
	work := atomic.Int64{}

	err = ApplyParallel(seq, workers, func(v V) error {
		startOpTime := time.Now()
		thiswork, err := workFunc(v)
		ioTime.Add(time.Since(startOpTime).Nanoseconds())
		work.Add(thiswork)
		ops.Add(1)
		if totalWork > 0 {
			if err := bar.Add64(thiswork); err != nil {
				slog.Warn("progress bar Add64() error", "error", err)
			}
		}
		return err
	})
	elapsedTime := float64(time.Since(startTime).Nanoseconds()) / 1e9
	totalElapsedTime := float64(ioTime.Load()) / 1e9

	slog.Info("statistics", "count", ops.Load(), "total", work.Load(), "parallel", workers, "seconds", elapsedTime, "ioseconds", totalElapsedTime, "error", err)

	return err
}

// WriteLines writes the iterator of strings to the output. It appends newline to the end of each line.
//
// output can be "-" for standard out, and if the output ends with .gz the output will be compressed with gzip.
func WriteLines(output string, it iter.Seq[string]) error {

	var w io.Writer
	if output == "-" {
		w = os.Stdout
	} else {

		if err := MkdirAll(path.Dir(output)); err != nil {
			return fmt.Errorf("failed making directory: %v", err)
		}

		f, err := CreateWriter(output)
		if err != nil {
			return fmt.Errorf("error creating: %v", err)
		}

		defer func() {
			if err := f.Close(); err != nil {
				fmt.Printf("Error closing file: %v", err)
			}
		}()

		w = f

		if strings.HasSuffix(output, ".gz") {
			gf := gzip.NewWriter(f)
			defer func() {
				if err := gf.Close(); err != nil {
					fmt.Printf("Error closing file: %v", err)
				}
			}()
			w = gf
		}
	}

	for line := range it {
		_, err := w.Write([]byte(line))
		if err != nil {
			return fmt.Errorf("error writing: %v", err)
		}
		_, err = w.Write([]byte("\n"))
		if err != nil {
			return fmt.Errorf("error writing: %v", err)
		}
	}

	return nil
}

// ReadLines returns an iterator of lines (including the newline) from input.
//
// Input can be "-" for standard in and if the input ends with .gz it is uncompressed.
func ReadLines(input string) iter.Seq2[string, error] {
	return func(yield func(string, error) bool) {
		slog.Info("Opening file", "input", input)
		var r io.Reader
		if input == "-" {
			r = os.Stdin
		} else {
			file, err := OpenReader(input)
			if err != nil {
				yield("", fmt.Errorf("error opening %s: %w", input, err))
				return
			}
			r = file

			defer func() {
				if err := file.Close(); err != nil {
					fmt.Printf("Error closing file: %v", err)
				}
			}()

			if strings.HasSuffix(input, ".gz") {
				file, err := gzip.NewReader(file)
				if err != nil {
					yield("", err)
					return
				}

				defer func() {
					if err := file.Close(); err != nil {
						fmt.Printf("Error closing file: %v", err)
					}
				}()

				r = file
			}
		}

		// Start scanner
		scanner := bufio.NewScanner(r)
		for scanner.Scan() {
			if !yield(scanner.Text(), nil) {
				return
			}
		}

		if err := scanner.Err(); err != nil {
			yield("", err)
		}
	}
}

func ReadBytesFromDir(dir string) (int64, int64, error) {
	slog.Debug("Reading directory", "dir", dir)

	totalBytes := int64(0)
	totalFiles := int64(0)

	err := WalkDirFiles(dir, false, func(path string, size int64) error {
		slog.Debug("Handling path", "path", path)
		cnt, err := ReadBytes(path)
		if err != nil {
			return err
		}
		totalBytes += cnt
		totalFiles += 1
		return nil
	})

	return totalFiles, totalBytes, err
}

const bufferSize = 1024 * 1024

// Utility to get the storage client (caching)
var storageClient = sync.OnceValues(func() (*storage.Client, error) {
	return storage.NewClient(context.Background(), option.WithUserAgent(
		"cloud-solutions/fsi-rdp-loadtest-v1.0.0"))
})

var gsPattern = regexp.MustCompile(`^gs://([^/]+)/(.*)$`)

// Mkdir skips for gs:// outputs
func MkdirAll(path string) error {
	gs_match := gsPattern.FindStringSubmatch(path)
	if gs_match != nil {
		return nil
	}

	return os.MkdirAll(path, 0750)
}

// Join paths together, but handles gs:// prefixes
func Join(path1 string, path2 string) string {
	if strings.HasPrefix(path1, "gs://") {
		if !strings.HasSuffix(path1, "/") {
			return path1 + "/" + path2
		} else {
			return path1 + path2
		}
	}
	return filepath.Join(path1, path2)
}

// WalkDirFiles handles local files or gs:// buckets and objects
func WalkDirFiles(dir string, includeSize bool, handle func(file string, size int64) error) error {
	gs_match := gsPattern.FindStringSubmatch(dir)
	if gs_match != nil {
		client, err := storageClient()
		if err != nil {
			return fmt.Errorf("opening creating GCS client: %w", err)
		}
		if !strings.HasSuffix(gs_match[2], "/") {
			gs_match[2] = gs_match[2] + "/"
		}
		slog.Debug("listing GCS objects", "bucket", gs_match[1], "prefix", gs_match[2])
		it := client.Bucket(gs_match[1]).Objects(context.Background(), &storage.Query{
			Prefix:     gs_match[2],
			Versions:   false,
			Projection: storage.ProjectionNoACL})
		for {
			attrs, err := it.Next()
			if err == iterator.Done {
				break
			}
			if err != nil {
				return fmt.Errorf("listing objects in path %s: %w", dir, err)
			}
			if err := handle(fmt.Sprintf("gs://%s/%s", attrs.Bucket, attrs.Name), attrs.Size); err != nil {
				return err
			}
		}
		return nil
	}

	return filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		slog.Debug("Handling path", "path", path, "d", d, "err", err)
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		size := int64(0)
		if includeSize {
			info, err := d.Info()
			if err != nil {
				return err
			}
			size = info.Size()
		}
		if err := handle(path, size); err != nil {
			return err
		}
		return nil
	})
}

// Open a reader from local POSIX or from GCS
func OpenReader(file string) (io.ReadCloser, error) {

	// ReadCloser
	var r io.ReadCloser

	// if starts with gs://, then open an object instead.
	gs_match := gsPattern.FindStringSubmatch(file)
	if gs_match != nil {
		client, err := storageClient()
		if err != nil {
			return nil, fmt.Errorf("opening creating GCS client: %w", err)
		}
		f, err := client.Bucket(gs_match[1]).Object(gs_match[2]).NewReader(context.Background())
		if err != nil {
			return nil, fmt.Errorf("reading GCS object: %w", err)
		}
		r = f
	} else {
		// Open normal file
		f, err := os.Open(file)
		if err != nil {
			return nil, fmt.Errorf("opening file %s: %w", file, err)
		}
		r = f
	}

	return r, nil
}

// Open a writer to local POSIX or to GCS
func CreateWriter(file string) (io.WriteCloser, error) {
	// if starts with gs://, then open an object instead.
	gs_match := gsPattern.FindStringSubmatch(file)
	if gs_match != nil {
		client, err := storageClient()
		if err != nil {
			return nil, fmt.Errorf("opening creating GCS client: %w", err)
		}
		slog.Debug("Opening GCS for writing", "bucket", gs_match[1], "object", gs_match[2])
		o := client.Bucket(gs_match[1]).Object(gs_match[2]).NewWriter(context.Background())
		return o, nil
	} else {
		err := MkdirAll(filepath.Dir(file))
		if err != nil {
			return nil, fmt.Errorf("error creating directory %s: %w", filepath.Dir(file), err)
		}

		slog.Debug("Opening file for writing", "file", file)
		o, err := os.Create(file)
		if err != nil {
			return nil, fmt.Errorf("error opening file %s for writing: %w", file, err)
		}
		return o, nil
	}
}

// Read file and return the bytes read and error
func ReadBytes(file string) (int64, error) {
	slog.Debug("Reading", "file", file)
	f, err := OpenReader(file)
	if err != nil {
		return 0, err
	}
	buf := make([]byte, bufferSize)
	var bytesRead int64 = 0
	for {
		r, err := f.Read(buf)
		bytesRead += int64(r)
		if err != nil {
			if err == io.EOF {
				break
			}
			return bytesRead, err
		}
	}
	if err := f.Close(); err != nil {
		return bytesRead, err
	}

	return bytesRead, nil
}

// Write random data to file, of size bytes, and return bytes written and error
func WriteBytes(file string, size int64) (int64, error) {
	slog.Debug("Writing", "file", file, "size", size)

	f, err := CreateWriter(file)
	if err != nil {
		return 0, err
	}

	sizeLeft := size

	buf := make([]byte, bufferSize)
	for sizeLeft > 0 {

		// Adjust size of buffer if nearly complete
		if len(buf) > int(sizeLeft) {
			buf = buf[:sizeLeft]
		}

		// Read in random data
		_, err := crand.Read(buf)
		if err != nil {
			return size - sizeLeft, fmt.Errorf("failed generating random bytes")
		}

		// Write random data to output file
		s, err := f.Write(buf)
		if err != nil {
			return size - sizeLeft, fmt.Errorf("failed writing")
		}

		sizeLeft -= int64(s)
	}

	// Close file
	if err := f.Close(); err != nil {
		return size, err
	}

	return size, nil
}

/*
 * Utility for limiting the number of concurrent workers
 */

type workCounter struct {
	maxWorkers     int        //  Maximum number of workers
	currentWorkers int        // Current number of workers
	workerLock     *sync.Cond // Mutex condition for releasing when free
}

// NewWorkerCounter creates a work counter limiting to maxWorkers
func NewWorkerCounter(maxWorkers int) *workCounter {
	return &workCounter{
		maxWorkers:     maxWorkers,
		currentWorkers: 0,
		workerLock:     sync.NewCond(&sync.Mutex{}),
	}
}

// Acquire a free worker slot.
//
// Will return immediately if available,
// otherwise will block until one is free.
//
// Workers should Acquire and Release within the function:
// w.Acquire()
// defer w.Release()
func (w *workCounter) Acquire() {
	w.workerLock.L.Lock()
	for w.currentWorkers >= w.maxWorkers {
		w.workerLock.Wait()
	}
	w.currentWorkers++
	w.workerLock.L.Unlock()
}

// Release worker slot.
//
// Will let another worker proceed if one is blocked in Acquire().
func (w *workCounter) Release() {
	w.workerLock.L.Lock()
	w.currentWorkers--
	w.workerLock.Signal()
	w.workerLock.L.Unlock()
}
