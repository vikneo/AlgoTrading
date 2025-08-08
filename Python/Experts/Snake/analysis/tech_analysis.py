import json
from typing import Dict

import requests
from bs4 import BeautifulSoup, ResultSet
from requests import Response


def get_analysis(currency_pair: str) -> Dict[str, str]:
    """
    Парсит страницу "investing.com" и собирает данные по отдельным валютным парам.

    :param currency_pair: str - url c валютной парой;
    :return: Dict[str, str] - словарь с детальной информацией по валютной паре;
    """

    context: dict = {}
    try:
        page: Response = requests.get(currency_pair)
        soup: BeautifulSoup = BeautifulSoup(page.text, "html.parser")

        title_pair = soup.find("a", attrs={"id": "quoteLink"})
        data_vol: ResultSet = soup.find_all("span", attrs={"class": "uppercaseText"})
        indicators: ResultSet = soup.find_all("p", attrs={"class": "inlineblock"})

        context.update(title=title_pair["title"])  # type: ignore

        for name in data_vol:
            context.update(resume=name.text)

        context.update(results=details(indicators))
    except OSError as e:
        context.update(
            error=type(e),
            error_message=str(e),
        )

    return context


def details(data: ResultSet) -> Dict[str, str]:
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
        if cnt <= 3:
            indicator[key] = value
            cnt += 1
        else:
            avg[key] = value

    # noinspection PyTypeChecker
    data_dict.update(indicator=indicator, avg=avg)  # type: ignore

    return data_dict


if __name__ == "__main__":
    from Python.Experts.Snake.config.currency_pair import curr_pairs

    for pair in curr_pairs:
        print(get_analysis(pair))
