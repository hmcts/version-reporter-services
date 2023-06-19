FROM python:3.11.4-alpine3.18

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV COSMOSDB_URI="" \
    COSMOSDB_PRIMARY_KEY="" \
    COSMOSDB_DATABASE="" \
    COSMOSDB_CONTAINER="" \
    PANOS_HOSTNAME="" \
    PANOS_USERNAME="" \
    PANOS_PASSWORD="" \
    PANOS_API_KEY=""

CMD [ "python", "./main.py" ]