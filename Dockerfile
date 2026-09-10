# syntax=docker/dockerfile:1
FROM golang@sha256:3c3e25a4da13fd0478eed2df1eb35a0e667094a7124d3993a6a1d30f71c17e79 AS build
WORKDIR /src/go
COPY go/ .
RUN CGO_ENABLED=0 go build -o /out/sample ./cmd/sample

FROM gcr.io/distroless/static-debian12@sha256:d75cdd72874d4790092fcb1b058493ecf6bb5bf2b2b897045b00ff01d91843f2
COPY --from=build /out/sample /sample
EXPOSE 8080
ENTRYPOINT ["/sample"]
