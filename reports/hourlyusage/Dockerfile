FROM python:3.11.5-alpine3.18

WORKDIR /usr/src/app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV AZURE_STORAGE_CONTAINER="" \
    AZURE_STORAGE_URL="" \
    AZURE_STORAGE_ACCESS_KEY=""

CMD [ "python", "./main.py" ]