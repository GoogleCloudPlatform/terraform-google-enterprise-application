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

package protoio

import (
	"fmt"
	"iter"
	"regexp"
	"time"

	"context"

	"log/slog"

	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/gcp"
	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/stats"
	"github.com/jhump/protoreflect/grpcreflect"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
	"google.golang.org/grpc/connectivity"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/credentials/oauth"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/reflect/protoreflect"
	"google.golang.org/protobuf/types/dynamicpb"
)

var target_pat = regexp.MustCompilePOSIX(`^(https?)://([^/]+)(:[0-9]+)?/([^/]+)/([^/]+)$`)

type BackendConfiguration struct {

	// Command line parameters
	Endpoint string
	Timeout  time.Duration

	// Private members
	service string
	method  string
	client  *grpc.ClientConn
	google  *gcp.GoogleConfig
}

func (cfg *BackendConfiguration) Initialize(cmd *cobra.Command, google *gcp.GoogleConfig) {
	cfg.google = google

	cmd.PersistentFlags().StringVar(&cfg.Endpoint, "endpoint", cfg.Endpoint, "Target endpoint for backend")
	cmd.PersistentFlags().DurationVar(&cfg.Timeout, "timeout", cfg.Timeout, "Connection timeout")
}

func (cfg *BackendConfiguration) connect(ctxt context.Context) error {
	if cfg.client != nil {
		return nil
	}

	if cfg.Endpoint == "" {
		return fmt.Errorf("the target endpoint must be configured")
	}

	mat := target_pat.FindStringSubmatch(cfg.Endpoint)
	if mat == nil {
		return fmt.Errorf("invalid url '%s', expecting https?://<host>(:<port>)?/serviceName/method", cfg.Endpoint)
	}

	var hostport string
	if len(mat) == 6 {
		hostport = mat[2] + mat[3]
		cfg.service = mat[4]
		cfg.method = mat[5]
	} else {
		if mat[1] == "http" {
			hostport = mat[2] + ":80"
			cfg.service = mat[3]
			cfg.method = mat[4]
		} else {
			hostport = mat[2] + ":443"
			cfg.service = mat[3]
			cfg.method = mat[4]
		}
	}

	// Configure connection
	var opts []grpc.DialOption
	if mat[1] == "http" {
		slog.Info("Connecting to gRPC server insecure", "hostport", hostport)
		opts = []grpc.DialOption{
			grpc.WithTransportCredentials(insecure.NewCredentials()),
		}
	} else {
		slog.Info("Connecting to gRPC server with GCE ADC", "hostport", hostport)
		opts = []grpc.DialOption{
			grpc.WithTransportCredentials(credentials.NewClientTLSFromCert(nil, "")),
			grpc.WithPerRPCCredentials(oauth.NewComputeEngine()),
		}
	}

	client, err := grpc.NewClient(hostport, opts...)
	if err != nil {
		return err
	}

	// Start connection
	client.Connect()

	// Wait until connected
	if cfg.Timeout > 0 {
		var currState connectivity.State
		connContext, cancelContext := context.WithTimeout(ctxt, cfg.Timeout)
		defer cancelContext()
		for {
			currState = client.GetState()
			if currState == connectivity.Ready {
				slog.Info("gRPC connected, ready to go.")
				break
			}

			slog.Info("gRPC not connected, still trying.", "state", currState.String())

			// Wait for next change
			if !client.WaitForStateChange(connContext, currState) {
				return fmt.Errorf("failed to connect in timeout of %v", cfg.Timeout)
			}
		}
	}

	// Monitor state for logging
	go func() {
		var lstate = client.GetState()

		for {

			// Wait for next change
			if !client.WaitForStateChange(ctxt, lstate) {
				return
			}

			lstate = client.GetState()

			slog.Info("gRPC Connection State", "state", lstate.String())
		}
	}()

	cfg.client = client

	return nil
}

