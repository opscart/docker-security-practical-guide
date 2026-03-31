FROM gcc:latest

WORKDIR /app
COPY app.c .

RUN gcc -o app app.c

CMD ["./app"]
