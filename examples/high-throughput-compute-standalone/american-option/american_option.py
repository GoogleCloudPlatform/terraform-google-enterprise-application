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


import logging

from request_pb2 import PricingRequest
from response_pb2 import PricingResponse

import QuantLib as ql


MarketData = PricingRequest.MarketData
Decimal = PricingRequest.Decimal
Date = PricingRequest.Date

logger = logging.getLogger(__name__)


def to_dbl(decimal: PricingRequest.Decimal) -> float:
    _NANO = 1e-9
    return decimal.units + decimal.nanos * _NANO


def to_date(date: PricingRequest.Date):
    return ql.Date(date.day, date.month, date.year)


def to_ccy(ccy: PricingRequest.Currency) -> str:
    return PricingRequest.Currency.Name(ccy)


def get_options(refdate, opts: list[MarketData.EquityOption]):
    out_opts = {}
    for opt in opts:
        ccy = to_ccy(opt.currency)

        strikes = [to_dbl(p) for p in opt.strike_prices]
        expirations = [to_date(d) for d in opt.strike_dates]

        volMatrix = ql.Matrix(len(strikes), len(expirations))
        for i in range(len(strikes)):
            for j in range(len(expirations)):
                volMatrix[i][j] = to_dbl(opt.implied_vols[j * len(strikes) + i])

        volatilitySurface = ql.BlackVarianceSurface(
            refdate, ql.TARGET(), expirations, strikes, volMatrix, ql.Actual365Fixed()
        )
        volatilitySurface.enableExtrapolation()

        out_opts[opt.id] = {
            "quote": ql.SimpleQuote(to_dbl(opt.spot_price)),
            "ccy": ccy,
            "surface": volatilitySurface,
        }

    return out_opts


def get_riskfree_curves(
    refdate, key, curves: list[PricingRequest.MarketData.RateCurve]
):
    out_curves = {}
    for curve in curves:
        if curve.rate_type != key:
            continue
        ccy = to_ccy(curve.currency)
        dates = [refdate] + [to_date(rd.date) for rd in curve.discounts]
        discounts = [1.0] + [to_dbl(rd.value) for rd in curve.discounts]
        out_curves[ccy] = ql.DiscountCurve(dates, discounts, ql.Actual360())

    return out_curves


def quantlib_run(req: PricingRequest) -> PricingResponse:
    if logger.isEnabledFor(logging.DEBUG):
        logger.debug(f"Processing request:\n{req}")

    # Set reference date
    refDate = to_date(req.marketdata.reference_date)
    ql.Settings.instance().evaluationDate = refDate

    # Fetch risk free curve
    curves = get_riskfree_curves(
        refDate,
        PricingRequest.MarketData.RateType.RISK_FREE_CURVE,
        req.marketdata.rate_curves,
    )

    # Fetch option volatilities
    vols = get_options(refDate, req.marketdata.equity_options)

    results = []
    for opt_req in req.american_option_request:
        ccy = to_ccy(opt_req.currency)
        exercise = ql.AmericanExercise(refDate, to_date(opt_req.expiry_date))

        # Contract prices
        payoff = ql.PlainVanillaPayoff(
            ql.Option.Call if opt_req.is_call_option else ql.Option.Put,
            to_dbl(opt_req.strike),
        )
        option = ql.VanillaOption(payoff, exercise)

        if opt_req.equity not in vols:
            raise Exception(f"no marketdata for {opt_req.equity}")

        volatility = vols[opt_req.equity]

        if ccy not in curves:
            raise Exception(f"no curve for currency {ccy}")

        if volatility["ccy"] != ccy:
            raise Exception(f"ccy of equity is {volatility.ccy} vs {ccy}")

        # No dividends
        dividendYield = ql.FlatForward(refDate, 0.00, ql.Actual365Fixed())

        # From marketdata
        process = ql.BlackScholesMertonProcess(
            ql.QuoteHandle(volatility["quote"]),
            ql.YieldTermStructureHandle(dividendYield),
            ql.YieldTermStructureHandle(curves[ccy]),
            ql.BlackVolTermStructureHandle(volatility["surface"]),
        )

        results = []
        option.setPricingEngine(ql.BaroneAdesiWhaleyApproximationEngine(process))
        results.append(option.NPV())

    response = PricingResponse(value=results)

    if logger.isEnabledFor(logging.DEBUG):
        logger.debug(f"Returning response:\n{response}")

    return response
