FROM alpine:3.20.0

ENV PIP_BREAK_SYSTEM_PACKAGES 1

RUN apk update && apk add curl coreutils yq jq openssl github-cli uuidgen bash python3 py3-pip

WORKDIR /app

COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .

# VAULT NAME is used when sourcing secrets from volume mounts
# SECRET PATH is used if a custom file path is used for those mounts (default: /mnt/secrets/)


ENV VAULT_NAME="" \
    SECRET_PATH="" \
    COSMOS_KEY="" \
    COSMOS_DB_NAME="reports" \
    COSMOS_DB_CONTAINER="helmcharts" \
    COSMOS_DB_URI="" \
    CLUSTER_NAME=""

RUN chmod +x /app/set_env.sh

CMD ["/app/entrypoint.sh"]