from app.passport.blocks import OCRBlock
from app.passport.geometry import NormRect


def block(
    block_id: str,
    text: str,
    x: float,
    y: float,
    w: float = 0.14,
    h: float = 0.035,
    confidence: float = 0.96,
) -> OCRBlock:
    return OCRBlock(
        id=block_id,
        text=text,
        confidence=confidence,
        bbox=NormRect(x=x, y=y, width=w, height=h),
    )


def first_spread_blocks(*, include_middle_name: bool = True) -> list[OCRBlock]:
    lines = [
        block("s", "45 08", 0.06, 0.04, w=0.1, h=0.03),
        block("n", "123456", 0.2, 0.04, w=0.12, h=0.03),
        block("ib", "Паспорт выдан", 0.06, 0.16, w=0.2),
        block("ibv", "ОТДЕЛОМ УФМС РОССИИ", 0.06, 0.21, w=0.28),
        block("ibv2", "ПО РЕСПУБЛИКЕ БАШКОРТОСТАН", 0.06, 0.25, w=0.3),
        block("id", "Дата выдачи", 0.06, 0.33, w=0.18),
        block("idv", "15.05.2012", 0.28, 0.33, w=0.14),
        block("dc", "Код подразделения", 0.06, 0.4, w=0.22),
        block("dcv", "770-001", 0.3, 0.4, w=0.12),
        block("ln", "Фамилия", 0.55, 0.16, w=0.14),
        block("lnv", "ИВАНОВ", 0.55, 0.21, w=0.16),
        block("fn", "Имя", 0.55, 0.28, w=0.1),
        block("fnv", "ИВАН", 0.55, 0.33, w=0.12),
        block("g", "Пол", 0.55, 0.5, w=0.08),
        block("gv", "МУЖ", 0.55, 0.55, w=0.08),
        block("bd", "Дата рождения", 0.72, 0.5, w=0.18),
        block("bdv", "19.07.1981", 0.72, 0.55, w=0.14),
        block("bp", "Место рождения", 0.55, 0.62, w=0.2),
        block("bpv", "Г. УФА", 0.55, 0.67, w=0.14),
        block("bpv2", "РЕСПУБЛИКА БАШКОРТОСТАН", 0.55, 0.72, w=0.28),
    ]
    if include_middle_name:
        lines[13:13] = [
            block("mn", "Отчество", 0.55, 0.39, w=0.14),
            block("mnv", "ИВАНОВИЧ", 0.55, 0.44, w=0.18),
        ]
    return lines
