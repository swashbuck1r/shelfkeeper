package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/swashbuck1r/shelfkeeper/go/internal/store"
)

func newTestAPI() *API {
	return New(store.New())
}

func TestHealthz(t *testing.T) {
	a := newTestAPI()
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()

	a.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	var body map[string]string
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["status"] != "ok" {
		t.Fatalf("status field = %q, want %q", body["status"], "ok")
	}
}

func TestCreateItem(t *testing.T) {
	a := newTestAPI()
	payload := bytes.NewBufferString(`{"name":"widget"}`)
	req := httptest.NewRequest(http.MethodPost, "/items", payload)
	rec := httptest.NewRecorder()

	a.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	var item store.Item
	if err := json.NewDecoder(rec.Body).Decode(&item); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if item.ID == "" {
		t.Fatal("item.ID is empty, want a generated uuid")
	}
	if item.Name != "widget" {
		t.Fatalf("item.Name = %q, want %q", item.Name, "widget")
	}
}

func TestCreateItemBadJSON(t *testing.T) {
	a := newTestAPI()
	payload := bytes.NewBufferString(`{not valid json`)
	req := httptest.NewRequest(http.MethodPost, "/items", payload)
	rec := httptest.NewRecorder()

	a.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestCreateItemMissingName(t *testing.T) {
	a := newTestAPI()
	payload := bytes.NewBufferString(`{"name":""}`)
	req := httptest.NewRequest(http.MethodPost, "/items", payload)
	rec := httptest.NewRecorder()

	a.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestGetItem(t *testing.T) {
	a := newTestAPI()
	item := store.Item{ID: "abc-123", Name: "widget"}
	a.store.Put(item)

	req := httptest.NewRequest(http.MethodGet, "/items/abc-123", nil)
	rec := httptest.NewRecorder()

	a.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	var got store.Item
	if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if got != item {
		t.Fatalf("got %+v, want %+v", got, item)
	}
}

func TestGetItemNotFound(t *testing.T) {
	a := newTestAPI()
	req := httptest.NewRequest(http.MethodGet, "/items/does-not-exist", nil)
	rec := httptest.NewRecorder()

	a.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusNotFound)
	}
}

func TestListItems(t *testing.T) {
	a := newTestAPI()
	a.store.Put(store.Item{ID: "1", Name: "widget"})
	a.store.Put(store.Item{ID: "2", Name: "gadget"})

	req := httptest.NewRequest(http.MethodGet, "/items", nil)
	rec := httptest.NewRecorder()

	a.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	var items []store.Item
	if err := json.NewDecoder(rec.Body).Decode(&items); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if len(items) != 2 {
		t.Fatalf("len(items) = %d, want 2", len(items))
	}
}

func TestListItemsEmpty(t *testing.T) {
	a := newTestAPI()
	req := httptest.NewRequest(http.MethodGet, "/items", nil)
	rec := httptest.NewRecorder()

	a.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	var items []store.Item
	if err := json.NewDecoder(rec.Body).Decode(&items); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if len(items) != 0 {
		t.Fatalf("len(items) = %d, want 0", len(items))
	}
}

func TestUnknownRoute(t *testing.T) {
	a := newTestAPI()
	req := httptest.NewRequest(http.MethodGet, "/does-not-exist", nil)
	rec := httptest.NewRecorder()

	a.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusNotFound)
	}
}
