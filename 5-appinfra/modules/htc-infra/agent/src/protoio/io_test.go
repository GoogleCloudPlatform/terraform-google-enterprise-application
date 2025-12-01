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
	"context"
	"path"
	"testing"

	"google.golang.org/protobuf/proto"

	"github.com/GoogleCloudPlatform/finance-research-risk-examples/examples/risk/agent/gcp"
)

// Command to compile the protobuf for tests:
// protoc -I. --go-grpc_out=. --go-grpc_opt=paths=source_relative test_service.proto
// protoc -I. --go_out=. --go_opt=paths=source_relative test_service.proto

var defn = `
syntax = "proto3";

package main;

message QuantTask {

  // Unique identifier (possibly a timestamp!)
  int64 id = 1;

  // Likelihood of failure (for a simulator)
  double  perc_crash  = 2;
  double  perc_fail   = 3;

  // How long it takes to run (for a simulator)
  int64 max_micros  = 4;
  int64 min_micros  = 5;

  // Size of payload results (all risk metrics, sensitivities, etc)
  int64 result_size = 6;

  // Payload includes all marketdata, trade information,
  // risk metric parameters, etc..
  bytes  payload    = 7;
}
`

var json_msg = `
{ "id": 1, "perc_crash":0.1, "perc_fail":0.3, "max_micros": 10000, "min_micros": 1000, "result_size":10, "payload": "alskdfjlkj3214"}
`

func TestProtoDefinition(t *testing.T) {
	desc, err := CompileDescriptor(context.Background(), defn)
	if err != nil {
		t.Fatalf("Failed compilng %s: %v", defn, err)
	}

	fromJsonConverter := JSONToProto(desc)
	fromProtoConverter := ProtoToJSON()

	asProto, err := fromJsonConverter([]byte(json_msg))
	if err != nil {
		t.Fatalf("failed converting from json %s to proto: %v", json_msg, err)
	}

	asJson, err := fromProtoConverter(asProto)
	if err != nil {
		t.Fatalf("failed converting proto to json: %v", err)
	}
	t.Logf("Original vs converted json: %s vs %s", json_msg, asJson)

	//ReadProto(context.Background(), desc, "testInput")
	// tmpdir := t.TempDir()
	tmpdir := "/tmp"
	tmpFile := path.Join(tmpdir, "testOutput")

	// Produce ten in a row!
	inputSrc := func(yield func(proto.Message, error) bool) {
		for range 10 {
			if !yield(asProto, nil) {
				break
			}
		}
	}

	// This is only relevant when reading/writing GCS, but needs to be supplied
	google := &gcp.GoogleConfig{}

	err = WriteProto(context.Background(), google, inputSrc, tmpFile+".jsonl")
	if err != nil {
		t.Fatalf("Failed writing to avro: %v", err)
	}

	seq := ReadProto(context.Background(), google, desc, tmpFile+".jsonl")

	err = WriteProto(context.Background(), google, seq, tmpFile+".jsonl.gz")
	if err != nil {
		t.Fatalf("Failed writing jsonl: %v", err)
	}

	seq2 := ReadProto(context.Background(), google, desc, tmpFile+".jsonl.gz")
	if err != nil {
		t.Fatalf("Failed reading from avro: %v", err)
	}

	for msg, err := range seq2 {
		if err != nil {
			t.Fatalf("Failed reading from avro: %v", err)
		}
		t.Logf("Read message: %v", msg)
	}
}
