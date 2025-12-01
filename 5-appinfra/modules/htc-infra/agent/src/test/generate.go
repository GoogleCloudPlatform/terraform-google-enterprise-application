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
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/gcp"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/stats"
	"github.com/spf13/cobra"
)

func AddTestCommands(stats *stats.StatsConfig, google *gcp.GoogleConfig) *cobra.Command {

	src := &Source{}

	genCmd := &cobra.Command{
		Use:   "test",
		Short: "Generate test load",
		Args:  cobra.ExactArgs(0),
		PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
			stats.Start(cmd.Context())
			if err := google.Start(cmd.Context(), "controller"); err != nil {
				return err
			}
			return nil
		},
	}
	src.AddGenerateFlags(genCmd, google)

	genCmd.AddCommand(NewGRPCGenerator(src, stats, google))
	genCmd.AddCommand(NewPubSubGenerator(src, stats, google))

	return genCmd
}
