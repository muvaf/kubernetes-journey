FROM python:3.7-alpine

RUN apk add --no-cache gcc musl-dev linux-headers

WORKDIR /code

ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0

COPY . .
RUN pip install -r requirements.txt

EXPOSE 5000

CMD ["flask", "run"]