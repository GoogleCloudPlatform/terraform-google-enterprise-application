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
	crand "crypto/rand"
	"fmt"
	"log/slog"
	"math/rand"
	"slices"

	"github.com/spf13/cobra"
	"google.golang.org/protobuf/encoding/protojson"
)

/*
 * Add the command line for reading data in parallel
 */

func AddReadDataCommand(rootCmd *cobra.Command) {
	parallel := 20
	progress := true
	readData := &cobra.Command{
		Use:   "readdata <dir>",
		Short: "Read data recursively in a folder with parallel readers",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {

			// Find all files
			files := make([]string, 0, 100)
			var totalBytes int64
			err := WalkDirFiles(args[0], true, func(path string, size int64) error {
				files = append(files, path)
				totalBytes += size
				return nil
			})
			if err != nil {
				return err
			}

			// Info
			slog.Info("Reading data", "dir", args[0], "files", len(files), "bytes", totalBytes, "readers", parallel)

			// Suppress progress if requested
			if !progress {
				totalBytes = 0
			}

			return ApplyParallelWithStats(slices.Values(files), parallel, totalBytes, ReadBytes)
		},
	}
	readData.Flags().BoolVar(&progress, "showProgress", progress, "Show progress")
	readData.Flags().IntVar(&parallel, "parallel", parallel, "Number of parallel readers")
	rootCmd.AddCommand(readData)
}

/*
 * Add the command line for writing data in parallel
 */

func AddWriteDataCommand(rootCmd *cobra.Command) {

	// Write data
	sizeBytes := int64(1024 * 1024)
	count := 100
	parallel := 2
	progress := true
	writeData := &cobra.Command{
		Use:   "writedata <dir>",
		Short: "Write data (file-<number>.bin) in a folder",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {

			// Create directory if not existing
			slog.Info("Making parent directory", "dir", args[0])
			if err := MkdirAll(args[0]); err != nil {
				return err
			}

			// File name generator
			slog.Info("Writing data", "count", count, "size", sizeBytes, "writers", parallel)
			files := func(yield func(string) bool) {
				for i := 0; i < count; i++ {
					if !yield(Join(args[0], fmt.Sprintf("file-%08d.bin", i+1))) {
						break
					}
				}
			}

			// Setup progress if requested
			totalProgress := int64(0)
			if progress {
				totalProgress = int64(count) * sizeBytes
			}

			return ApplyParallelWithStats(files, parallel, totalProgress, func(file string) (int64, error) {
				return WriteBytes(file, sizeBytes)
			})
		},
	}
	writeData.Flags().BoolVar(&progress, "showProgress", progress, "Show progress")
	writeData.Flags().IntVar(&parallel, "parallel", parallel, "Number of parallel writers")
	writeData.Flags().IntVar(&count, "count", count, "Number of files to write")
	writeData.Flags().Int64Var(&sizeBytes, "size", sizeBytes, "Size of files to write")
	rootCmd.AddCommand(writeData)
}

/*
 * Add the command line for generating tasks for load test (JSON formatted)
 */

func AddGenTasksCommand(rootCmd *cobra.Command) {

	// Generate Tasks file command
	percCrash := 0.0
	percFail := 0.0
	initMinMicros := int64(1_000_000)
	initMaxMicros := int64(1_000_000)
	minMicros := int64(100_000)
	maxMicros := int64(100_000)
	initReadDir := ""
	readDir := ""
	readFileDir := ""
	writeFileDir := ""
	writeBytes := int64(0)
	resultSize := int64(100)
	payloadSize := int64(100)
	count := 0
	genTasks := &cobra.Command{
		Use:   "gentasks dir",
		Short: "Generate JSON tasks for being distributed to the loadtest gRPC service",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {

			initialId := rand.Int31()

			// Generate data and convert to JSON
			slog.Info("Generating tasks", "count", count)
			data := func(yield func(string) bool) {
				for i := 0; i < count; i++ {
					buf := make([]byte, payloadSize)
					_, err := crand.Read(buf)
					if err != nil {
						slog.Warn("error generating payload", "error", err)
						return
					}

					// Calculate the read and write file (if a dir is specified)
					readFile := ""
					if readFileDir != "" {
						readFile = Join(readFileDir, fmt.Sprintf("file-%08d.bin", int64(i+1)))
					}
					writeFile := ""
					if writeFileDir != "" {
						writeFile = Join(writeFileDir, fmt.Sprintf("file-%08d.bin", int64(i+1)))
					}

					b, err := protojson.Marshal(&LoadTask{
						Init: &LoadTask_Task{
							Id:        int64(initialId),
							PercCrash: percCrash,
							PercFail:  percFail,
							MaxMicros: initMaxMicros,
							MinMicros: initMinMicros,
							ReadDir:   initReadDir,
						},
						Task: &LoadTask_Task{
							Id:         int64(i + 1),
							PercCrash:  percCrash,
							PercFail:   percFail,
							MaxMicros:  maxMicros,
							MinMicros:  minMicros,
							ReadDir:    readDir,
							ReadFile:   readFile,
							WriteFile:  writeFile,
							WriteBytes: writeBytes,
							ResultSize: resultSize,
							Payload:    buf,
						},
					})
					if err != nil {
						slog.Warn("error converting to JSON", "error", err)
						return
					}
					if !yield(string(b)) {
						break
					}
				}
			}

			return WriteLines(args[0], data)
		},
	}
	genTasks.Flags().Float64Var(&percCrash, "percCrash", percCrash, "Percentage likelihood of a crash")
	genTasks.Flags().Float64Var(&percFail, "percFail", percFail, "Percentage likelihood of a failure")
	genTasks.Flags().Int64Var(&initMinMicros, "initMinMicros", initMinMicros, "Initial minimum microsecond work")
	genTasks.Flags().Int64Var(&initMaxMicros, "initMaxMicros", initMaxMicros, "Initial maximum microsecond work")
	genTasks.Flags().Int64Var(&minMicros, "minMicros", minMicros, "Minimum microsecond work")
	genTasks.Flags().Int64Var(&maxMicros, "maxMicros", maxMicros, "Maximum microsecond work")
	genTasks.Flags().Int64Var(&resultSize, "resultSize", resultSize, "Result payload size in bytes")
	genTasks.Flags().Int64Var(&payloadSize, "payloadSize", payloadSize, "Payload size in bytes")
	genTasks.Flags().StringVar(&initReadDir, "initReadDir", initReadDir, "Initial read directory")
	genTasks.Flags().StringVar(&readDir, "readDir", readDir, "Read directory for task")
	genTasks.Flags().StringVar(&readFileDir, "readFileDir", readFileDir, "Read file prefix for task")
	genTasks.Flags().StringVar(&writeFileDir, "writeFileDir", writeFileDir, "Write file prefix for task")
	genTasks.Flags().Int64Var(&writeBytes, "writeBytes", writeBytes, "Write file size")
	genTasks.Flags().IntVar(&count, "count", count, "Count of records created")
	rootCmd.AddCommand(genTasks)
}
