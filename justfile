set shell := ["bash", "-cu"]

backend := "backend"
frontend := "frontend"

default:
    @just --list

backend:
    cd {{backend}} && gleam run

frontend:
    cd {{frontend}} && elm make src/Main.elm

backend-dev:
    cd backend && watchexec \
        --restart \
        --watch src \
        --exts gleam \
        -- gleam run

frontend-dev:
    cd frontend && watchexec \
        --watch src \
        --exts elm \
        -- elm make src/Main.elm

dev:
    #!/usr/bin/env bash
    set -e

    just backend-dev &
    backend_pid=$!

    just frontend-dev &
    frontend_pid=$!

    trap 'kill "$backend_pid" "$frontend_pid" 2>/dev/null || true' EXIT
    wait

build:
    just -f {{justfile()}} frontend
    cd {{backend}} && gleam build
