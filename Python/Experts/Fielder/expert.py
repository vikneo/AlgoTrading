import os

import MetaTrader5 as mt5  # type: ignore
from dotenv import load_dotenv

from Python.Indicators.Envelopes import Envelopes

load_dotenv()

LOGIN = int(os.getenv("LOGIN"))  # type: ignore
PASSWORD = os.getenv("PASSWORD")
SERVER = os.getenv("SERVER")


class Fielder:

    def __init__(self, symbol: str):
        self.login = LOGIN
        self.password = PASSWORD
        self.server = SERVER
        self.symbol = symbol

        if mt5.initialize(login=self.login, password=PASSWORD, server=self.server):
            self.digits = mt5.symbol_info(self.symbol).digits
            print("MT5 initialized")

    def __initialize(self):
        try:
            if not mt5.initialize(
                login=self.login, password=PASSWORD, server=self.server
            ):
                raise KeyError("MT5 initialized failed")
        except KeyError as error:
            print(error)

    def run(self):

        envelopes = Envelopes(mt5=mt5)
        env_up, env_low = envelopes.get_indicator()
        width_channel = round((env_up[-1] - env_low[-1]) * 10**self.digits, 2)

        print(width_channel)

        print(env_up[-1], env_low[-1])
        if mt5.symbol_info(self.symbol).bid > env_up[-1]:
            print("Signal Sell")
            # print(f"Envelopes blue - {env_up}")
        elif mt5.symbol_info(self.symbol).ask < env_low[-1]:
            print("Signal Buy")
            # print(f"Envelopes red - {env_low}")
