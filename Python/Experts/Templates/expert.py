import time

import MetaTrader5 as mt5  # type: ignore
import pandas as pd

SYMBOL = "EURUSD"


def open_order(
    symbol,
    volume,
    order_type,
    deviation,
    magic,
    stop_loss,
    take_profit,
):
    """
    Функция для открытия ордера на покупку или на продажу;
    :param symbol:
    :param volume:
    :param order_type:
    :param deviation:
    :param magic:
    :param stop_loss:
    :param take_profit:
    :return:
    """
    _tick = mt5.symbol_info_tick(symbol)

    order_dict = {
        "buy": mt5.ORDER_TYPE_BUY,
        "sell": mt5.ORDER_TYPE_SELL,
    }
    price_dict = {
        "buy": _tick.ask,
        "sell": _tick.bid,
    }
    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": volume,
        "type": order_dict[order_type],
        "price": price_dict[order_type],
        "deviation": deviation,
        "magic": magic,
        "sl": stop_loss,
        "tp": take_profit,
    }

    return mt5.order_send(request)


def get_signal_indicator(symbol, time_frame):
    """
    Получения данных баров по ценам закрытия;
    Построение скользящих MA;
    :param symbol:
    :param time_frame:
    :return:
    """
    bars1 = mt5.copy_rates_from_pos(symbol, time_frame, 1, 20)
    bars2 = mt5.copy_rates_from_pos(symbol, time_frame, 1, 25)
    bars1_df = pd.DataFrame(data=bars1)
    bars2_df = pd.DataFrame(data=bars2)

    sma_1 = bars1_df.close.mean()
    sma_2 = bars2_df.close.mean()

    if round(sma_1, 5) != round(sma_2, 5):
        if sma_1 > sma_2:
            print("BUY Signal")
            return "buy"
        elif sma_1 < sma_2:
            print("SELL Signal")
            return "sell"

    return None


initialize = mt5.initialize()
if initialize:
    print("Initialization Successful to Metatrader5")

while True:
    symbol_info = mt5.symbol_info(SYMBOL)
    tick = mt5.symbol_info_tick(SYMBOL)
    number_of_pos = len(
        list(filter(lambda pos: pos.symbol == SYMBOL, mt5.positions_get()))
    )

    if number_of_pos == 0:
        signal = get_signal_indicator(symbol=SYMBOL, time_frame=mt5.TIMEFRAME_M5)

        if signal == "buy":
            order = open_order(
                symbol=SYMBOL,
                volume=0.01,
                deviation=10,
                magic=1234,
                order_type="buy",
                stop_loss=tick.ask - 50 * symbol_info.point,
                take_profit=tick.ask + 50 * symbol_info.point,
            )
        elif signal == "sell":
            order = open_order(
                symbol=SYMBOL,
                volume=0.01,
                deviation=10,
                magic=1234,
                order_type="sell",
                stop_loss=tick.bid + 50 * symbol_info.point,
                take_profit=tick.bif - 50 * symbol_info.point,
            )
    time.sleep(1)
