import os
from os import getenv
from dotenv import load_dotenv

import MetaTrader5 as mt5
import pandas as pd

load_dotenv()

# выведем данные о пакете MetaTrader5
print("MetaTrader5 package author: ", mt5.__author__)
print("MetaTrader5 package version: ", mt5.__version__)

LOGIN = int(getenv("LOGIN_DEMO"))
SERVER = getenv("SERVER")
PASSWORD = getenv("PASSWORD_DEMO")


# установим подключение к терминалу MetaTrader 5 на указанный торговый счет
if not mt5.initialize(
        login=LOGIN,
        server=SERVER,
        password=PASSWORD,
):
    print("initialize() failed, error code =", mt5.last_error())
    quit()

account_info_dict = mt5.account_info()._asdict()
for prop in account_info_dict:
    print("  {}={}".format(prop, account_info_dict[prop]))
print()

# попробуем включить показ символа EURUSD в MarketWatch
selected = mt5.symbol_select("EURUSDrfd", True)
if not selected:
    print("Failed to select EURUSDrfd")
    mt5.shutdown()
    quit()

# выведем свойства по символу EURUSD
symbol_info = mt5.symbol_info("EURUSDrfd")
if symbol_info is not None:
    # выведем данные о терминале как есть
    print(symbol_info)
    print("EURUSD: spread =", symbol_info.spread, "  digits =", symbol_info.digits)
    # выведем свойства символа в виде списка
    print("Show symbol_info(\"EURUSD\")._asdict():")

    symbol_info_dict = mt5.symbol_info("EURUSDrfd")._asdict()  # ignore type
    for prop in symbol_info_dict:
        print("  {}={}".format(prop, symbol_info_dict[prop]))

# завершим подключение к терминалу MetaTrader 5
mt5.shutdown()