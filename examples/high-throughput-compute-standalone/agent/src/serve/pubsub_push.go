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

	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/gcp"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/protoio"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/stats"
	"github.com/spf13/cobra"
)

func NewPubSubPushAgent(cfg *protoio.BackendConfiguration, stats *stats.StatsConfig, google *gcp.GoogleConfig) *cobra.Command {

	// PubSub push
	var jsonPubSub bool
	cmd := &cobra.Command{
		Use:   "pubsub-push topic-id",
		Short: "Cloud Run PubSub endpoint listener and publish worker",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			invoker, err := cfg.GetInvoker(cmd.Context(), stats, true, jsonPubSub)
			if err != nil {
				return err
			}
			return handlePubSubPushSubscription(cmd.Context(), invoker, google, args[0])
		},
	}
	cmd.Flags().BoolVar(
		&jsonPubSub,
		"jsonPubSub",
		true,
		"Enable JSON in Pub/Sub instead of byte-encoded protobuf")

	return cmd
}

func handlePubSubPushSubscription(
	ctxt context.Context,
	invoker func(context.Context, []byte) ([]byte, error),
	google *gcp.GoogleConfig,
	topic string) error {

	// Create client for publishing
	client, err := google.PubSubClient(ctxt)
	if err != nil {
		slog.Warn("error creating client", "error", err)
		return err
	}

	// Publishing topic
	top := client.TopicInProject(topic, google.ProjectID)

	// PubSubMessage is the payload of a Pub/Sub event.
	// See the documentation for more details:
	// https://cloud.google.com/pubsub/docs/reference/rest/v1/PubsubMessage
	type PubSubMessage struct {
		Message struct {
			Data       []byte            `json:"data,omitempty"`
			Attributes map[string]string `json:"attributes"`
			ID         string            `json:"messageId"`
		} `json:"message"`
		Subscription string `json:"subscription"`
	}

	// Handler for the push subscription
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {

		// Read message
		var m PubSubMessage
		body, err := io.ReadAll(r.Body)
		if err != nil {
			slog.Warn("error reading message", "error", err)
			http.Error(w, fmt.Sprintf("io.ReadAll: %v", err), http.StatusBadRequest)
			return
		}

		// byte slice unmarshalling handles base64 decoding.
		if err := json.Unmarshal(body, &m); err != nil {
			slog.Warn("error unmarshalling JSON", "error", err, "body", body)
			http.Error(w, fmt.Sprintf("json.Unmarshal: %v", err), http.StatusBadRequest)
			return
		}

		// handleMessage is re-used from the general pubsub code
		res, err := handleMessage(ctxt, google, invoker, top, m.Message.Data, m.Message.Attributes)
		if err != nil {
			slog.Warn("failed handling message", "error", err)
			http.Error(w, fmt.Sprintf("failed handling message: %v", err), http.StatusBadRequest)
			return
		}

		// Wait for publishing to finish
		<-res.Ready()
		if _, err := res.Get(ctxt); err != nil {
			slog.Warn("failed publishing result", "error", err)
			http.Error(w, fmt.Sprintf("failed publishing result: %v", err), http.StatusBadRequest)
			return
		}

		// Ack the message
		w.WriteHeader(http.StatusOK)
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		slog.Info("defaulting to port", "port", port)
	}

	// Start HTTP server.
	slog.Info("Listening", "port", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		slog.Info("error listening", "error", err)
		return err
	}

	return nil
}
