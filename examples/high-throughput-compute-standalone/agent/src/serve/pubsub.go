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
	"fmt"
	"log/slog"
	"time"

	"cloud.google.com/go/pubsub"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/gcp"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/protoio"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/stats"
	"github.com/spf13/cobra"
)

func NewPubSubPullAgent(cfg *protoio.BackendConfiguration, stats *stats.StatsConfig, google *gcp.GoogleConfig) *cobra.Command {
	var idleTimeout time.Duration
	var jsonPubSub bool

	subSettings := &pubsub.ReceiveSettings{}
	cmd := &cobra.Command{
		Use:   "pubsub-pull subscription-id topic-id",
		Short: "PubSub pull and publish worker",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			invoker, err := cfg.GetInvoker(cmd.Context(), stats, jsonPubSub, jsonPubSub)
			if err != nil {
				return err
			}
			return handlePubSubSubscribe(cmd.Context(), stats, google, invoker, subSettings, idleTimeout, google.ProjectID, args[0], args[1], jsonPubSub)
		},
	}
	cmd.Flags().DurationVar(&idleTimeout, "idleTimeout", idleTimeout,
		"Idle timeout -- shutdown after no activity for this time period")
	cmd.Flags().DurationVar(&subSettings.MinExtensionPeriod, "minExtensionPeriod", 600*time.Second,
		"Minimum deadline extension for processing tasks")
	cmd.Flags().DurationVar(&subSettings.MaxExtension, "maxExtension", 60*time.Minute,
		"Maximum deadline for processing tasks")
	cmd.Flags().IntVar(&subSettings.NumGoroutines, "goroutines", 1,
		"Goroutine count")
	cmd.Flags().IntVar(&subSettings.MaxOutstandingMessages, "maxoutstandingmessages", 1,
		"Max number of messages outstanding")
	cmd.Flags().BoolVar(&subSettings.Synchronous, "synchronous", false,
		"Enable synchronous mode for subscriptions")
	cmd.Flags().BoolVar(&jsonPubSub, "jsonPubSub", true,
		"Enable JSON in Pub/Sub instead of byte-encoded protobuf")

	return cmd
}

func handlePubSubSubscribe(
	ctxt context.Context,
	stats *stats.StatsConfig,
	google *gcp.GoogleConfig,
	invoker func(context.Context, []byte) ([]byte, error),
	settings *pubsub.ReceiveSettings, idleTimeout time.Duration,
	project string, subscription string, topic string, jsonPubSub bool) error {

	slog.Debug("Subscribing", "project", project, "subscription", subscription)

	// Create PubSub client
	client, err := google.PubSubClient(ctxt)
	if err != nil {
		return fmt.Errorf("creating client: %w", err)
	}

	// Publish the topic response
	top := client.TopicInProject(topic, project)

	// Prepare to shutdown after an idle period
	if idleTimeout > time.Duration(0) {
		slog.Info("Shutting down after an idle timeout", "idleTimeout", idleTimeout)
		stats.SetStatsIdleTimeout(idleTimeout)
	}

	// Subscribe to data
	sub := client.SubscriptionInProject(subscription, project)
	sub.ReceiveSettings = *settings
	return sub.Receive(ctxt, func(ctxt context.Context, msg *pubsub.Message) {

		slog.Debug("received request",
			"data", msg.Data,
			"attributes", msg.Attributes)

		res, err := handleMessage(ctxt, google, invoker, top, msg.Data, msg.Attributes)
		if err != nil {
			slog.Warn("Failed calling service", "error", err)
			logAckResult(ctxt, msg.NackWithResult())
			return
		}

		go func() {

			// Wait for publish acknowledgement
			<-res.Ready()

			// Nack on failure
			if _, err := res.Get(ctxt); err != nil {
				slog.Warn("failed publishing result", "error", err)
				logAckResult(ctxt, msg.NackWithResult())
				return
			}

			// All good - ack message!
			logAckResult(ctxt, msg.AckWithResult())
		}()
	})
}

func logAckResult(ctxt context.Context, r *pubsub.AckResult) {
	status, err := r.Get(ctxt)
	if err != nil {
		slog.Warn("Failed when calling result.Get", "error", err)
	}
	if status != pubsub.AcknowledgeStatusSuccess {
		slog.Warn("Message acknowledged failed", "status", status)
	}
}

func handleMessage(
	ctxt context.Context,
	google *gcp.GoogleConfig,
	invoker func(context.Context, []byte) ([]byte, error),
	top *pubsub.Topic,
	data []byte,
	attributes map[string]string) (*pubsub.PublishResult, error) {

	// Extract srcId
	srcId, ok := attributes["srcId"]
	if !ok {
		srcId = ""
	}

	// Run the task raw
	requestCtx := context.WithValue(ctxt, srcIDKey, srcId)
	rbuf, err := invoker(
		requestCtx,
		data)

	// If error, do a Nack for faster retry
	if err != nil {
		return nil, fmt.Errorf("error running library: %w", err)
	}

	// Response with some attributes for incoming message!
	attributes["Hostname"] = google.Hostname
	rmsg := &pubsub.Message{
		Data:       rbuf,
		Attributes: attributes,
	}

	// Publish and ack when done
	return top.Publish(ctxt, rmsg), nil
}
