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
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/protoio"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/stats"
	"github.com/spf13/cobra"
	"google.golang.org/protobuf/proto"
)

func getFileCommand(cfg *protoio.BackendConfiguration, stats *stats.StatsConfig) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "file input-file output-output",
		Short: "Read and write JSONL or gzipped JSONL for work",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			input := args[0]
			output := args[1]

			invoker, err := cfg.GetProtoInvoker(cmd.Context(), stats)
			if err != nil {
				return err
			}

			// Read directly (serially)
			r, err := cfg.ReadProtoInput(cmd.Context(), input)
			if err != nil {
				return err
			}

			// Get the processed messages
			processed := func(yield func(proto.Message, error) bool) {
				for inmsg := range r {
					outmsg, err := invoker(cmd.Context(), inmsg)
					if err != nil {
						yield(nil, err)
						return
					}

					if !yield(outmsg, nil) {
						return
					}

				}
			}

			// Write the output (serially)
			if err := cfg.WriteProtoOutput(cmd.Context(), processed, output); err != nil {
				return err
			}

			return nil
		},
	}
	return cmd
}
