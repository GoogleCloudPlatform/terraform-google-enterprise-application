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
	"log"
	"sort"
	"time"
)

type timePoint struct {
	timing time.Duration
	weight int32
}

type timeDistribution struct {
	points []timePoint
	total  int64
}

func NewTimeDistribution() *timeDistribution {
	return &timeDistribution{
		points: make([]timePoint, 0, 10),
		total:  0,
	}
}

func (t *timeDistribution) Clear() {
	t.points = t.points[:0]
	t.total = 0
}

func (t *timeDistribution) Add(weight int32, timing time.Duration) {
	t.points = append(t.points, timePoint{timing, weight})
	t.total += int64(weight)
}

// percentile should be greatest to least, no more than 1.0 (max) or less than 0.0 (min).
func (t *timeDistribution) GetPercentile(percentile []float64) []time.Duration {

	// Sort largest to smallest
	sort.Slice(t.points, func(i, j int) bool {
		return t.points[i].timing > t.points[j].timing
	})

	// Validate percentile
	for j := 0; j < len(percentile); j++ {
		if percentile[j] > 1.0 || percentile[j] < 0.0 {
			log.Fatalf("invalid percentile: %f", percentile[j])
		}
		if j > 0 && percentile[j-1] <= percentile[j] {
			log.Fatalf("invalid percentile order")
		}
	}

	values := make([]time.Duration, len(percentile))

	// Walk forwards, going backwards
	total := t.total
	for i, j := 0, 0; i < len(t.points) && j < len(percentile); i++ {
		total -= int64(t.points[i].weight)
		curr_perc := float64(total) / float64(t.total)

		// It's already at the required pecentile
		for j < len(percentile) && curr_perc <= percentile[j] {
			values[j] = t.points[i].timing
			j++
		}
	}

	return values

}
