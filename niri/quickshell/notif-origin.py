#!/usr/bin/env python3
"""Print the process chain behind each desktop notification.

Notification clicks look up the sender and focus that window directly.
This watches Notify calls and writes one JSON object per line:
{"app", "summary", "body", "pids"}.
"""

import ctypes
import json
import os
import re
import signal
import subprocess
import sys

PID_RE = re.compile(r"(?:int16|int32|int64|uint16|uint32|uint64|byte)\s+(\d+)")
SENDER_RE = re.compile(r"sender=(:\d+\.\d+)")


PR_SET_PDEATHSIG = 1


def die_with_parent():
	"""Ask the kernel to SIGTERM this process when its parent exits.

	Without this, killing quickshell left the helper and its dbus-monitor
	running, and every restart added another pair.
	"""
	try:
		libc = ctypes.CDLL(None, use_errno=True)
		libc.prctl(PR_SET_PDEATHSIG, signal.SIGTERM)
	except (OSError, AttributeError):
		pass


def dbus_strings(text):
	found = []
	token = 'string "'
	i = 0
	while True:
		start = text.find(token, i)
		if start < 0:
			break
		i = start + len(token)
		chars = []
		closed = False
		while i < len(text):
			if text[i] == "\\" and i + 1 < len(text):
				n = text[i + 1]
				if n in "01234567":
					octal = n
					i += 2
					while i < len(text) and len(octal) < 3 and text[i] in "01234567":
						octal += text[i]
						i += 1
					chars.append(chr(int(octal, 8)))
					continue
				chars.append({"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"'}.get(n, n))
				i += 2
				continue
			if text[i] == '"':
				closed = True
				i += 1
				break
			chars.append(text[i])
			i += 1
		if closed:
			found.append("".join(chars))
	return found


def hint_pid(text):
	idx = text.find('"sender-pid"')
	if idx < 0:
		return 0
	match = PID_RE.search(text[idx:idx + 240])
	return int(match.group(1)) if match else 0


def connection_pid(sender):
	if not sender:
		return 0
	try:
		out = subprocess.check_output(
			[
				"busctl", "call",
				"org.freedesktop.DBus", "/org/freedesktop/DBus",
				"org.freedesktop.DBus", "GetConnectionUnixProcessID",
				"s", sender,
			],
			text=True,
			timeout=1,
			stderr=subprocess.DEVNULL,
		)
	except (subprocess.SubprocessError, OSError):
		return 0
	parts = out.split()
	if len(parts) < 2:
		return 0
	try:
		return int(parts[-1])
	except ValueError:
		return 0


def chain(pid):
	pids = []
	seen = set()
	while pid and pid > 1 and pid not in seen and len(pids) < 16:
		seen.add(pid)
		pids.append(pid)
		try:
			with open(f"/proc/{pid}/status", "r", encoding="utf-8", errors="replace") as handle:
				ppid = 0
				for line in handle:
					if line.startswith("PPid:"):
						ppid = int(line.split()[1])
						break
			pid = ppid
		except (OSError, ValueError):
			break
	return pids


def describe(block):
	if not block:
		return None
	header = block[0]
	if "member=Notify" not in header:
		return None
	text = "\n".join(block)
	strings = dbus_strings(text)
	if len(strings) < 4:
		return None
	sender = ""
	match = SENDER_RE.search(header)
	if match:
		sender = match.group(1)
	pid = connection_pid(sender) or hint_pid(text)
	return {
		"app": strings[0],
		"summary": strings[2],
		"body": strings[3],
		"pids": chain(pid),
	}


def emit(info):
	if not info or not info.get("pids"):
		return
	try:
		sys.stdout.write(json.dumps(info, ensure_ascii=False) + "\n")
		sys.stdout.flush()
	except BrokenPipeError:
		# The shell went away.
		raise SystemExit(0)


def main():
	parent = os.getppid()
	die_with_parent()
	if os.getppid() != parent:
		return 0  # parent already gone before the death signal was armed
	proc = subprocess.Popen(
		[
			"dbus-monitor", "--session",
			"type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
		],
		stdout=subprocess.PIPE,
		stderr=subprocess.DEVNULL,
		text=True,
		bufsize=1,
		preexec_fn=die_with_parent,
	)
	block = []
	try:
		for line in proc.stdout:
			stripped = line.rstrip("\n")
			if stripped.startswith(("method ", "signal ", "error ")):
				emit(describe(block))
				block = [stripped]
				continue
			if stripped.strip() == "":
				emit(describe(block))
				block = []
				continue
			if block:
				block.append(stripped)
		emit(describe(block))
	finally:
		proc.terminate()
	return proc.wait()


if __name__ == "__main__":
	sys.exit(main() or 0)
