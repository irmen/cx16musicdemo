import os
import sys
import time

# we used co calculate the sync based on number of frames displayed (vsync synced)
# but that is inaccurate as this depends on screen mode and such.
# FRAME_RATE = 25e6/(525*800)      # vga doesn't run exactly at 1/60 seconds!


class Trigger:
    text = []

    def __init__(self, timestamp: float, text: str):
        self.timestamp = timestamp
        self.text = [text]

    def append(self, text: str):
        self.text.append(text)


def load_source(filename) -> list[Trigger]:
    triggers = []
    trigger = Trigger(-1, "")
    lyrics = open(filename).readlines()[2:]
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


def generate_code(triggers: list[Trigger], blocks_per_second: float) -> str:
    print("adpcm blocks per second:", blocks_per_second)
    r = [
        "; this code is generated",
        "lyrics {",
        f"    const ubyte LINECOUNT = {len(triggers)}",
        "    uword[] timestamps = [     ; in blocks"
    ]
    for trigger in triggers:
        blocks = int(trigger.timestamp * blocks_per_second)
        r.append(f"        {blocks},")
    r.append(f"        $ffff  ; end")
    r.append("    ]")
    r.append("    str[] lines = [")
    for idx, trigger in enumerate(triggers):
        line = "|".join(trigger.text).lower()
        if idx == len(triggers) - 1:
            r.append('        ""')
        else:
            r.append(f'        sc:"{repr(line)[1:-1]}",')
    r.append("    ]")
    r.append("}")
    return "\n".join(r)


def playback(triggers: list[Trigger], blocks_per_second: float) -> None:
    start_ns = time.monotonic_ns()
    for trigger in triggers:
        if trigger.timestamp == 0.0:
            print("zero timestamp, unfinished sync?")
            raise SystemExit(1)
        timestamp_blocks = int(trigger.timestamp * blocks_per_second)
        print("(next at", trigger.timestamp, " blocks=", timestamp_blocks,")\n")
        timestamp_ns = int(timestamp_blocks/blocks_per_second * 1e9)
        while time.monotonic_ns() - start_ns < timestamp_ns:
            pass
        for index, text in enumerate(trigger.text):
            print("  " * index, text)
        print()
        print()


ADPCM_BLOCK_SIZE = 256
SAMPLE_RATE = 16021         # make sure this matches the Sr used for the music conversion


def calculate_bps(adpcmfile) -> float:
    adpcm_size = os.stat(adpcmfile).st_size
    adpcm_blocks = adpcm_size / ADPCM_BLOCK_SIZE
    # sample_rate = float(subprocess.getoutput(f"soxi -r {wavfile}"))
    # duration = float(subprocess.getoutput(f"soxi -D {wavfile}"))
    # blocks_per_second = adpcm_blocks / duration
    # print(f"\nStats for music file {adpcmfile}")
    # print(f"# adpcm blocks: {adpcm_blocks}  duration: {duration} sec.  --> {blocks_per_second} blocks per second.")
    total_decoded_samples = adpcm_blocks * 505
    decoded_duration = total_decoded_samples / SAMPLE_RATE
    blocks_per_second = adpcm_blocks / decoded_duration
    # print(f"\nStats for music file {adpcmfile}")
    # print(f"# adpcm blocks: {adpcm_blocks}  duration: {decoded_duration} sec.  --> {blocks_per_second} blocks per second.")
    # print()
    return blocks_per_second


if __name__ == "__main__":
    bps = calculate_bps(sys.argv[3])
    triggers = load_source(sys.argv[1])
    result = generate_code(triggers, bps)
    # playback(triggers)
    with open(sys.argv[2], "w") as out:
        out.write(result)
