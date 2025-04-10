FROM alpine/k8s:1.32.3

ENV PIP_BREAK_SYSTEM_PACKAGES 1

RUN apk update && apk add curl coreutils yq jq openssl github-cli uuidgen bash python3 py3-pip
RUN pip3 install azure-cosmos pytz
RUN helm plugin install https://github.com/fabmation-gmbh/helm-whatup

WORKDIR /app

COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .

# VAULT NAME is used when sourcing secrets from volume mounts
# SECRET PATH is used if a custom file path is used for those mounts (default: /mnt/secrets/)


ENV VAULT_NAME="" \
    SECRET_PATH="" \
    COSMOS_DB_NAME="reports" \
    COSMOS_DB_CONTAINER="helmcharts" \
    COSMOS_DB_URI="" \
    CLUSTER_NAME="" \
    ENVIRONMENT=""


RUN chmod +x /app/set_env.sh

CMD ["/app/entrypoint.sh"]