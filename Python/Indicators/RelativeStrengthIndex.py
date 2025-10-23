from datetime import datetime
from typing import Any

import pandas as pd
from technical_indicator import RSI


class RelativeStrengthIndex:
    def __init__(
        self,
        mt5,
        symbol: str = "EURUSD",
        period: int = 14,
    ):
        self.mt5 = mt5
        self.symbol = symbol
        self.period = period

    def __get_bars(self):
        """
        Получаем количество баров с ценами и меткой времени.
        :return: DataFrame
        """
        rates: pd.DataFrame = pd.DataFrame(
            self.mt5.copy_rates_from_pos(self.symbol, self.mt5.TIMEFRAME_M5, 0, 47),
        )
        rates["time"] = [datetime.fromtimestamp(x) for x in rates["time"]]

        return rates

    def calculate(self) -> Any | float:
        """
        Метод выбирает цены по закрытию "close" и передает массив
        в конструктор индикатора RSI;
        :return: float со значением индикатора RSI для текущей цены;
        """
        rates = self.__get_bars()
        close_price = [i for i in rates["close"]]
        rsi = RSI(close_price, self.period)

        return round(rsi.calculate_rsi(), 2)
