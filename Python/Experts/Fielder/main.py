from time import sleep

import MetaTrader5 as mt5
from expert import Fielder

exp = Fielder(symbol="EURUSD", rsi_period=9)

while True:
    try:
        exp.run()
        sleep(0.2)
    except (KeyError, KeyboardInterrupt):
        mt5.shutdown()
        print("Seance close")
        break
