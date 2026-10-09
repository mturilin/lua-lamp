# DemoApp — Latency Monitor

A lightweight, high-performance desktop application built on **Lua Lamp**.

## Development
Run the application in development mode (hot run against the installed Lua Lamp engine):
```bash
lualamp run .
```

## Packaging Standalone Distribution
Package into a 100% standalone native executable bundle with zero external dependencies:
```bash
# On macOS: produces dist/DemoApp.app and dist/DemoApp-1.0.0.dmg
lualamp build .

# On Linux: produces dist/DemoApp-linux-x86_64.tar.gz
lualamp build . --linux
```
