import json
from typing import Dict

import requests
from bs4 import BeautifulSoup, ResultSet
from bs4.element import Tag
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
        soup: BeautifulSoup = BeautifulSoup(page.text, 'html.parser')

        title_pair: Tag = soup.find('a', attrs={'id': 'quoteLink'})
        data_vol: ResultSet = soup.find_all('span', attrs={'class': 'buy uppercaseText'})
        indicators: ResultSet = soup.find_all('p', attrs={'class': 'inlineblock'})

        context.update(title=title_pair['title'])

        for name in data_vol:
            context.update(resume=name.text)

        context.update(
            details=details(indicators)
        )
    except Exception as e:
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
    for statistic in data:
        res = json.dumps(statistic.text.strip(), ensure_ascii=False)
        res = json.loads(res)

        key = res.split(':')[0]
        value = res.split(':')[1]
        data_dict[key] = value

    return data_dict
