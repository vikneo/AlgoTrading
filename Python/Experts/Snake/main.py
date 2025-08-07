from pprint import pprint
from time import sleep

from tech_analysis import get_analysis
from settings import get_connect, TIME_SLEEP

eur_usd_url = "https://ru.investing.com/technical/technical-analysis"  # EUR/USD
gbp_usd_url = "https://ru.investing.com/technical/gbp-usd-technical-analysis"  # GBP/USD

def main():
    if get_connect():
        while True:
            try:
                pprint(get_analysis(eur_usd_url))
                pprint(get_analysis(gbp_usd_url))
            except Exception as e:
                print(e)

            sleep(TIME_SLEEP)


if __name__ == '__main__':
    main()