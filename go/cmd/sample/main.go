// Command sample runs the Shelfkeeper inventory HTTP service.
package main

import (
	"log"
	"net/http"
	"os"

	"github.com/swashbuck1r/shelfkeeper/go/internal/api"
	"github.com/swashbuck1r/shelfkeeper/go/internal/store"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	a := api.New(store.New())
	addr := ":" + port
	log.Printf("listening on %s", addr)
	if err := http.ListenAndServe(addr, a.Routes()); err != nil {
		log.Fatal(err)
	}
}
