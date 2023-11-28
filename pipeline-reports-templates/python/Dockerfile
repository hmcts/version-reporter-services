FROM python:3.12.0-alpine3.18
RUN apk add --upgrade py3-distutils-extra

WORKDIR /usr/src/app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV COSMOS_KEY="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI=""

CMD [ "python", "./main.py" ]