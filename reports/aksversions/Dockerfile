FROM python:3.12.3-alpine3.18

RUN apk update 
RUN apk add curl coreutils yq jq openssl

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV COSMOS_KEY="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI=""

CMD [ "python", "./main.py" ]