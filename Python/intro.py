from os import getenv
from dotenv import load_dotenv

from datetime import datetime
import matplotlib.pyplot as plt
import pandas as pd
from pandas.plotting import register_matplotlib_converters

register_matplotlib_converters()
import MetaTrader5 as mt5

load_dotenv()

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

# запросим статус и параметры подключения
print(mt5.terminal_info())
# получим информацию о версии MetaTrader 5
print(mt5.version())

# запросим 1000 тиков с EURAUD
eur_aud_ticks = mt5.copy_ticks_from(
    "EURAUDrfd",
    datetime(2020, 1, 28, 13),
    1000,
    mt5.COPY_TICKS_ALL,
)
# запросим тики с AUDUSD в интервале 2019.04.01 13:00 - 2019.04.02 13:00
aud_usd_ticks = mt5.copy_ticks_range(
    "AUDUSDrfd",
    datetime(2020, 1, 27, 13),
    datetime(2020, 1, 28, 13),
    mt5.COPY_TICKS_ALL,
)

# получим бары с разных инструментов разными способами
eur_usd_rates = mt5.copy_rates_from(
    "EURUSDrfd", mt5.TIMEFRAME_M1,
    datetime(2025, 1, 28, 13),
    1000,
)
eur_gbp_rates = mt5.copy_rates_from_pos(
    "EURGBPrfd", mt5.TIMEFRAME_M1,
    0,
    1000,
)
eur_cad_rates = mt5.copy_rates_range(
    "EURCADrfd",
    mt5.TIMEFRAME_M1,
    datetime(2020, 1, 27, 13),
    datetime(2020, 1, 28, 13),
)

# завершим подключение к MetaTrader 5
mt5.shutdown()

# DATA
# print('euraud_ticks(', len(euraud_ticks), ')')
for val in eur_aud_ticks[:10]: print(val)

# print('audusd_ticks(', len(audusd_ticks), ')')
for val in aud_usd_ticks[:10]: print(val)

# print('eurusd_rates(', len(eurusd_rates), ')')
if eur_usd_rates:
    for val in eur_usd_rates[:10]: print(val)

# print('eurgbp_rates(', len(eurgbp_rates), ')')
for val in eur_gbp_rates[:10]: print(val)

# print('eurcad_rates(', len(eurcad_rates), ')')
for val in eur_cad_rates[:10]: print(val)

# PLOT
# создадим из полученных данных DataFrame
ticks_frame = pd.DataFrame(eur_aud_ticks)
# сделаем отрисовку тиков на графике
plt.plot(ticks_frame['time'], ticks_frame['ask'], 'r-', label='ask')
plt.plot(ticks_frame['time'], ticks_frame['bid'], 'b-', label='bid')

# выведем легенды
plt.legend(loc='upper left')

# добавим заголовок
plt.title('EURAUD ticks')

# покажем график
plt.show()
