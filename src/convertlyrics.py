import time

FRAME_RATE = 25e6/(525*800)      # vga doesn't run exactly at 1/60 seconds!


class Trigger:
    text = []

    def __init__(self, timestamp: float, text: str):
        self.timestamp = timestamp
        self.text = [text]

    def append(self, text: str):
        self.text.append(text)


def load_source() -> list[Trigger]:
    triggers = []
    trigger = Trigger(-1, "")
    lyrics = open("src/lyrics.txt").readlines()[2:]
    previous_timestamp = 0.0
    for line in lyrics:
        line = line.rstrip()
        if not line:
            continue
        if line.startswith(' '):
            # continuation of previous trigger
            trigger.append(line.strip())
        else:
            # new trigger
            if trigger.timestamp >= 0:
                triggers.append(trigger)
            parts = line.split(maxsplit=1)
            timestamp = float(parts[0])
            if timestamp == 0.0:
                timestamp = previous_timestamp + 0.001
            text = "" if parts[1] == "<END>" else parts[1]
            trigger = Trigger(timestamp, text)
            previous_timestamp = timestamp
            if not text:
                break
    triggers.append(trigger)
    return triggers


def generate_code(triggers: list[Trigger]) -> None:
    print("; this code is generated")
    print("lyrics {")
    print("    const ubyte LINECOUNT =", len(triggers))
    print("    uword[] timestamps = [     ; in jiffies")
    for trigger in triggers:
        jiffies = int(trigger.timestamp * FRAME_RATE)
        print(f"        {jiffies},")
    print(f"        $ffff  ; end")
    print("    ]")
    print("    str[] lines = [")
    for idx, trigger in enumerate(triggers):
        line = "\n".join(trigger.text).lower()
        if idx == len(triggers) - 1:
            print('        ""')
        else:
            print(f'        "{repr(line)[1:-1]}",')
    print("    ]")
    print("}")


def playback(triggers: list[Trigger]) -> None:
    start_ns = time.monotonic_ns()
    for trigger in triggers:
        if trigger.timestamp == 0.0:
            print("zero timestamp, unfinished sync?")
            raise SystemExit(1)
        timestamp_jiffies = int(trigger.timestamp * FRAME_RATE)
        print("(next at", trigger.timestamp, " jiffies=", timestamp_jiffies,")\n")
        timestamp_ns = int(timestamp_jiffies/FRAME_RATE * 1e9)
        while time.monotonic_ns() - start_ns < timestamp_ns:
            pass
        for index, text in enumerate(trigger.text):
            print("  " * index, text)
        print()
        print()


if __name__ == "__main__":
    triggers = load_source()
    generate_code(triggers)
    # playback(triggers)
