#!/usr/bin/env python3
#
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


from concurrent import futures
import argparse
import sys
import gzip
import grpc
import logging

from request_pb2 import PricingRequest
import service_pb2_grpc
import service_pb2
from grpc_reflection.v1alpha import reflection

from american_option import quantlib_run
from google.protobuf.json_format import Parse, MessageToJson

from test_data import generate_test_data


logger = logging.getLogger(__name__)


def process_file(input):
    # Get the output file (compress if needed)
    if input.name.endswith(".gz"):
        input = gzip.open(input, mode="rb")

    with input as f:
        for line in f:
            # Parse the request from the line
            req = PricingRequest()
            Parse(line, req)

            # Print out the result
            print(
                MessageToJson(
                    quantlib_run(req),
                    indent=None,
                )
            )


class Pricer(service_pb2_grpc.PricingServiceServicer):
    def CalcPrices(self, request, context):
        return quantlib_run(request)


def serve(port):
    server = grpc.server(
        futures.ThreadPoolExecutor(max_workers=10), maximum_concurrent_rpcs=2
    )
    service_pb2_grpc.add_PricingServiceServicer_to_server(Pricer(), server)
    SERVICE_NAMES = (
        service_pb2.DESCRIPTOR.services_by_name["PricingService"].full_name,
        reflection.SERVICE_NAME,
    )
    reflection.enable_server_reflection(SERVICE_NAMES, server)
    server.add_insecure_port(f"[::]:{port}")
    server.start()
    server.wait_for_termination()


def main(args):
    parser = argparse.ArgumentParser(
        prog="calc", description="Calculate American Options."
    )
    parser.add_argument("-d", "--debug", help="Debugging enabled", action="store_true")
    parser.add_argument(
        "--logJSON", help="Log to JSON (currently unsupported)", action="store_true"
    )

    subparsers = parser.add_subparsers(dest="command_name")

    load_parser = subparsers.add_parser(name="load", help="Load from file")
    load_parser.add_argument(
        "load_file", help="Input JSONL file to process", type=argparse.FileType("rb")
    )

    serve_parser = subparsers.add_parser(name="serve", help="Serve over gRPC")
    serve_parser.add_argument(
        "-p", "--port", help="Port to wait on", default=2002, type=int
    )

    gen_parser = subparsers.add_parser(
        name="gentasks", help="Generate option pricing requests"
    )
    gen_parser.add_argument(
        "-c",
        "--count",
        help="Number of output records to generate",
        type=int,
        default=1,
    )
    gen_parser.add_argument(
        "outfile", help="Output file with JSONL records", type=argparse.FileType("wb")
    )

    args = parser.parse_args()

    # Startup logging
    logging.basicConfig(level=logging.DEBUG if args.debug else logging.INFO)
    if args.logJSON:
        logger.info("Logging JSON formatted currently not supported.")

    logger.info("Starting American Option example")

    if args.command_name == "load":
        logger.info(f"Processing input file {args.load_file.name}")
        process_file(args.load_file)
    elif args.command_name == "serve":
        logger.info(f"Starting gRPC Server on port {args.port}")
        serve(args.port)
    elif args.command_name == "gentasks":
        logger.info(f"Generating {args.count} output to {args.outfile.name}")
        generate_test_data(args.outfile, args.count)
    else:
        parser.print_help()


if __name__ == "__main__":
    main(sys.argv)
