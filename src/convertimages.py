from PIL import Image


def convert_palette(palette, num_colors):
    pal = []
    for ci in range(num_colors):
        r = palette[ci * 3] >> 4
        g = palette[ci * 3 + 1] >> 4
        b = palette[ci * 3 + 2] >> 4
        pal.append((r, g, b))
    return pal


def extract_tile(img, letter_idx_ascii):
    y = 16 * ((letter_idx_ascii - 32) // 20)
    x = 16 * ((letter_idx_ascii - 32) % 20)
    tile = img.crop((x, y, x + 16, y + 16))
    tile = tile.convert('L')  # make greyscale
    # tile.save(f"tile-{letter_idx_ascii}.png")
    result = bytearray()

    def get_eight_pixels(xoffset):
        pixels = [tile.getpixel((xoffset + x, y)) for x in range(8)]
        return [1 if p > 150 else 0 for p in pixels]

    for y in range(16):
        pixelbyte = get_eight_pixels(0)
        outbyte = 0
        for bb in pixelbyte:
            outbyte <<= 1
            outbyte |= bb
        result.append(outbyte)
        pixelbyte = get_eight_pixels(8)
        outbyte = 0
        for bb in pixelbyte:
            outbyte <<= 1
            outbyte |= bb
        result.append(outbyte)
    return result


def extract_titlescreen_lores256(img, outf):
    outf.write(img.tobytes())


def extract_titlescreen_hires16(img, outf):
    for y in range(400):
        for xpair in range(640 // 2):
            pix1 = img.getpixel((xpair * 2, y))
            pix2 = img.getpixel((xpair * 2 + 1, y))
            assert 0 <= pix1 <= 15
            assert 0 <= pix2 <= 15
            pix = pix1 << 4 | pix2
            outf.write(bytes([pix]))


screencodes = "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[_]__ !\"#$%&'()*+,-./0123456789:;<=>?"
assert len(screencodes) == 64
assert screencodes[42] == '*'

if __name__ == "__main__":
    # the font tiles for Mirror's Edge
    img = Image.open("images/font1.png")
    with open("ME-FONT.BIN", "wb") as outf:
        tiles = {}
        for ascii in range(ord(' '), ord('Z') + 1):
            tile = extract_tile(img, ascii)
            tiles[ascii] = tile
        for screencode, ascii_chr in enumerate(screencodes):
            tile = tiles.get(ord(ascii_chr), None)
            if tile:
                outf.write(tiles[ord(ascii_chr)])
            else:
                outf.write(bytearray(32))

    # the font tiles for Death Stranding
    img = Image.open("images/font3.png")
    with open("DS-FONT.BIN", "wb") as outf:
        tiles = {}
        for ascii in range(ord(' '), ord('Z') + 1):
            tile = extract_tile(img, ascii)
            tiles[ascii] = tile
        for screencode, ascii_chr in enumerate(screencodes):
            tile = tiles.get(ord(ascii_chr), None)
            if tile:
                outf.write(tiles[ord(ascii_chr)])
            else:
                outf.write(bytearray(32))

    # the demo screen(s)
    img = Image.open("images/demo3-lores.png")
    with open("ME-DEMOSCREEN.BIN", "wb") as outf:
        extract_titlescreen_lores256(img, outf)
    with open("ME-DEMOSCREEN.PAL", "wb") as outf:
        palette = img.getpalette()
        for r, g, b in convert_palette(palette, len(palette) // 3):
            # note: have to convert to different order when writing as binary file!
            # rgb = (r << 8) | (g << 4) | b
            # print(f"\t.word  ${rgb:04x}")
            outf.write(bytes([g << 4 | b, r]))
    img = Image.open("images/dsdemo-lores.png")
    with open("DS-DEMOSCREEN.BIN", "wb") as outf:
        extract_titlescreen_lores256(img, outf)
    with open("DS-DEMOSCREEN.PAL", "wb") as outf:
        palette = img.getpalette()
        for r, g, b in convert_palette(palette, len(palette) // 3):
            # note: have to convert to different order when writing as binary file!
            # rgb = (r << 8) | (g << 4) | b
            # print(f"\t.word  ${rgb:04x}")
            outf.write(bytes([g << 4 | b, r]))

    # the title screens (hires version)
    img = Image.open("images/title-hires.png")
    with open("ME-TITLESCREEN.BIN", "wb") as outf:
        extract_titlescreen_hires16(img, outf)
    with open("ME-TITLESCREEN.PAL", "wb") as outf:
        palette = img.getpalette()
        for r, g, b in convert_palette(palette, len(palette) // 3):
            # note: have to convert to different order when writing as binary file!
            # rgb = (r << 8) | (g << 4) | b
            # print(f"\t.word  ${rgb:04x}")
            outf.write(bytes([g << 4 | b, r]))
    img = Image.open("images/dstitle-hires.png")
    with open("DS-TITLESCREEN.BIN", "wb") as outf:
        extract_titlescreen_hires16(img, outf)
    with open("DS-TITLESCREEN.PAL", "wb") as outf:
        palette = img.getpalette()
        for r, g, b in convert_palette(palette, len(palette) // 3):
            # note: have to convert to different order when writing as binary file!
            # rgb = (r << 8) | (g << 4) | b
            # print(f"\t.word  ${rgb:04x}")
            outf.write(bytes([g << 4 | b, r]))
