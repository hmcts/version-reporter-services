FROM python:3.11.4-alpine3.18

RUN apk update && apk add curl coreutils yq jq openssl github-cli PyGithub
RUN pip3 install azure-cosmos pytz

WORKDIR /app

COPY . .

ENV COSMOS_KEY="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI="" \
    MAX_DAYS_AWAY=3 \
    MAX_REPOS=300 \
    GITHUB_TOKEN=""

CMD ["/app/renovate-prs.sh"]
