// Command server is the DuoBudget sync server: a single static binary that
// stores an append-only event log in SQLite and serves push/pull to the two
// clients over a private tailnet.
//
// This is the initial skeleton. The event endpoints (POST /events,
// GET /events?after=<seq>) and the SQLite-backed store land in a later phase;
// for now it exposes only a health check so the binary and its wiring can be
// built and tested.
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	addr := ":8080"
	if p := os.Getenv("PORT"); p != "" {
		addr = ":" + p
	}

	log.Printf("duobudget sync server listening on %s", addr)
	if err := http.ListenAndServe(addr, newServer()); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

// newServer builds the HTTP handler for the sync server.
func newServer() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", handleHealth)
	return mux
}

// handleHealth responds 200 OK so orchestration and clients can probe liveness.
func handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "ok")
}
