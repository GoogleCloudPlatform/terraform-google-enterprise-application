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

package serve

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"

	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/protoio"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/stats"
	"github.com/spf13/cobra"
)

type contextKey string

const srcIDKey contextKey = "srcId"

func getRDFCommand(cfg *protoio.BackendConfiguration, stats *stats.StatsConfig) *cobra.Command {
	grpcCmd := &cobra.Command{
		Use:   "rdf",
		Short: "BigQuery RDF Server",
		Long:  "BigQuery RDF Server (port comes from PORT environment variable or 8080)",
		Args:  cobra.ExactArgs(0),
		RunE: func(cmd *cobra.Command, args []string) error {
			invoker, err := cfg.GetInvoker(cmd.Context(), stats, true, true)
			if err != nil {
				return err
			}

			return handleBigQuery(cmd.Context(), invoker)
		},
	}

	return grpcCmd
}

type BigQueryRDFRequest struct {
	RequestId          string              `json:"requestId"`
	Caller             string              `json:"caller"`
	SessionUser        string              `json:"sessionUser"`
	UserDefinedContext map[string]string   `json:"userDefinedContext"`
	Calls              [][]json.RawMessage `json:"calls"`
}

type BigQueryRDFResponse struct {
	Replies      []*json.RawMessage `json:"replies,omitempty"`
	ErrorMessage string             `json:"errorMessage,omitempty"`
}

func handleBigQuery(ctxt context.Context, invoker func(context.Context, []byte) ([]byte, error)) error {

	// Handler for BigQuery RDF
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {

		// Read message
		body, err := io.ReadAll(r.Body)
		if err != nil {
			slog.Warn("Error reading HTTP request", "error", err)
			http.Error(w, fmt.Sprintf("io.ReadAll: %v", err), http.StatusBadRequest)
			return
		}

		// Decode message
		var m BigQueryRDFRequest
		if err := json.Unmarshal(body, &m); err != nil {
			slog.Warn("Error json unmarshal", "error", err)
			http.Error(w, fmt.Sprintf("json.Unmarshal: %v", err), http.StatusBadRequest)
			return
		}

		slog.Debug("Reading message", "rdfrequest", m)

		// Call the routine serially
		result := &BigQueryRDFResponse{}
		result.Replies = make([]*json.RawMessage, len(m.Calls))
		for i, callData := range m.Calls {
			slog.Debug("Running on backend as JSON", "json", string(callData[0]))
			requestCtx := context.WithValue(ctxt, srcIDKey, m.RequestId)
			reply, err := invoker(
				requestCtx,
				callData[0])

			if err != nil {
				slog.Warn("Error running on backend", "error", err)
				result.ErrorMessage = fmt.Sprintf("error calling backend: %v", err)
				break
			}

			result.Replies[i] = (*json.RawMessage)(&reply)
		}

		// Send back the response
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)

		slog.Debug("Returning message", "json", result)
		b, err := json.Marshal(result)
		if err != nil {
			slog.Warn("Error marshing response", "error", err)
		} else {
			slog.Debug("Returning", "encoded", b)
		}
		if err := json.NewEncoder(w).Encode(result); err != nil {
			slog.Warn("Error encoding response", "error", err)
		}
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Start HTTP server.
	srv := &http.Server{
		Addr: ":" + port,
	}
	go func() {
		<-ctxt.Done()
		slog.Info("Shutting down HTTP Server")
		if err := srv.Shutdown(context.Background()); err != nil {
			slog.Warn("Error shutting down HTTP Server", "error", err)
		}
	}()

	slog.Info("Listening on port", "port", port)
	err := srv.ListenAndServe()
	if err != nil && err != http.ErrServerClosed {
		return fmt.Errorf("error listening: %w", err)
	}

	return nil
}
