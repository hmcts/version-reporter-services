FROM python:3.12.1-alpine3.18

RUN apk add curl coreutils yq jq openssl

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV COSMOS_KEY="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI="" \
    DESIRED_VERSION="" \
    AZURE_TENANT_ID="" \
    AZURE_CLIENT_ID="" \
    AZURE_CLIENT_SECRET="" \
    ENVIRONMENT="" \
    SERVER_IP="" \
    HUB_SUBSCRIPTION_ID=""

CMD [ "python", "./main.py" ]