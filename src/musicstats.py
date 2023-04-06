import os
import sys

ADPCM_BLOCK_SIZE = 256
SAMPLE_RATE = 16021         # make sure this matches the Sr used for the music conversion


def print_stats(adpcmfile):
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
    print(f"\nStats for music file {adpcmfile}")
    print(f"# adpcm blocks: {adpcm_blocks}  duration: {decoded_duration} sec.  --> {blocks_per_second} blocks per second.")
    print()


if __name__ == "__main__":
    print_stats(sys.argv[1])
