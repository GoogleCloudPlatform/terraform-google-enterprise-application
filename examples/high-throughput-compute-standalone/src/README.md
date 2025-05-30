# Load Test for HTC

## Overview

This is a general purpose gRPC load test. It supports compute, reading/writing data,
initialization, and produces JSON formatted stats.

## Compilation

This can be compiled using `go generate` and `go build`. The following packages
are required for building: `protoc-gen-go`, `protoc-gen-go-grpc`, and
`golang-google-protobuf-dev`. There is a provided [Dockerfile](Dockerfile).

## Running locally

### Building

```sh
go generate
go build
```

### Generate test data

Generate 1000 example tasks:

```sh
./loadtest gentasks --count 1000 tasks.jsonl
```

### With the file directly

Directly run loadtest with the test data:

```sh
./loadtest load tasks.jsonl
```

You will see both logging (on stderr) and the generated output (on stdout).

### With gRPC

Run the pricing engine locally on the default port 2002:

```sh
./loadtest serve
```

In a separate command prompt, [grpcurl](https://github.com/fullstorydev/grpcurl)  with the test data to try it out:
to generate JSON test data for the pricing library. This will only send in the
first request.

```sh
head -n 1 tasks.jsonl | grpcurl -d @ -plaintext localhost:2002 main.PricingService/CalcPrices
```

NOTE: You can use the --logJSON to produce  JSON formatted logs which includes some
performance statistics. These can be directly queried with distributed jobs using
Google Cloud Logging with [Log Analytics](https://cloud.google.com/logging/docs/analyze/query-and-view).

## Running in a container

### Build the container

```sh
docker build -t loadtest .
```

### Generate test data

Generate 1000 example tasks:

```sh
docker run loadtest gentasks --count 1000 - > tasks.jsonl
```

### With the file directly

Directly run loadtest with the test data:

```sh
docker run -v $PWD:/data loadtest load /data/tasks.jsonl
```

### With gRPC

Run the loadtest engine locally on the default port 2002:

```sh
docker run -p 2002:2002 loadtest serve
```

In a separate command prompt, [grpcurl](https://github.com/fullstorydev/grpcurl)  with the test data to try it out:
to generate JSON test data for the pricing library. This will only send in the
first request.

```sh
head -n 1 tasks.jsonl | grpcurl -d @ -plaintext localhost:2002 main.LoadTestService/RunLibrary
```
