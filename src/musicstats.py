import os
import subprocess
import sys


def print_stats(wavfile, adpcmfile):
    print("wavfile =", wavfile)
    print("adpcmfile =", adpcmfile)
    adpcm_size = os.stat(adpcmfile).st_size
    adpcm_blocks = adpcm_size / 256
    duration = float(subprocess.getoutput(f"soxi -D {wavfile}"))
    blocks_per_second = adpcm_blocks / duration
    print(f"\nStats for music file {adpcmfile}")
    print(f"# adpcm blocks: {adpcm_blocks}  duration: {duration} sec.  --> {blocks_per_second} blocks per second.\n")


if __name__ == "__main__":
    print_stats(sys.argv[1], sys.argv[2])
