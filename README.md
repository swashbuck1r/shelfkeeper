# Shelfkeeper

Shelfkeeper is a small inventory service with a companion text-statistics tool.

- `go/` is an HTTP API for keeping track of items: create an item, fetch it by id, list what is
  on the shelf, and a health endpoint. It keeps state in memory and is meant to be simple to run
  and simple to read.
- `node/` is a TypeScript library and tiny CLI for summarising text: word counts, character
  histograms, and top-N terms, with a table formatter for printing the results.

## Layout

```
go/                  Go module github.com/swashbuck1r/shelfkeeper/go
  cmd/sample/         main package; listens on :8080 (override with PORT)
  internal/api/       HTTP handlers and tests
  internal/store/     in-memory item store and tests
node/                npm package @shelfkeeper/tools
  src/                stats.ts, format.ts, index.ts (exports and CLI entry)
  test/               vitest suites
Dockerfile           multi-stage build of the Go service on a distroless base
```

## Build and test

Go (1.26):

```sh
cd go
go mod download
go build ./...
go test ./...
```

Node (22+):

```sh
cd node
npm ci
npm run build
npm test
```

Docker:

```sh
docker build -t shelfkeeper .
docker run --rm -p 8080:8080 shelfkeeper
curl localhost:8080/healthz
```

## API

| Method | Path | Description |
|---|---|---|
| `GET` | `/healthz` | liveness check, returns `{"status":"ok"}` |
| `POST` | `/items` | create an item from a JSON body `{"name": "..."}` |
| `GET` | `/items/{id}` | fetch one item |
| `GET` | `/items` | list all items |

## Text tool

```sh
cd node && npm run build
echo "the quick brown fox jumps over the lazy dog the end" | node dist/index.js
```

Prints the word count and a table of the five most frequent characters.

## Contributing

Keep it small and deterministic: no network calls in tests, no time-dependent assertions, and
never commit credentials or tokens of any kind.
