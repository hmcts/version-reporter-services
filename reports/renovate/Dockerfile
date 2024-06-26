FROM alpine:3.20.0

ENV PIP_BREAK_SYSTEM_PACKAGES 1

RUN apk update && apk add curl coreutils yq jq openssl github-cli uuidgen bash python3 py3-pip
RUN pip3 install azure-cosmos pytz

WORKDIR /app

COPY . .

ENV VAULT_NAME="" \
    SECRET_PATH="" \
    COSMOS_KEY="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI="" \
    MAX_DAYS_AWAY=3 \
    MAX_REPOS=300 \
    GITHUB_TOKEN=""

RUN chmod +x /app/script.sh && source set_env.sh

CMD ["/app/renovate-prs.sh"]
