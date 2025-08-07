import json
from datetime import datetime
from pprint import pprint
from typing import Dict, Any

import requests
from bs4 import BeautifulSoup, ResultSet
from bs4.element import Tag
from requests import Response

news_url = "https://ru.investing.com/economic-calendar/"


def get_news(url: str) -> Dict[str, str | Any]:
    """
    Считывает "Экономический календарь" и наполняет словарь данными за текущий день.

    :param url: Str - url страницы "Экономический календарь" на investing.com.
    :return: Dict[str, str] - словарь с детальной информацией по новостям с важностью ***;
    """
    context: Dict[str, Any] = {}

    html = requests.get(url)
    soup = BeautifulSoup(html.text, "html.parser")
    results: ResultSet = soup.find_all("tr", attrs={"class": "js-event-item"})

    context.update(
        datetime=datetime.now().strftime("%Y-%m-%d"),
    )
    news_list = []

    for event in results:
        time: Tag = event.find("td", attrs={"class": "first left time js-time"})
        stars: Tag = event.find_all('i', attrs={"class": "grayFullBullishIcon"})
        country: Tag = event.find("td", attrs={"class": "left flagCur noWrap"})
        content: Tag = event.find("td", attrs={"class": "left event"})
        fact: Tag = event.find("td", attrs={"class": "event-528809-actual"})
        forecast: Tag = event.find("td", attrs={"class": "event-528809-forecast"})
        previous: Tag = event.find("td", attrs={"class": "event-528809-previous"})

        if len(stars) >= 2:
            news_list.append(
                        [
                            time.text,
                            len(stars) * "*",
                            country.text.strip(),
                            content.text.strip(),
                            fact.text if fact else "",
                            forecast.text if forecast else "",
                            previous.text if previous else "",
                        ]
            )

        context.update(
            results=news_list,
        )

    return context


if __name__ == "__main__":
    news = get_news(news_url)
    pprint(news)
