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

package test

import (
	"context"
	"regexp"

	"cloud.google.com/go/pubsub"

	"log/slog"

	"google.golang.org/protobuf/reflect/protoreflect"

	"fmt"
	"time"

	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/gcp"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/protoio"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/stats"
	"github.com/spf13/cobra"
)

func NewPubSubGenerator(src *Source, stats *stats.StatsConfig, google *gcp.GoogleConfig) *cobra.Command {

	jsonPubSub := true
	maxMessagesOutstanding := 250000
	cmd := &cobra.Command{
		Use:   "pubsub <topic> [subscription]",
		Short: "Pubsub roundtrip throughput and latency tests",
		Args:  cobra.RangeArgs(1, 2),
	}
	cmd.Flags().BoolVar(&jsonPubSub, "jsonPubSub", jsonPubSub, "Enable JSON in Pub/Sub instead of byte-encoded protobuf")
	cmd.Flags().IntVar(&maxMessagesOutstanding, "maxMessagesOutstanding", maxMessagesOutstanding, "Maximum messages outstanding on publish")

	cmd.RunE = func(c *cobra.Command, args []string) error {
		slog.Info("Statistics are for messages (ops/second = messages per second).")

		// Create the client
		client, err := google.PubSubClient(c.Context())
		if err != nil {
			return fmt.Errorf("failed creating the client: %w", err)
		}

		// Job Number is the unix timestamp
		jobNum := time.Now().Unix()

		// Start the subscription
		if len(args) == 2 {
			slog.Debug("Subscribing", "project", google.ProjectID, "subscription", args[1])
			sub := client.SubscriptionInProject(args[1], google.ProjectID)
			sub.ReceiveSettings.MaxOutstandingBytes = -1
			sub.ReceiveSettings.MaxOutstandingMessages = -1

			go func() {
				msgReceiver := getMessageReceiver(stats, jobNum)
				if err := sub.Receive(c.Context(), msgReceiver); err != nil {
					slog.Warn("Subscription error", "error", err)
				}
			}()
		}

		// Start the source of test data
		topic := client.Topic(args[0])
		if maxMessagesOutstanding > 0 {
			topic.PublishSettings.FlowControlSettings.MaxOutstandingMessages = maxMessagesOutstanding
			topic.PublishSettings.FlowControlSettings.LimitExceededBehavior = pubsub.FlowControlBlock
		}
		publishOp := getMessagePublisher(stats, topic, jobNum)

		// Start publishing
		slog.Debug("Publishing", "project", google.ProjectID, "topic", args[0])
		var desc protoreflect.MessageDescriptor
		if !jsonPubSub {
			desc, err = getMessageDescriptor(c.Context(), client, args[0])
			if err != nil {
				return fmt.Errorf("failed finding schema from topic '%s': %w", args[0], err)
			}
		}
		if err := src.StartSourceBytes(c.Context(), desc, publishOp); err != nil {
			return fmt.Errorf("error publishing: %v", err)
		}

		// Cancel as soon as we are idle (no more outstanding requests
		stats.SetStatsIdleTimeout(time.Duration(0))

		// Wait for cancellation
		<-c.Context().Done()
		slog.Info("All sent messages received")

		return nil
	}

	return cmd
}

func getMessageReceiver(stats *stats.StatsConfig, jobNum int64) func(ctxt context.Context, msg *pubsub.Message) {

	return func(ctxt context.Context, msg *pubsub.Message) {

		// Debug
		slog.Debug("Receiving response", "response", msg)

		// Always ack for received messages
		r := msg.AckWithResult()

		// If exactly once enabled and there is an ack reslut,
		// block until the result is returned and a pubsub.AcknowledgeStatus
		// is returned for the acked message.
		if r != nil {
			status, err := r.Get(ctxt)
			if err != nil {
				slog.Warn("Failed when calling result.Get", "error", err, "msg", msg.ID)
			}
			if status != pubsub.AcknowledgeStatusSuccess {
				slog.Warn("Message acknowledged failed", "status", status, "id", msg.ID, "attributes", msg.Attributes)
			}
		}

		// Record performance of this single message and size of the message
		srcId, ok := msg.Attributes["srcId"]
		if ok {
			stats.DoneTask(srcId, uint64(len(msg.Data)))
		}
	}
}

func getMessagePublisher(stats *stats.StatsConfig, pubTopic *pubsub.Topic, jobNum int64) func(ctxt context.Context, msg []byte, cnt int) error {
	return func(ctxt context.Context, msg []byte, cnt int) error {
		slog.Debug("Publishing request", "count", cnt, "topic", pubTopic.ID())

		// Stop if the context is cancelled
		if ctxt.Err() != nil {
			return ctxt.Err()
		}

		// Publish message
		srcId := fmt.Sprintf("Job-%d-Msg-%d", jobNum, cnt)
		stats.StartTask(srcId)
		slog.Debug("publishing",
			"srcId", srcId,
			"data", msg)
		res := pubTopic.Publish(ctxt, &pubsub.Message{
			Data: msg,
			Attributes: map[string]string{
				"srcTimeNano": fmt.Sprintf("%d", time.Now().UnixNano()),
				"srcId":       srcId,
			},
		})

		// Log errors
		go func() {
			_, err := res.Get(ctxt)
			if err != nil {

				// It failed sending, no need to wait for it now
				stats.CancelTask(srcId)

				// Log if it's a general error, not cancellation
				if err != context.Canceled {
					slog.Warn("error publishing", "error", err)
				}
			}
		}()

		return nil
	}
}

var SCHEMA_PATTERN = regexp.MustCompile(`^projects/([^/]*)/schemas/([^/]*)$`)

func getMessageDescriptor(ctxt context.Context, client *pubsub.Client, topicName string) (protoreflect.MessageDescriptor, error) {
	topic := client.Topic(topicName)
	defer topic.Stop()

	exists, err := topic.Exists(ctxt)
	if err != nil {
		return nil, fmt.Errorf("error looking up topic '%s': %w", topicName, err)
	}
	if !exists {
		return nil, fmt.Errorf("topic %s does not exist", topic)
	}

	topicCfg, err := topic.Config(ctxt)
	if err != nil {
		return nil, fmt.Errorf("failed finding topic configuration: %w", err)
	}

	if topicCfg.SchemaSettings == nil || topicCfg.SchemaSettings.Schema == "" {
		return nil, fmt.Errorf("topic has no schema associated")
	}

	if topicCfg.SchemaSettings.Encoding != pubsub.EncodingBinary {
		return nil, fmt.Errorf("only support binary encoding")
	}

	schema_match := SCHEMA_PATTERN.FindStringSubmatch(topicCfg.SchemaSettings.Schema)
	if schema_match == nil {
		return nil, fmt.Errorf("invalid schema name: %s", topicCfg.SchemaSettings.Schema)
	}

	schemaClient, err := pubsub.NewSchemaClient(ctxt, schema_match[1])
	if err != nil {
		return nil, fmt.Errorf("error creating schema client: %w", err)
	}

	schemaConfig, err := schemaClient.Schema(ctxt, schema_match[2], pubsub.SchemaViewFull)
	if err != nil {
		return nil, fmt.Errorf("error finding schema '%s': %w", topicCfg.SchemaSettings.Schema, err)
	}

	if schemaConfig.Name != topicCfg.SchemaSettings.Schema {
		return nil, fmt.Errorf("not matching name")
	}

	if schemaConfig.Type != pubsub.SchemaProtocolBuffer {
		return nil, fmt.Errorf("must be a protocolbuffer schema")
	}

	return protoio.CompileDescriptor(ctxt, schemaConfig.Definition)
}
