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
	"fmt"

	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/gcp"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/protoio"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/stats"
	"github.com/spf13/cobra"
	"google.golang.org/protobuf/proto"
)

func NewGRPCGenerator(src *Source, stats *stats.StatsConfig, google *gcp.GoogleConfig) *cobra.Command {

	cfg := &protoio.BackendConfiguration{}

	cmd := &cobra.Command{
		Use:   "grpc",
		Short: "gRPC roundtrip and throughput latency tests",
		Args:  cobra.ExactArgs(0),
	}
	cfg.Initialize(cmd, google)
	cmd.RunE = func(c *cobra.Command, args []string) error {

		inputType, _, err := cfg.GetTypes(c.Context())
		if err != nil {
			return err
		}

		invoker, err := cfg.GetProtoInvoker(c.Context(), stats)
		if err != nil {
			return err
		}

		return src.StartSourceProto(c.Context(), inputType, func(ctxt context.Context, msg proto.Message, cnt int) error {
			_, err := invoker(ctxt, msg)
			if err != nil {
				return fmt.Errorf("failed calling grpc: %w", err)
			}
			return nil
		})
	}

	return cmd
}
