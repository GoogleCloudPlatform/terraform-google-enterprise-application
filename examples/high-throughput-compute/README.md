# High Throughput Compute and Data & Analytics

There are a number of components demonstrating High Throughput Compute and Data & Analytics on Google Cloud.

Risk examples rely on an unary gRPC service. This service consumes a single protobuf and returns a single protobuf and can be deployed through a variety of mechanisms.

There are some provided example gRPC services, including a Load Test example that provides a test harness that can exercise GCP infrastructure (some compute, some IO) and an American Options example is a Python example using quantlib to calculate American Options.

It is recommended to start with Load Test which provides an end to end deployment demonstration and testing framework