func (cfg *BackendConfiguration) GetProtoInvoker(ctxt context.Context, stats *stats.StatsConfig) (func(context.Context, proto.Message) (proto.Message, error), error) {
	err := cfg.connect(ctxt)
	if err != nil {
		return nil, err
	}

	if cfg.method == "" {
		return nil, fmt.Errorf("the target method must be configured")
	}

	_, outputType, err := cfg.GetTypes(ctxt)
	if err != nil {
		return nil, err
	}

	cOpts := []grpc.CallOption{grpc.StaticMethod()}
	fullMethod := "/" + cfg.service + "/" + cfg.method
	return func(context context.Context, req proto.Message) (proto.Message, error) {

		srcId, ok := ctxt.Value("srcId").(string)
		if !ok {
			srcId = ""
		}

		outmsg := dynamicpb.NewMessage(outputType)
		slog.Debug("Invoking", "srcId", srcId, "fullmethod", fullMethod, "request", req)

		stats.StartTask(srcId)
		err := cfg.client.Invoke(context, fullMethod, req, outmsg, cOpts...)
		stats.DoneTask(srcId, uint64(proto.Size(req))+uint64(proto.Size(outmsg)))

		if err != nil {
			return nil, err
		}

		return outmsg, nil
	}, nil
}

func (cfg *BackendConfiguration) ReadProtoInput(ctxt context.Context, input string) (iter.Seq2[proto.Message, error], error) {
	inputType, _, err := cfg.GetTypes(ctxt)
	if err != nil {
		return nil, err
	}
	return ReadProto(ctxt, cfg.google, inputType, input), nil
}

func (cfg *BackendConfiguration) WriteProtoOutput(ctxt context.Context, iter iter.Seq2[proto.Message, error], output string) error {
	return WriteProto(ctxt, cfg.google, iter, output)
}

func (cfg *BackendConfiguration) GetTypes(ctxt context.Context) (protoreflect.MessageDescriptor, protoreflect.MessageDescriptor, error) {
	err := cfg.connect(ctxt)
	if err != nil {
		return nil, nil, err
	}

	if cfg.service == "" {
		return nil, nil, fmt.Errorf("the target service must be configured")
	}

	reflectclient := grpcreflect.NewClientAuto(ctxt, cfg.client)
	desc, err := reflectclient.ResolveService(cfg.service)
	if err != nil {
		return nil, nil, err
	}

	if cfg.method == "" {
		return nil, nil, fmt.Errorf("the target method must be configured")
	}

	mtd := desc.FindMethodByName(cfg.method)
	if mtd == nil {
		return nil, nil, fmt.Errorf("service %s does not have a method %s", cfg.service, cfg.method)
	}

	/* Validate type of method */
	if mtd.IsClientStreaming() || mtd.IsServerStreaming() {
		return nil, nil, fmt.Errorf("streaming is not supported for method %s", cfg.method)
	}

	return mtd.GetInputType().UnwrapMessage(), mtd.GetOutputType().UnwrapMessage(), nil
}

func (cfg *BackendConfiguration) GetJSONConverters(ctxt context.Context) (func([]byte) (proto.Message, error), func(proto.Message) ([]byte, error), error) {
	inputType, _, err := cfg.GetTypes(ctxt)
	if err != nil {
		return nil, nil, err
	}

	return JSONToProto(inputType), ProtoToJSON(), nil
}

func (cfg *BackendConfiguration) GetInvoker(ctxt context.Context, stats *stats.StatsConfig, inJson bool, outJson bool) (func(context.Context, []byte) ([]byte, error), error) {
	protoInvoker, err := cfg.GetProtoInvoker(ctxt, stats)
	if err != nil {
		return nil, err
	}

	inputType, _, err := cfg.GetTypes(ctxt)
	if err != nil {
		return nil, err
	}

	var fromBytes func([]byte) (proto.Message, error)
	if inJson {
		fromBytes = JSONToProto(inputType)
	} else {
		fromBytes = ProtoBytesToProto(inputType)
	}

	var toBytes func(proto.Message) ([]byte, error)
	if outJson {
		toBytes = ProtoToJSON()
	} else {
		toBytes = ProtoToProtoBytes()
	}

	return func(context context.Context, req []byte) ([]byte, error) {
		protoMsg, err := fromBytes(req)
		if err != nil {
			return nil, err
		}

		outMsg, err := protoInvoker(context, protoMsg)
		if err != nil {
			return nil, err
		}

		jsonMsg, err := toBytes(outMsg)
		if err != nil {
			return nil, err
		}

		return jsonMsg, nil
	}, nil
}
