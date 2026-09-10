package store

import (
	"errors"
	"testing"
)

func TestPutAndGet(t *testing.T) {
	s := New()
	item := Item{ID: "1", Name: "widget"}
	s.Put(item)

	got, err := s.Get("1")
	if err != nil {
		t.Fatalf("Get returned error: %v", err)
	}
	if got != item {
		t.Fatalf("Get returned %+v, want %+v", got, item)
	}
}

func TestGetMissing(t *testing.T) {
	s := New()
	_, err := s.Get("missing")
	if !errors.Is(err, ErrNotFound) {
		t.Fatalf("Get error = %v, want ErrNotFound", err)
	}
}

func TestPutReplacesExisting(t *testing.T) {
	s := New()
	s.Put(Item{ID: "1", Name: "widget"})
	s.Put(Item{ID: "1", Name: "gadget"})

	got, err := s.Get("1")
	if err != nil {
		t.Fatalf("Get returned error: %v", err)
	}
	if got.Name != "gadget" {
		t.Fatalf("Get returned Name %q, want %q", got.Name, "gadget")
	}
}

func TestListEmpty(t *testing.T) {
	s := New()
	items := s.List()
	if len(items) != 0 {
		t.Fatalf("List returned %d items, want 0", len(items))
	}
}

func TestListReturnsAllItems(t *testing.T) {
	s := New()
	want := map[string]Item{
		"1": {ID: "1", Name: "widget"},
		"2": {ID: "2", Name: "gadget"},
		"3": {ID: "3", Name: "gizmo"},
	}
	for _, item := range want {
		s.Put(item)
	}

	items := s.List()
	if len(items) != len(want) {
		t.Fatalf("List returned %d items, want %d", len(items), len(want))
	}
	got := make(map[string]Item, len(items))
	for _, item := range items {
		got[item.ID] = item
	}
	for id, item := range want {
		if got[id] != item {
			t.Fatalf("List missing or mismatched item for id %q: got %+v, want %+v", id, got[id], item)
		}
	}
}
