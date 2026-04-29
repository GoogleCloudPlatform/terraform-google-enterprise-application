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
	"hash/crc32"
	"log/slog"
	"math/rand"
	"os"
	"path"
	"sync"
	"time"

	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
)

/*
 * Utility for turning a protobuf into a JSON using structured logging
 */

type loggableProto struct {
	msg proto.Message
}

// String() turns it into a String
func (p loggableProto) String() string {
	x, err := protojson.Marshal(p.msg)
	if err != nil {
		return string(x)
	} else {
		return ""
	}
}

// For slog, MarshalJSON is used to bridge into protobuf's JSON marshaler
func (p loggableProto) MarshalJSON() ([]byte, error) {
	return protojson.Marshal(p.msg)
}

/*
 * General simulator code
 */

// Run Quant Library
func RunLoadTask(task *LoadTask, hostname string) (*LoadResult, error) {
	slog.Debug("Running LoadTask", "task", loggableProto{task})

	// Initialize (if needed)
	initStatus, err := initialize(task.Init)
	if err != nil {
		slog.Debug("Error initializing", "err", err)
		return nil, fmt.Errorf("error initializing: %w", err)
	}

	// Run work
	taskStatus, err := runWork(task.Task, "task")
	if err != nil {
		slog.Debug("Error performing task", "err", err)
		return nil, fmt.Errorf("error performing task: %w", err)
	}

	// Assemble response
	response := &LoadResult{
		Init: initStatus,
		Task: taskStatus,
		Host: hostname,
	}

	slog.Debug("LoadResult", "result", loggableProto{response})

	return response, nil
}

// Mutex for the initialization.
var initialMu sync.Mutex
var initialId int64 = -1

// initialize
//
// Run the task during initialization.
func initialize(compute_task *LoadTask_Task) (*LoadResult_Status, error) {

	if compute_task == nil {
		return &LoadResult_Status{}, nil
	}

	// Only run once per thread (regardless of workers)
	initialMu.Lock()
	defer initialMu.Unlock()

	// Initialize if needed
	if compute_task.Id != initialId {
		slog.Info("Initializing", "id", compute_task.Id)
		status, err := runWork(compute_task, "init")
		if err != nil {
			return nil, err
		}

		initialId = compute_task.Id

		return status, nil
	}

	// Return no stats -- acknowledging already initialized
	return &LoadResult_Status{
		Id: compute_task.Id,
	}, nil
}

// runWork
//
// Run the specific task (whether an init or normal task), returning the status and
// any error.
//
// This will include all compute, read, and write tasks.
func runWork(task *LoadTask_Task, worktype string) (*LoadResult_Status, error) {

	slog.Debug("Running QuantTask", "task", loggableProto{task})

	// If there is no task, empty status is enough
	if task == nil {
		return &LoadResult_Status{}, nil
	}

	// Capture total micros (internal) time spent
	startTime := time.Now()

	var err error
	var bytesRead int64 = 0
	var filesRead int64 = 0

	// Read files if needed
	if task.GetReadDir() != "" {
		dirFilesRead, dirBytesRead, err := ReadBytesFromDir(task.GetReadDir())
		if err != nil {
			return nil, err
		}
		bytesRead += dirBytesRead
		filesRead += dirFilesRead
	}

	// Read file if needed
	if task.GetReadFile() != "" {
		fileBytesRead, err := ReadBytes(task.GetReadFile())
		if err != nil {
			return nil, err
		}
		bytesRead += fileBytesRead
		filesRead += 1
	}

	// Simulate work
	computeMicros, status := simulateWork(
		task.GetPercCrash(),
		task.GetPercFail(),
		task.GetMinMicros(),
		task.GetMaxMicros())

	// Write file if needed
	var bytesWritten int64 = 0
	if task.GetWriteFile() != "" {

		// Create directory if not existing
		if err := os.MkdirAll(path.Dir(task.GetWriteFile()), 0750); err != nil {
			return nil, err
		}

		// Write file
		bytesWritten, err = WriteBytes(task.GetWriteFile(), task.GetWriteBytes())
		if err != nil {
			return nil, err
		}
	}

	// Create the payload
	payload := make([]byte, task.ResultSize)
	if _, err = crand.Read(payload); err != nil {
		return nil, err
	}

	totalMicros := time.Since(startTime).Microseconds()

	// Create the result
	r := &LoadResult_Status{
		Id:            task.Id,
		Payload:       payload,
		ComputeMicros: computeMicros,
		TotalMicros:   totalMicros,
		FilesRead:     filesRead,
		BytesRead:     bytesRead,
		BytesWritten:  bytesWritten,
	}

	// Record work executed
	slog.Info("work executed",
		"id", task.Id,
		"worktype", worktype,
		"computeMicros", computeMicros,
		"totalMicros", totalMicros,
		"filesRead", filesRead,
		"bytesRead", bytesRead,
		"bytesWritten", bytesWritten,
	)

	slog.Debug("Returning QuantResult", "result", loggableProto{r})

	return r, status
}

// simulateWork
//
// Crash (exit immediately) and fail (with error) have a percentage likelihood,
// min_micros to max_micros will determine how much (randomly) will have 100%
// CPU consumed.
//
// Number of microseconds consumed and error (based on perc_fail) returned.
func simulateWork(
	perc_crash float64,
	perc_fail float64,
	min_micros int64,
	max_micros int64) (int64, error) {

	// Calculate the delay
	var busyTime int64
	if min_micros > 0 {
		busyTime = min_micros
		if max_micros > min_micros {
			busyTime += int64(rand.Float64() * float64(max_micros-min_micros))
		}
		slog.Debug("Working", "min_micros", min_micros, "max_micros", max_micros, "busyTime", busyTime)
		if err := busyWork(busyTime); err != nil {
			return 0, err
		}
	}

	// Status of the job
	status := rand.Float64()

	// Crash if needed
	if status < perc_crash {
		slog.Warn("Crashing.")
		os.Exit(100)
	}

	if status < perc_crash+perc_fail {
		return busyTime, fmt.Errorf("job failed")
	}

	return busyTime, nil
}

// busyWork
//
// Consume 100% available CPU until the alloted micros has elapsed.
//
// Error should generally never occur.
func busyWork(micros int64) error {
	h := crc32.NewIEEE()
	endTime := time.Now().Add(time.Microsecond * time.Duration(micros))
	buf := make([]byte, 32)

	// Loop as long as the current time is NOT after endTime
	for !time.Now().After(endTime) {
		// Read in random data
		_, err := crand.Read(buf)
		if err != nil {
			return fmt.Errorf("failed reading random bytes: %w", err)
		}

		// Write random data to hash function
		_, err = h.Write(buf)
		if err != nil {
			return fmt.Errorf("failed writing to hash: %w", err)
		}
	}

	return nil
}
