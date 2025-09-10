from pprint import pprint

import MetaTrader5 as mt5  # type: ignore
from analysis.tech_analysis import get_analysis
from config.currency_pair import curr_pairs
from config.settings import LOGIN, PASSWORD, SERVER


class Snake:

    def __init__(
        self,
        lots: float,
        deviation: int,
        login: int,
        server: str,
        password: str,
        sl: int = 100,  # stop_loss
        tp: int = 100,  # take_profit
        magic: int = 1234,  # magic number - ID expert
    ) -> None:
        self.lots = lots
        self.sl = sl
        self.tp = tp
        self.magic = magic
        self.deviation = deviation
        self.login = login
        self.server = server
        self.password = password
        self.symbol = "EURUSDrfd"  # temporary
        self.tickets: list[str] = []

    def __connect(self) -> bool:
        # установим подключение к терминалу MetaTrader 5 на указанный торговый счет
        if not mt5.initialize(
            login=self.login,
            server=self.server,
            password=self.password,
        ):
            print("initialize() failed, error code =", mt5.last_error())
            quit()
        return True

    def run(self) -> None:
        if self.__connect():
            try:
                for pair in curr_pairs:
                    pprint(get_analysis(pair))
                self.get_orders()
                self.get_test_position()
            except OSError as e:
                print(e)
            finally:
                mt5.shutdown()

    def get_orders(self):
        """
        Получает все свои открытые позиции.
        :return: None.
        """
        self.tickets = mt5.orders_get(self.symbol)
        if self.tickets:
            return self.tickets

        return None

    def get_test_position(self):
        for ticket in self.tickets:
            order = mt5.positions_get(ticket=ticket)
            if order:
                print("Order symbol = ", order[0].symbol)
                print("Order ticket = ", order[0].ticket)
                print("Order magic = ", order[0].magic)
                print("Order price = ", order[0].profit)
            else:
                print("Order not found")

    def get_indicator(self):
        pass

    def _order_send(self, price):

        point = mt5.symbol_info(self.symbol).point

        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": self.symbol,
            "volume": self.lots,
            "type": mt5.ORDER_TYPE_BUY,
            "price": price,
            "sl": price - self.sl * point,
            "tp": price + self.tp * point,
            "deviation": self.deviation,
            "magic": self.magic,
            "comment": "python script",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_RETURN,
        }

        # выведем информацию о действующих ордерах на символе EURUSD
        result = mt5.order_send(request)
        print(
            "1. order_send(): by {} {} lots at {} with deviation={} points".format(
                self.symbol, self.lots, price, self.deviation
            )
        )
        if result.retcode != mt5.TRADE_RETCODE_DONE:
            print("2. order_send failed, retcode={}".format(result.retcode))
            # запросим результат в виде словаря и выведем поэлементно
            result_dict = result._asdict()
            for field in result_dict.keys():
                print("   {}={}".format(field, result_dict[field]))
                # если это структура торгового запроса, то выведем её тоже поэлементно
                if field == "request":
                    trade_request_dict = result_dict[field]._asdict()
                    for tradereq_filed in trade_request_dict:
                        print(
                            "       trade_request: {}={}".format(
                                tradereq_filed, trade_request_dict[tradereq_filed]
                            )
                        )


snake = Snake(lots=0.01, deviation=20, login=LOGIN, server=SERVER, password=PASSWORD)

if __name__ == "__main__":
    snake = Snake(0.01, 20, LOGIN, SERVER, PASSWORD)
    snake.run()
