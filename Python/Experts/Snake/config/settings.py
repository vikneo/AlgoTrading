from os import getenv

from dotenv import load_dotenv

load_dotenv()

LOGIN = int(getenv("LOGIN_DEMO"))
SERVER = getenv("SERVER")
PASSWORD = getenv("PASSWORD_DEMO")

TIME_SLEEP = 1 * 60
