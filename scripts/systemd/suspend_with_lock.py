import subprocess
import time
import sys

def main():
    # Attempt to lock the screen using the IPC call
    try:
        subprocess.Popen(["qs", "-c", "ii", "ipc", "call", "lock", "activate"])
    except Exception as e:
        print(f"Failed to lock: {e}")

    # Give it a moment to register the lock
    time.sleep(1)

    # Trigger suspend
    try:
        subprocess.run(["systemctl", "suspend"], check=True)
    except Exception as e:
        print(f"Failed to suspend: {e}")

if __name__ == "__main__":
    main()
