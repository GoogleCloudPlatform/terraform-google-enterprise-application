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
	"fmt"
	"math"
	"time"

	"log/slog"
)

var kbyte float64 = math.Pow(2, 10)
var mbyte float64 = math.Pow(2, 20)
var gbyte float64 = math.Pow(2, 30)

func getFormattedDuration(t time.Duration) string {
	if t >= time.Minute {
		return fmt.Sprintf("%3dm ", int(t.Minutes()))
	} else if t >= time.Second {
		return fmt.Sprintf("%3ds ", int(t.Seconds()))
	} else if t >= time.Millisecond {
		return fmt.Sprintf("%3dms", t.Milliseconds())
	} else if t >= time.Microsecond {
		return fmt.Sprintf("%3dμs", t.Microseconds())
	} else {
		return fmt.Sprintf("%3dns", t.Nanoseconds())
	}
}

func getFormattedBytes(bytes float64) string {
	if bytes > gbyte {
		return fmt.Sprintf("%3.0fGB/s", bytes/gbyte)
	} else if bytes > mbyte {
		return fmt.Sprintf("%3.0fMB/s", bytes/mbyte)
	} else if bytes > kbyte {
		return fmt.Sprintf("%3.0fKB/s", bytes/kbyte)
	} else {
		return fmt.Sprintf("%3.0f B/s", bytes)
	}
}

func getFormattedOps(ops float64) string {
	if ops > 1_000_000_000 {
		return fmt.Sprintf("%3.0fg/s", ops/1_000_000_000)
	} else if ops > 1_000_000 {
		return fmt.Sprintf("%3.0fm/s", ops/1_000_000)
	} else if ops > 1_000 {
		return fmt.Sprintf("%3.0fk/s", ops/1_000)
	} else {
		return fmt.Sprintf("%3.0f /s", ops)
	}
}

// Accumulated stats for a window
type accumulatedStats struct {
	showHdr bool // Whether the header has been shown

	// Window start time
	start time.Time // Start time for distribution

	// Tracking for completed operations in the window
	timings *timeDistribution // Latency time distribution
	ops     uint64            // Completed operations
	bytes   uint64            // Transfered bytes

	// Tracking for total op time in the window
	optime int64

	// Tracking for operations (all operations outstanding)
	currentOps map[string]int64
}

func NewAccumulatedStats() *accumulatedStats {
	return &accumulatedStats{
		showHdr:    false,
		start:      time.Now(),
		timings:    NewTimeDistribution(),
		ops:        0,
		bytes:      0,
		optime:     0,
		currentOps: make(map[string]int64),
	}
}

func (a *accumulatedStats) LogStats(reset bool, logJSON bool) {

	// Timing
	n := time.Now()
	dur := n.Sub(a.start)

	// Average latency
	latencies := a.timings.GetPercentile([]float64{1.0, 0.99, 0.95, 0.5, 0.0})

	// Show stats header if not JSON and first time
	if !a.showHdr && !logJSON {
		slog.Info(fmt.Sprintf("%4.4s %7.7s %6.6s %5.5s %5.5s %5.5s %5.5s %5.5s",
			"Load", "Bytes", "Ops", "Max", "99th", "95th", "50th", "Min"))
		a.showHdr = true
	}

	// Calculate the total compute execution time since the
	// start of the window, including completed operations
	// *and* on-going operations
	executed := a.optime
	for _, opStartTime := range a.currentOps {
		executed += n.UnixNano() - max(opStartTime, a.start.UnixNano())
	}

	if !logJSON {
		slog.Info(fmt.Sprintf("%4.1f %s %s %s %s %s %s %s",
			float64(executed)/(1e9*dur.Seconds()),
			getFormattedBytes(float64(a.bytes)/dur.Seconds()),
			getFormattedOps(float64(a.ops)/dur.Seconds()),
			getFormattedDuration(latencies[0]),
			getFormattedDuration(latencies[1]),
			getFormattedDuration(latencies[2]),
			getFormattedDuration(latencies[3]),
			getFormattedDuration(latencies[4])))
	} else {
		slog.Info("statistics",
			"load", float64(executed)/(1e9*dur.Seconds()),
			"bytes", a.bytes,
			"ops", a.ops,
			"lat_max", latencies[0],
			"lat_99", latencies[1],
			"lat_95", latencies[2],
			"lat_50", latencies[3],
			"lat_min", latencies[4],
		)
	}

	// Reset all stats
	a.start = n
	a.ops = 0
	a.bytes = 0
	a.optime = 0
	a.timings.Clear()

}

func (a *accumulatedStats) ActiveOp() int {
	return len(a.currentOps)
}

func (a *accumulatedStats) StartOp(id string) {
	a.currentOps[id] = time.Now().UnixNano()
}

// Cancel the operation
//
// Note that if a stats has been produced, it will have been included
// in the load for that window. Going forward it will be excluded and no
// operations, bytes, or latency will be tracked.
func (a *accumulatedStats) CancelOp(id string) {
	delete(a.currentOps, id)
}

func (a *accumulatedStats) DoneOp(id string, bytes uint64) time.Duration {
	startTime, ok := a.currentOps[id]
	delete(a.currentOps, id)
	if !ok {
		return time.Duration(0)
	}

	currentTime := time.Now().UnixNano()

	a.ops += uint64(1)
	a.bytes += bytes
	a.optime += currentTime - max(startTime, a.start.UnixNano())
	a.timings.Add(int32(1), time.Duration(currentTime-startTime))

	return time.Duration(currentTime - startTime)
}
