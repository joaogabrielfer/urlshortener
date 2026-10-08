# api

- `POST   / {"url": ...}` -> creates a short link for the url given, returning short_url, long_url and key
- `GET    /:key` -> returns the url mapped to that key
- `DELETE /:key` -> deletes the given key entry

# building and running

- `just build`
- `just dev`
