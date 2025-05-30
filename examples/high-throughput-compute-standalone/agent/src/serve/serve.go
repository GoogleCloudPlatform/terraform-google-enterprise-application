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
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/gcp"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/protoio"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/stats"
	"github.com/spf13/cobra"
)

func AddServeCommands(stats *stats.StatsConfig, google *gcp.GoogleConfig) *cobra.Command {

	cfg := &protoio.BackendConfiguration{}
	cmd := &cobra.Command{
		Use:   "serve",
		Short: "Serve work a sidecar worker",
		Args:  cobra.ExactArgs(0),
		PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
			stats.Start(cmd.Context())
			if err := google.Start(cmd.Context(), "agent"); err != nil {
				return err
			}
			return nil
		},
	}
	cfg.Initialize(cmd, google)

	cmd.AddCommand(NewPubSubPullAgent(cfg, stats, google))
	cmd.AddCommand(NewPubSubPushAgent(cfg, stats, google))
	cmd.AddCommand(getRDFCommand(cfg, stats))
	cmd.AddCommand(getFileCommand(cfg, stats))

	return cmd
}
