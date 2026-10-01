FROM golang:1.24.8-alpine3.22 AS build

ENV CGO_ENABLED=0
RUN go install github.com/minio/minio@RELEASE.2025-10-15T17-29-55Z && \
    go install github.com/minio/mc@RELEASE.2025-08-13T08-35-41Z

FROM alpine:3.22.2
COPY --from=build /go/bin/minio /go/bin/mc /usr/local/bin/
ENTRYPOINT ["minio"]
