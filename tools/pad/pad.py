#!/usr/bin/env python3
"""Send commands to the test pad (the ESP32-C3 running firmware/firmware.ino).

  pad.py press LT+SELECT 150     hold LT and Select for 150 ms
  pad.py status                  connected=1 when the Mac has the pad
  pad.py stick L 0 1; press A    several commands, ";" between them
  pad.py wait 500                pause (here, not on the pad)

The port is the one /dev/cu.usbmodem* (PAD_PORT overrides). Stdlib only. The port is opened
without HUPCL and without touching DTR/RTS: the C3's USB serial resets the chip on some
DTR/RTS toggles.
"""
import glob, os, select, sys, termios, time


def find_port():
    port = os.environ.get("PAD_PORT")
    if port:
        return port
    ports = sorted(glob.glob("/dev/cu.usbmodem*"))
    if not ports:
        sys.exit("no /dev/cu.usbmodem*: is the ESP32-C3 plugged in (data cable)?")
    return ports[0]


def open_port(path):
    fd = os.open(path, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0                                    # iflag
    attrs[1] = 0                                    # oflag
    attrs[2] = (attrs[2] | termios.CLOCAL | termios.CREAD | termios.CS8) & ~termios.HUPCL
    attrs[3] = 0                                    # lflag: raw
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    return fd


def read_line(fd, timeout):
    buf, end = b"", time.time() + timeout
    while time.time() < end:
        ready, _, _ = select.select([fd], [], [], 0.05)
        if ready:
            buf += os.read(fd, 256)
            if b"\n" in buf:
                return buf.split(b"\n", 1)[0].decode(errors="replace").strip()
    return None


def run(fd, command):
    parts = command.split()
    if not parts:
        return True
    if parts[0] == "wait":
        time.sleep(float(parts[1]) / 1000)
        return True
    os.write(fd, (command.strip() + "\n").encode())
    # a press holds for its ms before the pad answers
    hold = int(parts[2]) / 1000 if parts[0] == "press" and len(parts) > 2 else 0.1
    answer = read_line(fd, hold + 2)
    print(f"{command.strip()} -> {answer}")
    return answer is not None and not answer.startswith("err")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    fd = open_port(find_port())
    time.sleep(0.1)
    ok = True
    for command in " ".join(sys.argv[1:]).split(";"):
        ok = run(fd, command) and ok
    os.close(fd)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
