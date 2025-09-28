import datetime
import json
import os
from pathlib import Path
from time import sleep
from typing import Dict

import requests
from bs4 import BeautifulSoup, ResultSet
from requests import Response

BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "data_json"
DATA_DIR.mkdir(exist_ok=True)


class PowerTrend:

    def __init__(self, base_url: str):
        self.url: str = base_url
        self.context: dict = {}
        self.bulish_trend: list = []
        self.bears_trend: list = []

    def get_analysis(self) -> Dict[str, str]:
        """
        Парсит страницу "investing.com" и собирает данные по отдельным валютным парам.

        :param currency_pair: str - url c валютной парой;
        :return: Dict[str, str] - словарь с детальной информацией по валютной паре;
        """
        try:
            page: Response = requests.get(self.url)
            soup: BeautifulSoup = BeautifulSoup(page.text, "html.parser")

            title_pair = soup.find("a", attrs={"id": "quoteLink"})
            data_now = datetime.datetime.today().strftime("%d-%m-%Y %H:%M:%S")
            data_vol: ResultSet = soup.find_all(
                "span", attrs={"class": "uppercaseText"}
            )
            indicators: ResultSet = soup.find_all("p", attrs={"class": "inlineblock"})
            self.context.update(title=title_pair["title"], date_time=data_now)  # type: ignore

            for name in data_vol:
                self.context.update(resume=name.text)

            self.context.update(results=self.details(indicators))
        except OSError as err:
            self.context.update(
                error=type(err),
                error_message=str(err),
            )

        self.save_file()
        return self.context

    def details(self, data: ResultSet) -> Dict[str, str]:
        """
        Собираем детальную информацию по уровням сигналов индикаторов
        и возвращаем данные в виде словаря.

        :param data: ResultSet - данные индикаторов;
        :return: Dict[str, str] - упакованный словарь с детальной информацией;
        """

        data_dict: Dict[str, str] = {}
        indicator: Dict[str, str] = {}
        avg: Dict[str, str] = {}
        cnt = 0

        for statistic in data:
            _res: str = json.dumps(statistic.text.strip(), ensure_ascii=False)
            res: str = json.loads(_res)

            key = res.split(":")[0]
            value = res.split(":")[1]

            if key.lower() == "покупать":
                self.bulish_trend.append(int(value))
            if key.lower() == "продавать":
                self.bears_trend.append(int(value))

            if cnt <= 3:
                indicator[key] = value
                cnt += 1
            else:
                avg[key] = value

        full_ind = abs(self.bulish_trend[0] - self.bears_trend[0])
        full_avg = abs(self.bulish_trend[1] - self.bears_trend[1])
        full_trend = round((full_ind + full_avg * 100) / 24, 2)
        bulish = round((sum(self.bulish_trend) * 100) / 24, 2)
        bears = round((sum(self.bears_trend) * 100) / 24, 2)

        # noinspection PyTypeChecker
        data_dict.update(
            indicator=indicator,
            avg=avg,
            bulish_trend=bulish,
            bears_trend=bears,
            index_trend=full_trend,
        )  # type: ignore

        return data_dict

    def save_file(self):
        try:
            title = self.context["title"].replace("/", "_")
            file_name = f"{title.split(' ')[0]}_Data.json"
            path_to_file = os.path.join(DATA_DIR, file_name)
            print(self.context["date_time"])
            print(f"{title} \t: - Считан!")
            text = json.dumps(self.context, ensure_ascii=False)

            with open(path_to_file, "w", encoding="utf8") as file:
                file.write(f"{text}\n")
        except KeyError as err:
            print("Описание Ошибки: - ", err)


if __name__ == "__main__":
    # from Python.Experts.Snake.config.currency_pair import curr_pairs
    curr_pairs = [
        "https://ru.investing.com/technical/technical-analysis",  # EUR/USD
        "https://ru.investing.com/technical/gbp-usd-technical-analysis",  # GBP/USD
        "https://ru.investing.com/technical/usd-jpy-technical-analysis",  # USD/JPY
    ]

    while True:
        for pair in curr_pairs:
            trend = PowerTrend(pair)
            trend.get_analysis()
            sleep(2)
        sleep(300)
