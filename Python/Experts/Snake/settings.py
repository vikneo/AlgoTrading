from os import getenv
from dotenv import load_dotenv

import MetaTrader5 as mt5   # ignore type

load_dotenv()


LOGIN = int(getenv("LOGIN_DEMO"))
SERVER = getenv("SERVER")
PASSWORD = getenv("PASSWORD_DEMO")

TIME_SLEEP = 10 * 60

def get_connect() -> bool:
    # установим подключение к терминалу MetaTrader 5 на указанный торговый счет
    if not mt5.initialize(
            login=LOGIN,
            server=SERVER,
            password=PASSWORD,
    ):
        print("initialize() failed, error code =", mt5.last_error())
        # quit()
        return False

    return True