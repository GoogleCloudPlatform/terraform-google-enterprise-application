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

package stats

import (
	"testing"
	"time"
)

func TestTimings(t *testing.T) {
	RunTest(t, []timePoint{
		{time.Second * 2, 1},
		{time.Second * 1, 1},
		{time.Second * 4, 1},
		{time.Second * 3, 1},
	},
		[]float64{1, 0.5, 0.0},
		[]time.Duration{
			time.Second * 4,
			time.Second * 3,
			time.Second * 1,
		})
}

func RunTest(t *testing.T, data []timePoint, percentile []float64, expected_results []time.Duration) {
	tt := NewTimeDistribution()
	for _, d := range data {
		tt.Add(d.weight, d.timing)
	}

	results := tt.GetPercentile(percentile)
	if len(expected_results) != len(results) {
		t.Fatalf("expected same results length")
	}
	for i := 0; i < len(results); i++ {
		if results[i] != expected_results[i] {
			t.Fatalf("off, expected %v, got %v timing for percentile %f",
				expected_results[i], results[i], percentile[i])
		}
	}
}
