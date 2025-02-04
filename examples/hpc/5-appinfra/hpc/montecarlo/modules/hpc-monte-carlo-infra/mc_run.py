#!/usr/bin/env python3
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

#  Copyright 2023 Google LLC
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

"""
Run MC simulation for VaR portfolio risk
"""

import avro.schema
import io
import numpy
import os
import time
import yfinance as yf

from absl import app
from absl import flags
from avro.io import DatumWriter, BinaryEncoder
from datetime import datetime
from datetime import timedelta
from google.cloud import pubsub_v1
from google.cloud.pubsub import SchemaServiceClient

FLAGS = flags.FLAGS

flags.DEFINE_string("project_id", None, "Google Cloud Project ID")
flags.DEFINE_string("incoming_topic_id", None, "Pubsub Topic ID for Pubsub to Bigquery")
flags.DEFINE_string(
    "incoming_topic_schema", None, "Pubsub Schema for Pubsub to Bigquery"
)
flags.DEFINE_integer(
    "ticker_index", os.getenv("JOB_COMPLETION_INDEX"), "Index of ticker in ticker_list"
)
flags.DEFINE_list(
    "ticker_list", "GOOG,ADM,ADP", "List of Stock Ticker to run, default GOOG"
)
flags.DEFINE_string(
    "start_date", "2022-01-01", "Start data for data query, default 2022-01-01"
)
flags.DEFINE_integer(
    "calendar_days", 365, "How many calendar days to include in the calculation"
)
flags.DEFINE_integer(
    "epoch_time",
    f"{int(time.time())}",
    "Epoch time, number of seconds since January 1st, 1970 at 00:00:00 UTC.",
)
flags.DEFINE_integer("iterations", 100, "Number of iterations to run.")
flags.DEFINE_boolean("print_raw", True, "Dump raw data.")

flags.mark_flag_as_required("project_id")
flags.mark_flag_as_required("incoming_topic_id")
flags.mark_flag_as_required("incoming_topic_schema")


class VaRSimulator:
    def __init__(self):
        self.ticker = FLAGS.ticker_list[FLAGS.ticker_index]
        self.start_date = FLAGS.start_date
        self.end_date = f'{(datetime.strptime(FLAGS.start_date,"%Y-%m-%d") + timedelta(days = FLAGS.calendar_days)).date()}'
        self.calendar_days = FLAGS.calendar_days
        self.epoch_time = FLAGS.epoch_time
        self.iteration = 1

    def get_data(self):
        self.get_historical_data_yahoo()

    def get_historical_data_yahoo(self):
        # get historical market data: https://pypi.org/project/yfinance/

        self.raw_data = yf.Ticker(self.ticker).history(
            start=self.start_date, end=self.end_date
        )
        self.data = self.raw_data.Close
        if len(self.data) == 0:
            print(f"No data for ticker {self.ticker}")
            exit(0)
        print("len = ", len(self.data))

    def print_raw(self):
        print(self.get_stats())
        print(type(self.raw_data))
        print(self.raw_data)

    def get_stats(self):
        close = self.data
        self.first = close[0]
        self.last = close[-1]
        self.trading_days = len(close)
        self.cagr = (self.last / self.first) ** (365.0 / self.calendar_days) - 1.0
        self.volatility = self.data.pct_change().std()
        return (self.first, self.last, self.trading_days, self.cagr, self.volatility)

    def run_simulation(self):
        returns = (
            numpy.random.normal(
                self.cagr / self.trading_days, self.volatility, self.trading_days
            )
            + 1
        )
        returns = numpy.insert(returns, 0, 1.0)
        self.simulation_results = self.last * returns.cumprod()
        return self.simulation_results

    def create_object(self):
        self.object = {
            "ticker": self.ticker,
            "epoch_time": self.epoch_time,
            "iteration": self.iteration,
            "start_date": self.start_date,
            "end_date": self.end_date,
            "simulation_results": list(
                map(lambda x: {"price": x}, self.simulation_results)
            ),
        }
        return self.object


class PubsubToBiquery:
    def __init__(self):
        self.project_id = FLAGS.project_id

        self.publisher_client = pubsub_v1.PublisherClient()
        self.topic_path = self.publisher_client.topic_path(
            self.project_id, FLAGS.incoming_topic_id
        )

        self.schema_client = SchemaServiceClient()
        self.schema_path = self.schema_client.schema_path(
            self.project_id, FLAGS.incoming_topic_schema
        )

        pubsub_schema = self.schema_client.get_schema(
            request={"name": self.schema_path}
        )
        avro_schema = avro.schema.parse(pubsub_schema.definition)

        self.writer = DatumWriter(avro_schema)

    def publish_record(self, record):
        byte_stream = io.BytesIO()
        encoder = BinaryEncoder(byte_stream)
        self.writer.write(record, encoder)
        data = byte_stream.getvalue()
        byte_stream.flush()
        future = self.publisher_client.publish(self.topic_path, data)
        if FLAGS.print_raw:
            print(f"Published message ID: {future.result()}")


def main(argv):
    vr = VaRSimulator()
    pbbq = PubsubToBiquery()

    vr.get_data()
    vr.get_stats()

    for i in range(FLAGS.iterations):
        vr.iteration = i
        vr.run_simulation()
        pbbq.publish_record(vr.create_object())

    if FLAGS.print_raw:
        vr.print_raw()


if __name__ == "__main__":
    """ This is executed when run from the command line """
    app.run(main)
