# Snidanok 🇺🇦

Plan weekly breakfasts, auto-generate grocery lists.

## Quick start with Docker on any machine

```sh
docker compose up --build
docker compose run --rm web bin/rails db:prepare
```

Open http://localhost:3000.

What's running:
- `web` — Rails server on port 3000
- `db` — PostgreSQL 16 (host port 5433)
- `css` — Tailwind watcher

Run tests:

```sh
docker compose run --rm web bundle exec rspec
```

