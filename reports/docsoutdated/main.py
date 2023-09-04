from bs4 import BeautifulSoup
import requests
import datefinder
from datetime import date
from datetime import datetime
from urllib.parse import urljoin

urls = []
with open("documentation-urls") as file:
    urls = file.readlines()

for url in urls:
    result = requests.get(url)
    doc = BeautifulSoup(result.text, "html.parser")
    nav = doc.find("nav", {"id": "toc", "aria-labelledby": "toc-heading"})
    if nav is not None:
        a_list = nav.find_all('a', href=True)

        for a in a_list:
            full_url = urljoin(url, a.get('href', None))
            print(f"Processing: {full_url}")
            page = requests.get(full_url)
            page_doc = BeautifulSoup(page.text, "html.parser")
            review_section = doc.find("div", {"class": "page-expiry--not-expired"})
            if review_section is not None:
                review_section = doc.find("div", {"class": "page-expiry--expired"})

            matches = datefinder.find_dates(review_section.text)
            if matches is not None:
                today = date.today()

                date_list = []
                for match in matches:
                    date_list.append(f"{match}")

                print("Today's date:", today)
                expiry = date_list.pop()
                print("Doc expiry: ", expiry)
