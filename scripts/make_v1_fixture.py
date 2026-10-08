#!/usr/bin/env python3
"""Deterministic pre-v2 SQLite fixture. Run from repo root to regenerate."""
import json
import sqlite3
from pathlib import Path

path = Path('Packages/ResaleDeskStore/Tests/ResaleDeskStoreTests/Fixtures/v1.sqlite')
path.parent.mkdir(parents=True, exist_ok=True)
if path.exists():
    path.unlink()
with sqlite3.connect(path) as db:
    db.execute('PRAGMA foreign_keys=ON')
    db.executescript('''
        CREATE TABLE grdb_migrations (identifier TEXT PRIMARY KEY NOT NULL);
        INSERT INTO grdb_migrations VALUES ('v1');
        CREATE TABLE item (id TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL);
        CREATE TABLE rubric (id TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL);
        CREATE TABLE condition (itemID TEXT PRIMARY KEY NOT NULL REFERENCES item(id) ON DELETE RESTRICT,
            rubricID TEXT NOT NULL REFERENCES rubric(id) ON DELETE RESTRICT, payload TEXT NOT NULL);
        CREATE TABLE draft (id TEXT PRIMARY KEY NOT NULL, itemID TEXT NOT NULL UNIQUE REFERENCES item(id) ON DELETE RESTRICT, payload TEXT NOT NULL);
        CREATE TABLE parcel (id TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL);
        CREATE TABLE parcel_item (parcelID TEXT NOT NULL REFERENCES parcel(id) ON DELETE RESTRICT,
            itemID TEXT NOT NULL REFERENCES item(id) ON DELETE RESTRICT, PRIMARY KEY(parcelID, itemID));
        CREATE TABLE packing (id TEXT PRIMARY KEY NOT NULL, parcelID TEXT NOT NULL REFERENCES parcel(id) ON DELETE RESTRICT,
            recordedAt INTEGER NOT NULL CHECK(recordedAt >= 0), payload TEXT NOT NULL);
        CREATE TABLE price (id TEXT PRIMARY KEY NOT NULL, itemID TEXT NOT NULL REFERENCES item(id) ON DELETE RESTRICT,
            recordedAt INTEGER NOT NULL CHECK(recordedAt >= 0), payload TEXT NOT NULL);
        CREATE TABLE outcome (id TEXT PRIMARY KEY NOT NULL, itemID TEXT NOT NULL UNIQUE REFERENCES item(id) ON DELETE RESTRICT, payload TEXT NOT NULL);
    ''')
    compact = lambda x: json.dumps(x, sort_keys=True, separators=(',', ':'))
    db.execute('INSERT INTO item VALUES (?, ?)', ('fixture-item', compact({'id': 'fixture-item', 'title': 'Fixture book', 'photoPaths': []})))
    db.execute('INSERT INTO price VALUES (?, ?, ?, ?)', ('fixture-price', 'fixture-item', 1, compact({'id': 'fixture-price', 'itemID': 'fixture-item', 'askingCents': 1200, 'recordedAt': 1})))
    db.execute('INSERT INTO outcome VALUES (?, ?, ?)', ('fixture-outcome', 'fixture-item', compact({'id': 'fixture-outcome', 'itemID': 'fixture-item', 'kind': 'sold', 'season': '2026'})))
print(f'{path}: {path.stat().st_size} bytes')
