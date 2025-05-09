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


import json
import argparse
import sys
import gzip


def generate_test_data(output, count: int = 1):
    # Get the output file (compress if needed)
    if output.name.endswith(".gz"):
        output = gzip.open(output, mode="wb")

    # Generate output
    for i in range(count):
        output.write(bytes(generate_request(), "utf8"))
        output.write(bytes("\n", "utf8"))


def generate_request() -> str:
    pyvoldates = [
        {"year": 2021, "month": 2, "day": 8},
        {"year": 2022, "month": 2, "day": 8},
        {"year": 2023, "month": 2, "day": 8},
        {"year": 2025, "month": 2, "day": 8},
        {"year": 2027, "month": 2, "day": 8},
    ]
    pyvolatilities = [
        {"nanos": 100000000},
        {"nanos": 120000000},
        {"nanos": 130000000},
        {"nanos": 150000000},
        {"nanos": 200000000},
        {"nanos": 150000000},
        {"nanos": 100000000},
        {"nanos": 200000000},
        {"nanos": 100000000},
        {"nanos": 100000000},
        {"nanos": 200000000},
        {"nanos": 100000000},
        {"nanos": 100000000},
        {"nanos": 100000000},
        {"nanos": 300000000},
    ]
    goog_pyvolstrikes = [{"units": 1450}, {"units": 1500}, {"units": 1550}]
    ezj_pyvolstrikes = [{"units": 570}, {"units": 590}, {"units": 610}]
    py_curve_discounts = [
        {"date": {"year": 2021, "month": 2, "day": 8}, "value": {"nanos": 971974410}},
        {"date": {"year": 2022, "month": 2, "day": 8}, "value": {"nanos": 940227460}},
        {"date": {"year": 2023, "month": 2, "day": 8}, "value": {"nanos": 910740310}},
        {"date": {"year": 2025, "month": 2, "day": 8}, "value": {"nanos": 854950890}},
        {"date": {"year": 2027, "month": 2, "day": 8}, "value": {"nanos": 801367500}},
        {"date": {"year": 2030, "month": 2, "day": 8}, "value": {"nanos": 724948790}},
        {"date": {"year": 2050, "month": 2, "day": 8}, "value": {"nanos": 376020590}},
    ]
    marketdata = {
        "rate_curves": [
            {
                "currency": "USD",
                "rate_type": "RISK_FREE_CURVE",
                "discounts": py_curve_discounts,
            },
            {
                "currency": "GBP",
                "rate_type": "RISK_FREE_CURVE",
                "discounts": py_curve_discounts,
            },
        ],
        "equity_options": [
            {
                "id": "GOOG",
                "currency": "USD",
                "spot_price": {"units": 1500},
                "strike_dates": pyvoldates,
                "strike_prices": goog_pyvolstrikes,
                "implied_vols": pyvolatilities,
            },
            {
                "id": "EZJ",
                "currency": "GBP",
                "spot_price": {"units": 590},
                "strike_dates": pyvoldates,
                "strike_prices": ezj_pyvolstrikes,
                "implied_vols": pyvolatilities,
            },
        ],
        "reference_date": {"year": 2021, "month": 2, "day": 5},
    }
    opt_reqs = [
        {
            "short_position": True,
            "expiry_date": {"year": 2022, "month": 5, "day": 21},
            "contract_amount": {"units": 10000},
            "strike": {"units": 1500},
            "equity": "GOOG",
            "currency": "USD",
            "business_day_convention": "MODIFIED_FOLLOWING",
            "settlement_days": 2,
            "is_call_option": False,
        },
        {
            "short_position": True,
            "expiry_date": {"year": 2022, "month": 5, "day": 21},
            "contract_amount": {"units": 10000},
            "strike": {"units": 590},
            "equity": "EZJ",
            "currency": "GBP",
            "business_day_convention": "FOLLOWING",
            "settlement_days": 2,
            "is_call_option": False,
        },
        {
            "short_position": True,
            "expiry_date": {"year": 2022, "month": 5, "day": 21},
            "contract_amount": {"units": 10000},
            "strike": {"units": 590},
            "equity": "EZJ",
            "currency": "GBP",
            "business_day_convention": "MODIFIED_FOLLOWING",
            "settlement_days": 2,
            "is_call_option": True,
        },
    ]

    return json.dumps(
        {
            "marketdata": marketdata,
            "american_option_request": opt_reqs,
        }
    )


def main(args):
    parser = argparse.ArgumentParser(
        prog="generate", description="Generate test data for american-option"
    )
    parser.add_argument(
        "-c",
        "--count",
        help="Number of output records to generate",
        type=int,
        default=1,
    )
    parser.add_argument(
        "outfile", help="Output file with JSONL records", type=argparse.FileType("wb")
    )

    args = parser.parse_args()

    # Get the output file (compress if needed)
    ofile = args.outfile
    if args.outfile.name.endswith(".gz"):
        ofile = gzip.open(ofile, mode="wb")

    # Generate output
    for i in range(args.count):
        ofile.write(bytes(generate_request(), "utf8"))
        ofile.write(bytes("\n", "utf8"))


if __name__ == "__main__":
    main(sys.argv)
