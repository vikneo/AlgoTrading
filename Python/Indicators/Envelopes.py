from datetime import datetime

import numpy as np
import pandas as pd


class Envelopes:
    """
    Описывает индикатор Envelopes.

    Значения по умолчанию:
        period = 14,
        deviation = 0.1,
        method = 3,
        applied_price = 2,
        shift = 0,
    Parameters `method`:
        0 - SMA;
        1 - EMA;
        2 - SMMA;
        3 - LWMA;
    Parameters `applied_Price`:
        0: "PRICE_OPEN",
        1: "PRICE_CLOSE",
        2: "PRICE_HIGH",
        3: "PRICE_LOW",
    """

    def __init__(
        self,
        mt5,
        symbol: str = "EURUSD",
        period: int = 14,
        deviation: float = 0.05,
        method: int = 3,
        applied_price: int = 2,
        shift: int = 0,
    ):
        self.mt5 = mt5
        self.symbol = symbol
        self.period = period
        self.deviation = deviation
        self.method = self.__ma_method(method)
        self.applied_price = self.__applied_price(applied_price)
        self.shift = shift
        self.env_up = 0
        self.env_low = 0

    @staticmethod
    def __ma_method(method: int) -> str:
        _METHOD = {
            0: "MODE_SMA",
            1: "MODE_EMA",
            2: "MODE_SMMA",
            3: "MODE_LWMA",
        }
        return _METHOD[method]

    @staticmethod
    def __applied_price(price: int) -> str:
        _PRICE = {
            0: "PRICE_OPEN",
            1: "PRICE_CLOSE",
            2: "PRICE_HIGH",
            3: "PRICE_LOW",
        }
        return _PRICE[price]

    def __str__(self) -> str:
        return (
            f"Envelopes: "
            f"(period-{self.period}); "
            f"(Upper Line-{self.env_up}; "
            f"Lower Line-{self.env_low}; "
        )

    def set_env_up(self, price):
        self.env_up = price

    def set_env_low(self, price):
        self.env_low = price

    def get_env_up(self):
        return self.env_up

    def get_env_low(self):
        return self.env_low

    def __get_bars(self):
        """
        Получаем количество баров с ценами и меткой времени.
        :return: DataFrame
        """
        rates: pd.DataFrame = pd.DataFrame(
            self.mt5.copy_rates_from_pos(self.symbol, self.mt5.TIMEFRAME_M5, 0, 20)
        )
        rates["time"] = [datetime.fromtimestamp(x) for x in rates["time"]]

        return rates

    def __get_lwma(self, price) -> np.ndarray:
        """
        Подсчитывается средняя скользящая по методу MODE_LWMA
        :param price: параметр цены (close, high, low, open)
        :return: массив данных
        """
        res = np.zeros(price.shape[0])
        for i in range(price.shape[0]):
            if i < self.period - 1:
                # fmt: off
                res[i] = price[0:i + 1].mean()
                # fmt: on
            else:
                koff = self.period
                x = 0
                sum_val = 0
                sum_koff = 0
                while koff > 0:
                    sum_val += price[i - x] * koff
                    sum_koff += koff
                    koff -= 1
                    x += 1
                res[i] = sum_val / sum_koff
        return res

    def calculate(self) -> None:
        """
        Метод подсчитывает границы индикатора по ценам `HIGH и по ценам `LOWER`;
        :param rates: массив данных с ценами боров и меткой времени;
        :return: tuple с ценами границ верхней и нижней линии индикатора;
        """
        rates = self.__get_bars()
        lwma_high = self.__get_lwma(rates["high"])[-1]
        lwma_low = self.__get_lwma(rates["low"])[-1]

        env_up = ((self.deviation / 0.01) * 11.8) * self.mt5.symbol_info(
            self.symbol
        ).point + lwma_high
        # fmt: off
        env_low = (
            lwma_low - ((self.deviation / 0.01) * 11.8) * self.mt5.symbol_info(self.symbol).point
        )
        # fmt: on
        self.set_env_up(env_up)
        self.set_env_low(env_low)

    def get_indicator(self) -> tuple:
        """
        Получаем цены границ индикатора
        :return:
        """
        self.calculate()
        return self.get_env_up(), self.get_env_low()
