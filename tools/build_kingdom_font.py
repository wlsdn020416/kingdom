"""갈무리11의 한글을 보존하고 게임용 숫자·문장 기호를 추가한 OFL 파생 글꼴을 만든다."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/fonts/sources/Galmuri11.ttf'
OUTPUT = ROOT / 'assets/fonts/kingdom_dot.ttf'

# 내부 공간을 넓힌 각진 숫자와 별도 문장 기호. 각 칸은 원본과 같은 100 UPM이다.
PIXELS = {
    '0': ['01110', '11011', '11011', '11011', '11011', '11011', '11011', '11011', '01110'],
    '1': ['00100', '01100', '11100', '00100', '00100', '00100', '00100', '00100', '11111'],
    '2': ['01110', '11011', '00011', '00011', '00110', '01100', '11000', '11000', '11111'],
    '3': ['11110', '00011', '00011', '00011', '01110', '00011', '00011', '00011', '11110'],
    '4': ['00011', '00111', '01111', '11011', '11011', '11111', '00011', '00011', '00011'],
    '5': ['11111', '11000', '11000', '11000', '11110', '00011', '00011', '11011', '01110'],
    '6': ['00110', '01100', '11000', '11000', '11110', '11011', '11011', '11011', '01110'],
    '7': ['11111', '00011', '00011', '00110', '00110', '01100', '01100', '11000', '11000'],
    '8': ['01110', '11011', '11011', '11011', '01110', '11011', '11011', '11011', '01110'],
    '9': ['01110', '11011', '11011', '11011', '01111', '00011', '00011', '00110', '01100'],
    '\ue000': ['00000100000', '10001110001', '11001110011', '11111111111', '01111111110', '01111111110', '00000000000', '01111111110', '01111111110'],
    '\ue001': ['00000000110', '00000001110', '00000011100', '00000111000', '01001110000', '00111100000', '00011000000', '00101100000', '01000010000'],
    '\ue002': ['11111111111', '11000000011', '11000100011', '11000100011', '11011111011', '01000100010', '00100100100', '00010101000', '00001110000'],
    '✓': ['0000000011', '0000000110', '0000001100', '1100011000', '0110110000', '0011100000', '0001000000'],
    '→': ['0000010000', '0000011000', '1111111100', '1111111110', '1111111100', '0000011000', '0000010000'],
    '·': ['00000', '00000', '00000', '00110', '00110', '00000', '00000'],
}


def build() -> None:
    font = TTFont(SOURCE, recalcTimestamp=False)
    cmap = font.getBestCmap()
    order = font.getGlyphOrder()
    for character, rows in PIXELS.items():
        # 숫자는 한글의 11칸 높이와 기준선을 맞춘다.
        if character.isdigit():
            rows = rows[:3] + [rows[3]] + rows[3:6] + [rows[6]] + rows[6:]
        codepoint = ord(character)
        name = cmap.get(codepoint, f'kingdom{codepoint:04X}')
        if name not in order:
            order.append(name)
        pen = TTGlyphPen(None)
        for y, row in enumerate(rows):
            for x, pixel in enumerate(row):
                if pixel != '1':
                    continue
                left, top = (x + 1) * 100, (len(rows) - y) * 100
                pen.moveTo((left, top))
                pen.lineTo((left + 100, top))
                pen.lineTo((left + 100, top - 100))
                pen.lineTo((left, top - 100))
                pen.closePath()
        font['glyf'][name] = pen.glyph()
        font['hmtx'][name] = (800 if character.isdigit() else (len(rows[0]) + 2) * 100, 100)
        for table in font['cmap'].tables:
            if table.isUnicode():
                table.cmap[codepoint] = name
    font.setGlyphOrder(order)
    # 파생 글꼴의 표시 이름을 구분하고 원저작권·OFL 메타데이터는 보존한다.
    names = {1: 'Kingdom Dot', 2: 'Regular', 3: 'KingdomDot-Regular-1.000', 4: 'Kingdom Dot Regular', 5: 'Version 1.000', 6: 'KingdomDot-Regular', 16: 'Kingdom Dot', 17: 'Regular'}
    for name_id, value in names.items():
        font['name'].removeNames(nameID=name_id)
        font['name'].setName(value, name_id, 3, 1, 0x409)
    font['head'].modified = font['head'].created
    font.save(OUTPUT)
    result = TTFont(OUTPUT)
    chars = result.getBestCmap()
    assert all(cp in chars for cp in range(0xAC00, 0xD7A4))
    assert all(ord(ch) in chars for ch in PIXELS)
    print(f'FONT BUILD PASS: {OUTPUT.name}, Hangul 11172/11172, custom glyphs {len(PIXELS)}')


if __name__ == '__main__':
    build()
