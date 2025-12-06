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
	"fmt"

	"github.com/bufbuild/protocompile"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/reflect/protoreflect"
	"google.golang.org/protobuf/types/dynamicpb"
)

func CompileDescriptor(ctxt context.Context, protodefinition string) (protoreflect.MessageDescriptor, error) {

	compiler := protocompile.Compiler{
		Resolver: protocompile.WithStandardImports(&protocompile.SourceResolver{
			Accessor: protocompile.SourceAccessorFromMap(map[string]string{
				"main.proto": protodefinition,
			}),
		}),
		MaxParallelism: 1,
		SourceInfoMode: protocompile.SourceInfoNone,
	}
	descs, err := compiler.Compile(ctxt, "main.proto")
	if err != nil {
		return nil, err
	}
	if len(descs) != 1 {
		return nil, fmt.Errorf("expected to parse one file, got %d files", len(descs))
	}
	msgTypes := descs[0].Messages()
	if msgTypes.Len() == 0 {
		return nil, fmt.Errorf("expected at least one message type defined")
	}

	return msgTypes.Get(msgTypes.Len() - 1), nil
}

func JSONToProto(desc protoreflect.MessageDescriptor) func([]byte) (proto.Message, error) {
	opts := &protojson.UnmarshalOptions{
		AllowPartial:   false,
		DiscardUnknown: true,
	}

	return func(jsonmsg []byte) (proto.Message, error) {
		if desc == nil {
			return nil, fmt.Errorf("missing descriptor")
		}
		msg := dynamicpb.NewMessage(desc)
		if err := opts.Unmarshal([]byte(jsonmsg), msg); err != nil {
			return nil, fmt.Errorf("error marshing JSON to protobuf: %w", err)
		}
		return msg, nil
	}
}

func ProtoBytesToProto(desc protoreflect.MessageDescriptor) func([]byte) (proto.Message, error) {
	return func(req []byte) (proto.Message, error) {
		msg := dynamicpb.NewMessage(desc)
		if err := proto.Unmarshal(req, msg); err != nil {
			return nil, fmt.Errorf("error marshing bytes to JSON: %w", err)
		}
		return msg, nil
	}
}

func JSONToProtoBytes(desc protoreflect.MessageDescriptor) func([]byte) ([]byte, error) {
	jsonToProto := JSONToProto(desc)

	return func(line []byte) ([]byte, error) {
		msg, err := jsonToProto(line)
		if err != nil {
			return nil, err
		}
		msgdata, err := proto.Marshal(msg)
		if err != nil {
			return nil, err
		}
		return msgdata, nil
	}
}

func ProtoToProtoBytes() func(proto.Message) ([]byte, error) {
	return proto.Marshal
}

func ProtoToJSON() func(proto.Message) ([]byte, error) {
	opts := &protojson.MarshalOptions{
		Multiline:         false,
		Indent:            "",
		AllowPartial:      false,
		EmitDefaultValues: false,
		EmitUnpopulated:   false,
		UseEnumNumbers:    true,
		UseProtoNames:     true,
	}

	return func(msg proto.Message) ([]byte, error) {
		return opts.Marshal(msg)
	}
}
