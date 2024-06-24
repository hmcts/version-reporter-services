FROM alpine/k8s:1.30.0

ENV PIP_BREAK_SYSTEM_PACKAGES 1

RUN apk update && apk add python3 py3-pip openssl uuidgen bash
RUN python3 -m ensurepip && pip3 install azure-cosmos pytz
RUN helm plugin install https://github.com/fabmation-gmbh/helm-whatup

WORKDIR /app

COPY . .

ENV COSMOS_KEY="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI="" \
    MAX_VERSIONS_AWAY=2 \
    AZURE_TENANT_ID="" \
    AZURE_CLIENT_ID="" \
    AZURE_CLIENT_SECRET="" \
    ENVIRONMENT="" \
    CLUSTER_NAME=""

CMD ["/app/helm-chart-versions.sh"]
