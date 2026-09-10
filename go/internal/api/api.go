// Package api provides the HTTP handlers for the sample service.
package api

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/swashbuck1r/shelfkeeper/go/internal/store"
)

// API bundles the handlers with their store dependency.
type API struct {
	store *store.Store
}

// New returns an API backed by the given store.
func New(s *store.Store) *API {
	return &API{store: s}
}

// Routes returns a chi router with all handlers registered.
func (a *API) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/healthz", a.handleHealthz)
	r.Post("/items", a.handleCreateItem)
	r.Get("/items", a.handleListItems)
	r.Get("/items/{id}", a.handleGetItem)
	return r
}

func (a *API) handleHealthz(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

type createItemRequest struct {
	Name string `json:"name"`
}

func (a *API) handleCreateItem(w http.ResponseWriter, r *http.Request) {
	var req createItemRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON body"})
		return
	}
	if req.Name == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "name is required"})
		return
	}

	item := store.Item{ID: uuid.NewString(), Name: req.Name}
	a.store.Put(item)
	writeJSON(w, http.StatusOK, item)
}

func (a *API) handleGetItem(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	item, err := a.store.Get(id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "item not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func (a *API) handleListItems(w http.ResponseWriter, r *http.Request) {
	items := a.store.List()
	writeJSON(w, http.StatusOK, items)
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
