#!/usr/bin/env bash
set -euo pipefail

echo "=== Upgrading Go dependencies ==="
go get -u ./...

echo "=== Tidying Go modules ==="
go mod tidy

echo "=== Verifying Go module compilation ==="
go build ./...

echo "=== Verifying test compilation (no live infrastructure created) ==="
go test -c ./...

echo "=== Verification complete! ==="
