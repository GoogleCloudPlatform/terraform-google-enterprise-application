
# American Option Example Library

## Overview

This is an example Python script using [Quantlib](https://www.quantlib.org/) in order
to calculate American Option prices. This is provided purely as an example and is not
intended to be used as-is for financial pricing.

## Setup

There is a provided [Dockerfile](Dockerfile) and a [setup script](setup.sh) to
configure a virtual environment and generate protobuf code.

You can run `setup.sh` locally for development purposes and it can also be used
in the `Dockerfile`.

## Running locally

### Setup the virtual environment

Run setup.sh:

```sh
./setup.sh
```

### Generate test data

Generate 1000 example tasks:

```sh
.venv/bin/python3 main.py gentasks --count 1000 tasks.jsonl
```

### With the file directly

Directly run pricer with the test data:

```sh
.venv/bin/python3 main.py load tasks.jsonl
```

### With gRPC

Run the pricing engine locally on the default port 2002:

```sh
.venv/bin/python3 main.py serve
```

In a separate command prompt, [grpcurl](https://github.com/fullstorydev/grpcurl)  with the test data to try it out:
to generate JSON test data for the pricing library. This will only send in the
first request.

```sh
head -n 1 tasks.jsonl | grpcurl -d @ -plaintext localhost:2002 main.PricingService/CalcPrices
```

## Running in a container

### Build the container

```sh
docker build -t pricer .
```

### Generate test data

Generate 1000 example tasks:

```sh
docker run pricer gentasks --count 1000 - > tasks.jsonl
```

### With the file directly

Directly run pricer with the test data:

```sh
docker run -v $PWD:/data pricer load /data/tasks.jsonl
```

### With gRPC

Run the pricing engine locally on the default port 2002:

```sh
docker run -p 2002:2002 pricer serve
```

In a separate command prompt, [grpcurl](https://github.com/fullstorydev/grpcurl)  with the test data to try it out:
to generate JSON test data for the pricing library. This will only send in the
first request.

```sh
head -n 1 tasks.jsonl | grpcurl -d @ -plaintext localhost:2002 main.PricingService/CalcPrices
```
