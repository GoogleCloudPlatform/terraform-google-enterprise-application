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

package gcp

import (
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"cloud.google.com/go/storage"
	"google.golang.org/api/option"
)

func (cfg *GoogleConfig) NewStorageClient(ctxt context.Context) (*storage.Client, error) {
	return storage.NewClient(ctxt, option.WithUserAgent(
		"cloud-solutions/fsi-rdp-agent-v1.0.0"))
}

type gzipReadWrapper struct {
	greader *gzip.Reader
	reader  io.ReadCloser
}

func (r gzipReadWrapper) Read(p []byte) (int, error) {
	return r.greader.Read(p)
}

func (r gzipReadWrapper) Close() error {
	errGzip := r.greader.Close()
	errReader := r.reader.Close()
	if errGzip != nil {
		if errReader != nil {
			slog.Warn("gzipReadWrapper: underlying reader also failed to close", "underlyingError", errReader.Error(), "primaryError", errGzip.Error())
		}
		return errGzip
	}
	return errReader
}

var gsPattern = regexp.MustCompile(`^gs://([^/]+)/(.*)$`)

func (cfg *GoogleConfig) OpenReader(ctxt context.Context, file string) (io.ReadCloser, error) {

	// ReadCloser
	var r io.ReadCloser

	// if starts with gs://, then open an object instead.
	gs_match := gsPattern.FindStringSubmatch(file)
	if gs_match != nil {
		client, err := cfg.NewStorageClient(ctxt)
		if err != nil {
			return nil, fmt.Errorf("opening creating GCS client: %w", err)
		}
		f, err := client.Bucket(gs_match[1]).Object(gs_match[2]).NewReader(ctxt)
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

	// If it ends in .gz, filter with gzip
	if strings.HasSuffix(file, ".gz") {
		greader, err := gzip.NewReader(io.ReadCloser(r))
		if err != nil {
			return nil, err
		}
		r = gzipReadWrapper{
			greader: greader,
			reader:  r,
		}
	}

	return r, nil
}

type gzipWriteWrapper struct {
	gwriter *gzip.Writer
	writer  io.WriteCloser
}

func (r gzipWriteWrapper) Write(p []byte) (int, error) {
	return r.gwriter.Write(p)
}

func (r gzipWriteWrapper) Close() error {
	errGzip := r.gwriter.Close()
	errWriter := r.writer.Close()
	if errGzip != nil {
		if errWriter != nil {
			slog.Warn("gzipWriteWrapper: underlying writer also failed to close", "underlyingError", errWriter.Error(), "primaryError", errGzip.Error())
		}
		return errGzip
	}
	return errWriter
}

func (cfg *GoogleConfig) CreateWriter(ctxt context.Context, file string) (io.WriteCloser, error) {

	var w io.WriteCloser

	// if starts with gs://, then open an object instead.
	gs_match := gsPattern.FindStringSubmatch(file)
	if gs_match != nil {
		client, err := cfg.NewStorageClient(ctxt)
		if err != nil {
			return nil, fmt.Errorf("opening creating GCS client: %w", err)
		}
		slog.Debug("Opening GCS for writing", "bucket", gs_match[1], "object", gs_match[2])
		o := client.Bucket(gs_match[1]).Object(gs_match[2]).NewWriter(ctxt)
		w = o
	} else {
		err := os.MkdirAll(filepath.Dir(file), 0750)
		if err != nil {
			return nil, fmt.Errorf("error creating directory %s: %w", filepath.Dir(file), err)
		}

		slog.Debug("Opening file for writing", "file", file)
		o, err := os.Create(file)
		if err != nil {
			return nil, fmt.Errorf("error opening file %s for writing: %w", file, err)
		}
		w = o
	}

	if strings.HasSuffix(file, ".gz") {
		w = gzipWriteWrapper{gwriter: gzip.NewWriter(w), writer: w}
	}

	return w, nil
}
