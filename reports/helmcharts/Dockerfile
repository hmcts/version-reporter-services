FROM alpine/k8s:1.27.4

RUN apk update && apk add python3 py3-pip && pip3 install azure-cosmos
RUN apk add openssl uuidgen
RUN helm plugin install https://github.com/fabmation-gmbh/helm-whatup

COPY helm-chart-versions.sh /
COPY send-to-cosmos.py /

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

CMD ["/helm-chart-versions.sh"]
