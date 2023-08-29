FROM python:3.11.5-alpine3.18

WORKDIR /usr/src/app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV COSMOSDB_URI="" \
    COSMOSDB_PRIMARY_KEY="" \
    COSMOSDB_DATABASE=""\
    COSMOSDB_CONTAINER=""

CMD [ "python", "./main.py" ]