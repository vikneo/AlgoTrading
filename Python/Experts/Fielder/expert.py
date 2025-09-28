import os

import MetaTrader5 as mt5  # type: ignore
from dotenv import load_dotenv

from Python.Indicators.Envelopes import Envelopes
from Python.Indicators.RelativeStrengthIndex import RelativeStrengthIndex

load_dotenv()

LOGIN = int(os.getenv("LOGIN"))  # type: ignore
PASSWORD = os.getenv("PASSWORD")
SERVER = os.getenv("SERVER")


class Fielder:

    def __init__(self, symbol: str, rsi_period: int):
        self.login = LOGIN
        self.password = PASSWORD
        self.server = SERVER
        self.symbol = symbol
        self.rsi_period = rsi_period

        try:
            if mt5.initialize(login=self.login, password=PASSWORD, server=self.server):
                self.digits = mt5.symbol_info(self.symbol).digits
                print("MT5 initialized")
            else:
                raise KeyError("Invalid login or password")
        except KeyError as e:
            print("MT5 initialized failed.\n Описание: {}".format(e))

    def __get_indicators(self):
        envelopes = Envelopes(mt5=mt5)
        rsi = RelativeStrengthIndex(mt5=mt5, period=self.rsi_period)
        print("RSI : {}".format(rsi.calculate()))
        env_up, env_low = envelopes.get_indicator()
        return env_up, env_low

    def run(self):
        env_up, env_low = self.__get_indicators()
        width_channel = round((env_up[-1] - env_low[-1]) * 10**self.digits, 2)

        print(width_channel)

        print(env_up[-1], env_low[-1])
        if mt5.symbol_info(self.symbol).bid > env_up[-1]:
            print("Signal Sell")
            # print(f"Envelopes blue - {env_up}")
        elif mt5.symbol_info(self.symbol).ask < env_low[-1]:
            print("Signal Buy")
            # print(f"Envelopes red - {env_low}")
