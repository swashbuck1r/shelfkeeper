// Package store provides a simple in-memory, concurrency-safe store for items.
package store

import (
	"errors"
	"sync"
)

// ErrNotFound is returned when an item is not present in the store.
var ErrNotFound = errors.New("item not found")

// Item is a single stored record.
type Item struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// Store is a mutex-guarded in-memory map of items.
type Store struct {
	mu    sync.Mutex
	items map[string]Item
}

// New returns an empty, ready-to-use Store.
func New() *Store {
	return &Store{
		items: make(map[string]Item),
	}
}

// Put inserts or replaces an item.
func (s *Store) Put(item Item) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.items[item.ID] = item
}

// Get returns the item with the given id, or ErrNotFound.
func (s *Store) Get(id string) (Item, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	item, ok := s.items[id]
	if !ok {
		return Item{}, ErrNotFound
	}
	return item, nil
}

// List returns all items in unspecified order.
func (s *Store) List() []Item {
	s.mu.Lock()
	defer s.mu.Unlock()
	items := make([]Item, 0, len(s.items))
	for _, item := range s.items {
		items = append(items, item)
	}
	return items
}
