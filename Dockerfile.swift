FROM swift:4.2.3

ENV APP_HOME /app/tool
WORKDIR $APP_HOME

COPY . .

WORKDIR /app/tool/Fetcher

CMD ["swift", "build"]
