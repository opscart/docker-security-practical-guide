FROM gcc:14.2.0

WORKDIR /app
COPY app.c .

RUN gcc -o app app.c

CMD ["./app"]
