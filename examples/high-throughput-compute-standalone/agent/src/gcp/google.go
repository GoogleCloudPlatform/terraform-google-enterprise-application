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

package gcp

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"

	"cloud.google.com/go/compute/metadata"
	"cloud.google.com/go/pubsub"
	mexporter "github.com/GoogleCloudPlatform/opentelemetry-operations-go/exporter/metric"
	"github.com/spf13/cobra"
	"go.opencensus.io/stats/view"
	"go.opentelemetry.io/contrib/detectors/gcp"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/bridge/opencensus"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/option"
)

type GoogleConfig struct {
	ProjectID string
	Region    string
	Hostname  string

	enableOpenTelemetry bool
	shutdown            func(context.Context) error
}

func (cfg *GoogleConfig) Initialize(cmd *cobra.Command) {

	// Set defaults for project
	credentials, err := google.FindDefaultCredentials(context.Background())
	if err == nil {
		cfg.ProjectID = credentials.ProjectID
	}
	cfg.enableOpenTelemetry = true

	// Fetch hostname (or use Metadata instance if not found)
	cfg.Hostname, err = os.Hostname()
	if err != nil || cfg.Hostname == "localhost" {
		cfg.Hostname, err = metadata.InstanceIDWithContext(context.Background())
	}
	if err != nil || cfg.Hostname == "" {
		cfg.Hostname = "localhost"
	}

	// Set parameters
	cmd.PersistentFlags().StringVar(&cfg.ProjectID, "projectId", cfg.ProjectID, "Google Project ID")
	cmd.PersistentFlags().StringVar(&cfg.Region, "region", cfg.Region, "Region for regional endpoint(s) (global otherwise)")
	cmd.PersistentFlags().BoolVar(&cfg.enableOpenTelemetry, "monitoring", cfg.enableOpenTelemetry, "Enable Cloud Monitoring")
}

func (cfg *GoogleConfig) getResources(ctxt context.Context) []attribute.KeyValue {

	// Attributes returned
	attrs := make([]attribute.KeyValue, 4)

	// If running on Cloud Run..
	kRevision := os.Getenv("K_REVISION")
	jobExecution := os.Getenv("CLOUD_RUN_EXECUTION")
	if kRevision != "" || jobExecution != "" {
		slog.Info("Running on Cloud Run")

		// Namespace (service revision or the job execution)
		if kRevision != "" {
			attrs = append(attrs, attribute.String("namespace", kRevision))
		} else {
			attrs = append(attrs, attribute.String("namespace", jobExecution))
		}

		return attrs
	}

	// Open Telemetry capture K8S namespace (if provided)
	ns := os.Getenv("K8S_NAMESPACE")
	if ns != "" {
		slog.Info("Running on Kubernetes")

		attrs = append(attrs, semconv.K8SNamespaceNameKey.String(ns))
		attrs = append(attrs, semconv.K8SPodNameKey.String(cfg.Hostname))

		return attrs
	}

	slog.Info("Uncertain where running - Open Telemetry may have errors")

	return attrs
}

func (cfg *GoogleConfig) Start(ctxt context.Context, serviceName string) error {

	// Only start once
	if cfg.shutdown != nil {
		return fmt.Errorf("cannot start Google monitoring twice")
	}

	var shutdownFuncs []func(context.Context) error

	// Create shutdown function
	cfg.shutdown = func(ctxt context.Context) error {
		var err error
		for _, fn := range shutdownFuncs {
			err = errors.Join(err, fn(ctxt))
		}
		shutdownFuncs = nil
		return err
	}

	// Create exporter
	opts := []mexporter.Option{
		mexporter.WithProjectID(cfg.ProjectID),
	}
	exp, err := mexporter.New(opts...)
	if err != nil {
		return fmt.Errorf("failed to create exporter: %v", err)
	}

	// Identify the resource
	res, err := resource.New(
		ctxt,
		// Use the GCP resource detector to detect information about the GCP platform
		resource.WithDetectors(gcp.NewDetector()),
		// Keep the default detectors
		resource.WithTelemetrySDK(),
		// Add attributes from environment variables
		resource.WithFromEnv(),
		// Add your own custom attributes to identify your application
		resource.WithAttributes(
			append(cfg.getResources(ctxt), semconv.ServiceNameKey.String(serviceName))...,
		),
	)
	if errors.Is(err, resource.ErrPartialResource) || errors.Is(err, resource.ErrSchemaURLConflict) {
		slog.Info("Open Telemetry resources partially failed")
	} else if err != nil {
		return fmt.Errorf("open Telemetry resources failed: %w", err)
	}
	slog.Info("Open Telemetry resources", "resources", res)

	// Create a bridge from the existing service and load into Open Telemetry
	bridge := opencensus.NewMetricProducer()
	provider := sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(exp, sdkmetric.WithProducer(bridge))),
		sdkmetric.WithResource(res),
	)
	shutdownFuncs = append(shutdownFuncs, provider.Shutdown)

	// Register views
	if err := view.Register(pubsub.DefaultSubscribeViews...); err != nil {
		slog.Warn("Failed to register view", "error", err)
	}

	return nil
}

func (cfg *GoogleConfig) Stop(ctxt context.Context) error {
	if cfg.shutdown != nil {
		return cfg.shutdown(ctxt)
	}
	return nil
}

func (cfg *GoogleConfig) PubSubClient(ctxt context.Context) (*pubsub.Client, error) {

	// Client Options
	opts := []option.ClientOption{}
	endpoint := "pubsub.googleapis.com:443"
	if cfg.Region != "" {
		slog.Info("Connecting to PubSub", "project", cfg.ProjectID, "region", cfg.Region)
		endpoint = fmt.Sprintf("%s-pubsub.googleapis.com:443", cfg.Region)
	} else {
		slog.Info("Connecting to PubSub", "project", cfg.ProjectID)
	}
	opts = append(opts, option.WithEndpoint(endpoint))

	// Tracking Options
	opts = append(opts, option.WithUserAgent("cloud-solutions/fsi-rdp-agent-v1.0.0"))

	// Create the client
	client, err := pubsub.NewClient(ctxt, cfg.ProjectID, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed creating the client: %w", err)
	}

	return client, nil
}
