# Single static binary, cgo-free (modernc.org/sqlite lands in a later phase).
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
# COPY go.sum ./   # re-enable once external deps are added
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/duobudget-server .

FROM gcr.io/distroless/static-debian12
COPY --from=build /out/duobudget-server /duobudget-server
EXPOSE 8080
VOLUME ["/data"]
ENTRYPOINT ["/duobudget-server"]
