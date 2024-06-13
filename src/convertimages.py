from cx16images import BitmapImage


def extract_tile(img: BitmapImage, letter_idx_ascii):
    y = 16 * ((letter_idx_ascii - 32) // 20)
    x = 16 * ((letter_idx_ascii - 32) % 20)
    cropped = img.crop(x, y, 16, 16)
    tile = cropped.get_image().convert('L')  # make greyscale
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


screencodes = "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[_]__ !\"#$%&'()*+,-./0123456789:;<=>?"
assert len(screencodes) == 64
assert screencodes[42] == '*'


if __name__ == "__main__":
    # the font tiles for Mirror's Edge
    img = BitmapImage("images/font1.png")
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
    img = BitmapImage("images/font3.png")
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
    img = BitmapImage("images/demo3-lores.png")
    with open("ME-DEMOSCREEN.BIN", "wb") as outf:
        outf.write(img.get_all_pixels_8bpp())
    with open("ME-DEMOSCREEN.PAL", "wb") as outf:
        outf.write(img.get_vera_palette())
    img = BitmapImage("images/dsdemo-lores.png")
    with open("DS-DEMOSCREEN.BIN", "wb") as outf:
        outf.write(img.get_all_pixels_8bpp())
    with open("DS-DEMOSCREEN.PAL", "wb") as outf:
        outf.write(img.get_vera_palette())

    # the title screens (hires version)
    img = BitmapImage("images/title-hires.png")
    with open("ME-TITLESCREEN.BIN", "wb") as outf:
        outf.write(img.get_all_pixels_4bpp())
    with open("ME-TITLESCREEN.PAL", "wb") as outf:
        outf.write(img.get_vera_palette())
    img = BitmapImage("images/dstitle-hires.png")
    with open("DS-TITLESCREEN.BIN", "wb") as outf:
        outf.write(img.get_all_pixels_4bpp())
    with open("DS-TITLESCREEN.PAL", "wb") as outf:
        outf.write(img.get_vera_palette())
