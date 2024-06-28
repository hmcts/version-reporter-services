FROM alpine/azure_cli:1.5.6

RUN apk update 
RUN apk add python3 py3-pip openssl uuidgen bash
RUN python3 -m ensurepip
RUN pip3 install azure-cosmos pytz

WORKDIR /app

COPY . .

ENV COSMOS_KEY="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI="" \
    AZURE_TENANT_ID="" \
    AZURE_CLIENT_ID="" \
    AZURE_CLIENT_SECRET=""

CMD ["/app/aks-versions.sh"]
