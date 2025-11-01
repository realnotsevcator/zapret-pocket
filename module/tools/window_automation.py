"""Utilities for launching a GUI process and managing its main window.

This helper follows the requested workflow:

1. Start a process while remembering its PID.
2. Wait until the main window for that process appears *and* becomes the
   foreground window.
3. Center the active window on the current monitor.
4. Block until the window (and process) close, then allow the caller to run
   the rest of their script.

Only standard library modules and the Windows ``user32`` API (via :mod:`ctypes`)
are used so that no extra runtime dependencies are required.
"""

from __future__ import annotations

import argparse
import os
import shlex
import subprocess
import sys
import time
from ctypes import Structure, byref, sizeof, windll
from ctypes.wintypes import DWORD, HWND, RECT
from typing import Iterable, Optional


def _ensure_windows() -> None:
    """Ensure the script is running on a Windows platform."""
    if os.name != "nt":  # pragma: no cover - platform guard
        raise OSError("Window management helper is only supported on Windows")


def _wait_for_active_window(pid: int, timeout: float, poll_interval: float) -> Optional[HWND]:
    """Wait until a window belonging to *pid* is the active foreground window."""
    deadline = time.time() + timeout if timeout > 0 else None
    while True:
        hwnd_active = windll.user32.GetForegroundWindow()
        if hwnd_active:
            window_pid = DWORD()
            windll.user32.GetWindowThreadProcessId(hwnd_active, byref(window_pid))
            if window_pid.value == pid:
                return hwnd_active
        if deadline is not None and time.time() >= deadline:
            return None
        time.sleep(poll_interval)


class MONITORINFO(Structure):
    _fields_ = [
        ("cbSize", DWORD),
        ("rcMonitor", RECT),
        ("rcWork", RECT),
        ("dwFlags", DWORD),
    ]


def _get_work_area(hwnd: HWND) -> RECT:
    """Determine the work area of the monitor displaying *hwnd*."""
    monitor = windll.user32.MonitorFromWindow(hwnd, 1)  # MONITOR_DEFAULTTONEAREST
    info = MONITORINFO()
    info.cbSize = sizeof(MONITORINFO)
    if monitor and windll.user32.GetMonitorInfoW(monitor, byref(info)):
        return info.rcWork

    # Fallback to the virtual screen size when monitor information is unavailable.
    fallback = RECT()
    fallback.left = windll.user32.GetSystemMetrics(76)  # SM_XVIRTUALSCREEN
    fallback.top = windll.user32.GetSystemMetrics(77)  # SM_YVIRTUALSCREEN
    width = windll.user32.GetSystemMetrics(78)  # SM_CXVIRTUALSCREEN
    height = windll.user32.GetSystemMetrics(79)  # SM_CYVIRTUALSCREEN
    fallback.right = fallback.left + width
    fallback.bottom = fallback.top + height
    return fallback


def _center_window(hwnd: HWND) -> None:
    """Center the specified window within its current work area."""
    rect = RECT()
    windll.user32.GetWindowRect(hwnd, byref(rect))
    work_area = _get_work_area(hwnd)

    window_width = rect.right - rect.left
    window_height = rect.bottom - rect.top
    target_x = work_area.left + max(0, (work_area.right - work_area.left - window_width) // 2)
    target_y = work_area.top + max(0, (work_area.bottom - work_area.top - window_height) // 2)

    windll.user32.SetWindowPos(
        hwnd,
        0,
        target_x,
        target_y,
        0,
        0,
        0x0001 | 0x0004,  # SWP_NOSIZE | SWP_NOZORDER
    )


def launch_process(command: Iterable[str] | str, pid_file: Optional[str] = None) -> subprocess.Popen:
    """Launch *command*, write the PID if requested, and return the ``Popen`` object."""
    if isinstance(command, str):
        args = shlex.split(command)
    else:
        args = list(command)
    if not args:
        raise ValueError("Command must not be empty")
    process = subprocess.Popen(args)
    if pid_file:
        with open(pid_file, "w", encoding="utf-8") as fh:
            fh.write(str(process.pid))
    return process


def manage_windowed_process(
    command: Iterable[str] | str,
    *,
    pid_file: Optional[str] = None,
    wait_timeout: float = 30.0,
    poll_interval: float = 0.2,
) -> int:
    """Launch a process, center its active window, and wait for it to exit.

    Returns the process' exit code once it terminates.
    """
    _ensure_windows()

    process = launch_process(command, pid_file=pid_file)
    hwnd = _wait_for_active_window(process.pid, wait_timeout, poll_interval)
    if not hwnd:
        raise TimeoutError("Timed out waiting for the process window to become active")

    _center_window(hwnd)
    return process.wait()


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Launch a GUI process and center its window.")
    parser.add_argument("command", help="Command to execute (quoted string) or path to executable", nargs=argparse.REMAINDER)
    parser.add_argument("--pid-file", dest="pid_file", help="Optional file to write the child PID to.")
    parser.add_argument("--timeout", dest="timeout", type=float, default=30.0, help="Seconds to wait for the window to activate.")
    parser.add_argument(
        "--poll-interval",
        dest="poll_interval",
        type=float,
        default=0.2,
        help="Polling interval in seconds while waiting for the window.",
    )
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    if not args.command:
        raise SystemExit("No command specified")

    command = args.command if len(args.command) > 1 else args.command[0]
    exit_code = manage_windowed_process(
        command,
        pid_file=args.pid_file,
        wait_timeout=args.timeout,
        poll_interval=args.poll_interval,
    )
    return exit_code


if __name__ == "__main__":  # pragma: no cover - CLI entry point
    try:
        raise SystemExit(main())
    except TimeoutError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
