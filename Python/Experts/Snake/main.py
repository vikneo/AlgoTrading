from time import sleep

from config.settings import TIME_SLEEP
from snake import snake

def main():
    while True:
        try:
            snake.run()
        except Exception as e:
            print(e)

        sleep(TIME_SLEEP)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt as e:
        print(e)