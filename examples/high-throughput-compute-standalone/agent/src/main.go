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
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/gcp"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/serve"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/stats"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/test"
	"github.com/spf13/cobra"
)

// Description of CLI tool
const LONG_DESCRIPTION = `
A comprehensive example of many of the ways compute can be orchestrated
on Google Cloud Platform.
`

func main() {

	// Setup context and cancellation
	ctxt, cancel := context.WithCancel(context.Background())

	// Handle ctrl-C / interrupt
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	cleanup_seconds := 15
	go func() {

		// For each time ctrl-C is run
		for range c {

			// If already shutting down, stop immediately
			if ctxt.Err() != nil {
				slog.Warn("Forcibly exiting on second interrupt during shutdown.")
				os.Exit(1)
			}

			// Shutdown gracefully
			slog.Info("Shutting down")

			// Cancel the main context
			cancel()

			// Start monitoring for a forceful shutdown in the background
			go func() {
				slog.Info(fmt.Sprintf("Waiting %d seconds before exiting forcibly.", cleanup_seconds))
				time.Sleep(time.Second * time.Duration(cleanup_seconds))
				slog.Warn(fmt.Sprintf("Waited %d seconds. Forcibly exiting.", cleanup_seconds))
				os.Exit(1)
			}()
		}
	}()

	//
	// Main CLI
	//
	var statsCfg stats.StatsConfig
	var google gcp.GoogleConfig
	rootCmd := &cobra.Command{
		Use:          "agent",
		Short:        "agent is an example of running compute on GCP",
		Long:         LONG_DESCRIPTION,
		SilenceUsage: true,
	}

	// Capture statistics and logging flags
	statsCfg.Initialize(rootCmd, cancel)

	// Capture Google interaction flags
	google.Initialize(rootCmd)

	// Add test, serving, and default help commands and flags
	rootCmd.AddCommand(serve.AddServeCommands(&statsCfg, &google))
	rootCmd.AddCommand(test.AddTestCommands(&statsCfg, &google))

	// Initialize default Cobra flags
	rootCmd.InitDefaultHelpCmd()
	rootCmd.InitDefaultHelpFlag()
	rootCmd.CompletionOptions.HiddenDefaultCmd = true

	// Capture any extra arguments from a special environment variable
	args := os.Args[1:]
	keyValue, ok := os.LookupEnv("HTCAGENT_EXTRA_ARGS")
	if ok {
		args = append(args, strings.Split(keyValue, ",")...)
	}

	// Execute and shutdown quickly on error
	rootCmd.SetArgs(args)
	if err := rootCmd.ExecuteContext(ctxt); err != nil {
		slog.Error("error running", "error", err)
		os.Exit(1)
	}

	// Shutdown stats and Google (Open Telemetry)
	statsCfg.Stop()
	_ = google.Stop(context.Background())

	// See if there was a shutdown due to error
	if context.Cause(ctxt) != nil && context.Cause(ctxt) != context.Canceled {
		slog.Error("Shutdown due to error", "error", context.Cause(ctxt))
		os.Exit(1)
	}

	os.Exit(0)
}
