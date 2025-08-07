#!/bin/sh
# entrypoint-wrapper.sh
#
# This script serves as a wrapper entrypoint for Docker containers. It locates and executes all executable scripts
# in the /usr/local/bin/entrypoints/ directory (except itself), in sorted order. If any script fails, the wrapper exits
# with the same status code. After running all scripts, it blocks indefinitely to keep the container alive.
#
# Usage: Set this script as the container's entrypoint. Place additional entrypoint scripts in /usr/local/bin/entrypoints/.

set -e

echo "[entrypoint-wrapper] Starting entrypoint script execution..."
SCRIPTS=$(ls /usr/local/bin/entrypoints/* | sort)
echo "[entrypoint-wrapper] Found scripts: $SCRIPTS"
for script in $SCRIPTS; do
    if [ "$script" != "/usr/local/bin/entrypoints/entrypoint-wrapper.sh" ] && [ -x "$script" ]; then
        echo "[entrypoint-wrapper] Running $script..."
        "$script"
        status=$?
        if [ $status -ne 0 ]; then
            echo "[entrypoint-wrapper] ERROR: $script exited with status $status" >&2
            exit $status
        fi
        echo "[entrypoint-wrapper] Finished $script."
    else
        echo "[entrypoint-wrapper] Skipping $script (not executable or is wrapper)."
    fi
done
echo "[entrypoint-wrapper] All entrypoint scripts executed."
echo "[entrypoint-wrapper] Checking for /start.sh..."

# Block to keep the container running (main process)
echo "[entrypoint-wrapper] All entrypoint scripts executed. Container will now block to stay alive."
tail -f /dev/null
