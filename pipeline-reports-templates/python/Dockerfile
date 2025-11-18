FROM alpine:3.22.2

RUN apk update && apk add python3 py3-pip

WORKDIR /app

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV COSMOS_KEY="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI=""

CMD [ "python", "./main.py" ]