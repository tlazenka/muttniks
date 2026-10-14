FROM swift:6.4

RUN apt-get update \
    && apt-get install -y --no-install-recommends libsqlite3-dev sqlite3 pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY . .
RUN swift build
