FROM python:3.11.4-alpine3.18

RUN apk add curl coreutils yq jq openssl

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV COSMOS_ENDPOINT="" \
    COSMOS_KEY="" \
    COSMOSDB_DATABASE="" \
    COSMOSDB_CONTAINER="" \
    AZURE_TENANT_ID="" \
    AZURE_CLIENT_ID="" \
    AZURE_CLIENT_SECRET="" \
    DESIRED_SOFTWARE_VERSION="10.2.0"

CMD [ "python", "./main.py" ]