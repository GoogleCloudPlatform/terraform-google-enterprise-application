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
	"fmt"
	"log/slog"
	"os"

	"context"
	"net"

	"cloud.google.com/go/compute/metadata"
	"github.com/spf13/cobra"
	grpc "google.golang.org/grpc"
	"google.golang.org/grpc/health"
	"google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
	"google.golang.org/protobuf/encoding/protojson"
)

/*
 * Generate the request / response proto code and gRPC bindings
 */

//go:generate protoc -I. --go-grpc_out=. --go-grpc_opt=paths=source_relative service.proto
//go:generate protoc -I. --go_out=. --go_opt=paths=source_relative service.proto request.proto response.proto

/*
 * gRPC Service
 */

type LoadTestServer struct {
	UnimplementedLoadTestServiceServer

	cnt      *workCounter
	hostname string
}

func NewLoadTestServer(maxWorkers int, hostname string) *LoadTestServer {
	return &LoadTestServer{
		cnt: NewWorkerCounter(maxWorkers),
	}
}

func (q *LoadTestServer) RunLibrary(ctx context.Context, in *LoadTask) (*LoadResult, error) {

	// Limit the number of workers that can run
	q.cnt.Acquire()
	defer q.cnt.Release()

	return RunLoadTask(in, q.hostname)
}

/*
 * Command line utility
 */

const LONG_DESCRIPTION = `
Loadtest is an HTC workload that performs simulated work for test purposes.
`

func main() {

	// Root command
	var debug bool
	var logJson bool
	var numWorkers int
	rootCmd := &cobra.Command{
		Use:   "loadtest",
		Short: "loadtest is an gRPC test harness for testing HTC compute on GCP",
		Long:  LONG_DESCRIPTION,

		// Run before all subcommands
		PersistentPreRun: func(cmd *cobra.Command, args []string) {

			// Log JSON if requested
			if logJson {
				slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
			}

			// Enable debug if requested
			if debug {
				slog.SetLogLoggerLevel(slog.LevelDebug)
				slog.Info("Debug logging enabled")
			}
		},
	}
	rootCmd.PersistentFlags().IntVar(&numWorkers, "workers", 1, "Number of worker threads")
	rootCmd.PersistentFlags().BoolVar(&debug, "debug", false, "Enable debug logging")
	rootCmd.PersistentFlags().BoolVar(&logJson, "logJSON", false, "Enable JSON logging")

	// Run GRPC Server file command
	port := 2002
	serveCmd := &cobra.Command{
		Use:   "serve",
		Short: "Run gRPC service for simulating work",
		RunE: func(cmd *cobra.Command, args []string) error {

			// Find the hostname
			hostname, err := os.Hostname()
			if err != nil || hostname == "" || hostname == "localhost" {
				hostname, err = metadata.InstanceIDWithContext(context.Background())
				if err != nil {
					hostname = "localhost"
				}
			}

			// Listen to the port on all IP addresses
			lis, err := net.Listen("tcp", fmt.Sprintf("0.0.0.0:%d", port))
			if err != nil {
				return fmt.Errorf("failed to listen: %v", err)
			}

			// Create health check service.
			// This can be used to push back on too many tasks in the future.
			healthcheck := health.NewServer()
			healthcheck.SetServingStatus("", grpc_health_v1.HealthCheckResponse_SERVING)

			// Create server and register all services:
			// core service, health check, reflection
			s := grpc.NewServer()
			RegisterLoadTestServiceServer(s, NewLoadTestServer(numWorkers, hostname))
			grpc_health_v1.RegisterHealthServer(s, healthcheck)
			reflection.Register(s)

			// Start server
			slog.Info("Listening", "port", port, "hostname", hostname)
			if err := s.Serve(lis); err != nil {
				return fmt.Errorf("failed to serve: %v", err)
			}

			return nil
		},
	}
	serveCmd.Flags().IntVar(&port, "port", port, "Port for gRPC server")
	rootCmd.AddCommand(serveCmd)

	// Load file command
	rootCmd.AddCommand(&cobra.Command{
		Use:   "load <file>",
		Short: "Load JSONL files and execute directly",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			for line, err := range ReadLines(args[0]) {
				if err != nil {
					return err
				}

				task := &LoadTask{}
				if err := protojson.Unmarshal([]byte(line), task); err != nil {
					return fmt.Errorf("parsing json: %w", err)
				}
				response, err := RunLoadTask(task, "localhost")
				if err != nil {
					return fmt.Errorf("running quant: %w", err)
				}

				// Send output
				omsg, err := protojson.Marshal(response)
				if err != nil {
					return fmt.Errorf("running quant: %w", err)
				}

				if _, err := os.Stdout.Write(omsg); err != nil {
					fmt.Printf("warning: failed to write to stdout: %v", err)

				}
				if _, err := os.Stdout.Write([]byte{'\n'}); err != nil {
					fmt.Printf("warning: failed to write newline to stdout: %v", err)
				}
			}

			return nil
		},
	})

	// Add additional commands
	AddGenTasksCommand(rootCmd)
	AddReadDataCommand(rootCmd)
	AddWriteDataCommand(rootCmd)

	// Execute and shutdown quickly on error
	rootCmd.InitDefaultHelpCmd()
	rootCmd.InitDefaultHelpFlag()
	if err := rootCmd.Execute(); err != nil {
		slog.Error("error running", "error", err)
		os.Exit(1)
	}

	os.Exit(0)
}
