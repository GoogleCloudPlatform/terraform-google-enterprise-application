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
	"context"
	"log/slog"
	"os"
	"sync"
	"time"

	"github.com/spf13/cobra"
)

type statOperation int

const (
	idStart statOperation = iota
	idCancel
	idDone

	idleTimeoutSet
)

type stats struct {
	Operation statOperation
	Id        string
	Bytes     uint64
	Timeout   time.Duration
}

// ShowStats in a certain frequency. This logs using slog.
func (cfg *StatsConfig) showStats(
	ctxt context.Context) {

	cfg.statsShutdown.Add(1)
	go func() {
		defer cfg.statsShutdown.Done()

		accum := NewAccumulatedStats()

		timeout := time.Duration(-1)

		// Last idle time (default to zero)
		var idleTime time.Time

		// Stat accumulation time
		ntime := time.Now().Add(cfg.Freq)

		timeoutTimer := time.NewTimer(timeout)
		timeoutTimer.Stop()

	StatsLoop:
		for ctxt.Err() == nil {

			if idleTime.IsZero() {
				timeoutTimer.Stop()
			} else if timeout >= time.Duration(0) {
				timerLimit := timeout - time.Since(idleTime)
				if timerLimit <= time.Duration(0) {
					cfg.cancel()
				} else {
					timeoutTimer.Reset(timerLimit)
				}
			}

			select {
			case <-ctxt.Done():
				break StatsLoop

			case e, ok := <-cfg.statsChannel:
				if !ok {
					break StatsLoop
				}
				switch e.Operation {
				case idleTimeoutSet:
					timeout = e.Timeout
				case idStart:
					if cfg.LogAll {
						slog.Info("taskStart",
							"id", e.Id,
							"active", accum.ActiveOp())
					}
					accum.StartOp(e.Id)
				case idCancel:
					accum.CancelOp(e.Id)
				case idDone:
					runtime := accum.DoneOp(e.Id, e.Bytes)

					if cfg.LogAll {
						slog.Info("task",
							"id", e.Id,
							"runtime", runtime,
							"bytes", e.Bytes)
					}
				}

				// Idle the idle time if needed
				if accum.ActiveOp() == 0 && idleTime.IsZero() {
					idleTime = time.Now()
				} else if accum.ActiveOp() > 0 && !idleTime.IsZero() {
					idleTime = time.Time{}
				}

			case <-time.After(time.Until(ntime)):
				accum.LogStats(true, cfg.LogJSON)

				// Next time
				ntime = ntime.Add(cfg.Freq)

			case <-timeoutTimer.C:
				cfg.cancel()
			}

		}

		// Shutdown final statistics
		accum.LogStats(true, cfg.LogJSON)
	}()
}

type StatsConfig struct {
	LogAll  bool
	LogJSON bool
	Debug   bool
	Freq    time.Duration

	cancel        context.CancelFunc
	statsChannel  chan stats
	statsShutdown sync.WaitGroup
}

func (cfg *StatsConfig) Initialize(cmd *cobra.Command, cancel context.CancelFunc) {
	cfg.Freq = time.Second * 5
	cfg.cancel = cancel
	cfg.statsChannel = make(chan stats)

	cmd.PersistentFlags().DurationVar(&cfg.Freq, "freq", 5*time.Second, "Frequency of logging statistics")
	cmd.PersistentFlags().BoolVar(&cfg.Debug, "debug", false, "Enable debug logging")
	cmd.PersistentFlags().BoolVar(&cfg.LogAll, "logAll", false, "Enable logging each completed operation")
	cmd.PersistentFlags().BoolVar(&cfg.LogJSON, "logJSON", false, "Enable JSON logging")
}

func (cfg *StatsConfig) Start(ctxt context.Context) {

	// Log with JSON format if requested
	if cfg.LogJSON {
		slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	}

	// Enable debug if requested
	if cfg.Debug {
		slog.SetLogLoggerLevel(slog.LevelDebug)
	}

	// Show statistics at a frequency
	slog.Info("Showing statistics", "frequency", cfg.Freq, "logAll", cfg.LogAll)
	cfg.showStats(ctxt)
}

func (cfg *StatsConfig) Stop() {
	close(cfg.statsChannel)
	cfg.statsShutdown.Wait()
}

func (cfg *StatsConfig) StartTask(id string) {
	cfg.statsChannel <- stats{Operation: idStart, Id: id}
}

func (cfg *StatsConfig) CancelTask(id string) {
	cfg.statsChannel <- stats{Operation: idCancel, Id: id}
}

func (cfg *StatsConfig) DoneTask(id string, bytes uint64) {
	cfg.statsChannel <- stats{Operation: idDone, Id: id, Bytes: bytes}
}

func (cfg *StatsConfig) SetStatsIdleTimeout(timeout time.Duration) {
	cfg.statsChannel <- stats{Operation: idleTimeoutSet, Timeout: timeout}
}
