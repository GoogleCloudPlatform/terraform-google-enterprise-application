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
	"iter"
	"sync/atomic"
	"time"

	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/gcp"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/protoio"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/stats"
	"github.com/spf13/cobra"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/reflect/protoreflect"
)

type Source struct {
	Source string
	Loop   bool
	Buffer int

	Ramp      time.Duration
	RampSteps int
	MaxBatch  int
	Rate      float64

	// Private
	google *gcp.GoogleConfig
}

func (s *Source) AddGenerateFlags(cmd *cobra.Command, google *gcp.GoogleConfig) {
	s.google = google

	cmd.PersistentFlags().StringVar(&s.Source, "source", s.Source, "Source of data")
	cmd.PersistentFlags().BoolVar(&s.Loop, "loop", s.Loop, "Loop over data repeatedly")
	cmd.PersistentFlags().IntVar(&s.Buffer, "buffer", s.Buffer, "Size of buffer for reading")
	cmd.PersistentFlags().IntVar(&s.MaxBatch, "max_batch", s.MaxBatch, "Maximum batch operations outstanding (parallel operations, 0 => serial)")
	cmd.PersistentFlags().Float64Var(&s.Rate, "rate", s.Rate, "Batch operations per second max (0 = no limit)")
	cmd.PersistentFlags().DurationVar(&s.Ramp, "ramp", s.Ramp, "Duration for ramp of rate (0 = no ramp)")
	cmd.PersistentFlags().IntVar(&s.RampSteps, "ramp_steps", s.RampSteps, "Number of steps for ramping")
}

func StartSource[T any](s *Source, ctxt context.Context, op func(ctxt context.Context, v T, cnt int) error, seqf func() iter.Seq2[T, error]) error {

	// Loop forever if requested
	var seq iter.Seq2[T, error]
	if s.Loop {
		seq = func(yield func(t T, e error) bool) {
			var empty T
			for ctxt.Err() == nil {
				iseq := seqf()
				for v, e := range iseq {
					if e != nil {
						yield(empty, e)
						return
					}
					if !yield(v, nil) {
						return
					}
				}
			}
		}
	} else {
		seq = seqf()
	}

	// If there is a rate, then limit the rate
	if s.Rate > 0 {
		seq = stats.Throttle[T](ctxt, seq, s.Rate, s.RampSteps, s.Ramp)
	}

	// Always one worker if none specified
	if s.MaxBatch == 0 {
		s.MaxBatch = 1
	}

	// Counter starts at one
	var cnt atomic.Int64
	cnt.Store(1)

	// Apply in parallel
	return stats.ApplyParallel[T](seq, s.MaxBatch, func(v T) error {
		prevcnt := cnt.Add(1)
		return op(ctxt, v, int(prevcnt))
	})
}

func (s *Source) StartSourceBytes(ctxt context.Context, desc protoreflect.MessageDescriptor, op func(context.Context, []byte, int) error) error {
	return StartSource[[]byte](s, ctxt, op, func() iter.Seq2[[]byte, error] {
		seq := protoio.ReadLines(ctxt, s.google, s.Source)
		if desc != nil {
			seq = protoio.MapIterErr(seq, protoio.JSONToProtoBytes(desc))
		}
		return seq
	})
}

func (s *Source) StartSourceProto(ctxt context.Context, desc protoreflect.MessageDescriptor, op func(context.Context, proto.Message, int) error) error {
	return StartSource[proto.Message](s, ctxt, op, func() iter.Seq2[proto.Message, error] {
		return protoio.MapIterErr(protoio.ReadLines(ctxt, s.google, s.Source), protoio.JSONToProto(desc))
	})
}
