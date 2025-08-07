from pprint import pprint
from time import sleep

from analysis.tech_analysis import get_analysis
from config.settings import get_connect, TIME_SLEEP
from config.curremcy_pair import curr_pairs

def main():
    if get_connect():
        while True:
            try:
                for pair in curr_pairs:
                    pprint(get_analysis(pair))
            except Exception as e:
                print(e)

            sleep(TIME_SLEEP)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt as e:
        print(e)