# Default entry point for the Python Runner service.
# Replace this file with your own long-running code.
# The idle loop below keeps the container alive so Docker's
# `restart: unless-stopped` policy does not restart it endlessly.
import time

print("Python runner is up!", flush=True)

while True:
    time.sleep(3600)
