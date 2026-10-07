#!/usr/bin/env python3
"""Ubah PRD.md menjadi HTML siap cetak untuk `chromium --print-to-pdf`.

Menangani bentuk yang dipakai PRD: judul #/##/###, daftar - dan 1., kotak
centang - [x]/[ ], tabel pipa, garis pemisah ---, **tebal**, dan `kode`.

Biasanya tidak dipanggil langsung; pakai `tool/prd-ke-pdf.sh`.
"""

import html
import re
import sys


def inline(teks: str) -> str:
    keluar = html.escape(teks)
    keluar = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", keluar)
    keluar = re.sub(r"`(.+?)`", r"<code>\1</code>", keluar)
    return keluar


def ubah(md: str) -> str:
    baris = md.split("\n")
    keluar: list[str] = []
    i = 0
    daftar: str | None = None  # 'ul' atau 'ol'

    def tutup_daftar() -> None:
        nonlocal daftar
        if daftar:
            keluar.append(f"</{daftar}>")
            daftar = None

    while i < len(baris):
        isi = baris[i].strip()

        if not isi:
            tutup_daftar()
            i += 1
            continue

        # Tabel pipa: baris judul, baris pemisah, lalu baris isi.
        if (
            isi.startswith("|")
            and i + 1 < len(baris)
            and re.match(r"^\|[\s:\-|]+\|$", baris[i + 1].strip())
        ):
            tutup_daftar()
            judul = [k.strip() for k in isi.strip("|").split("|")]
            i += 2
            isi_tabel: list[list[str]] = []
            while i < len(baris) and baris[i].strip().startswith("|"):
                isi_tabel.append(
                    [k.strip() for k in baris[i].strip().strip("|").split("|")]
                )
                i += 1
            keluar.append("<table><thead><tr>")
            keluar.extend(f"<th>{inline(k)}</th>" for k in judul)
            keluar.append("</tr></thead><tbody>")
            for r in isi_tabel:
                keluar.append("<tr>")
                keluar.extend(f"<td>{inline(k)}</td>" for k in r)
                keluar.append("</tr>")
            keluar.append("</tbody></table>")
            continue

        if isi == "---":
            tutup_daftar()
            keluar.append("<hr/>")
            i += 1
            continue

        judul = re.match(r"^(#{1,6})\s+(.*)$", isi)
        if judul:
            tutup_daftar()
            tingkat = len(judul.group(1))
            keluar.append(f"<h{tingkat}>{inline(judul.group(2))}</h{tingkat}>")
            i += 1
            continue

        butir = re.match(r"^- (\[[ x]\] )?(.*)$", isi)
        if butir:
            if daftar != "ul":
                tutup_daftar()
                keluar.append("<ul>")
                daftar = "ul"
            kotak = (butir.group(1) or "").strip()
            tanda = "&#9745; " if kotak == "[x]" else ("&#9744; " if kotak else "")
            kelas = ' class="selesai"' if kotak == "[x]" else ""
            keluar.append(f"<li{kelas}>{tanda}{inline(butir.group(2))}</li>")
            i += 1
            continue

        bernomor = re.match(r"^\d+\.\s+(.*)$", isi)
        if bernomor:
            if daftar != "ol":
                tutup_daftar()
                keluar.append("<ol>")
                daftar = "ol"
            keluar.append(f"<li>{inline(bernomor.group(1))}</li>")
            i += 1
            continue

        tutup_daftar()
        keluar.append(f"<p>{inline(isi)}</p>")
        i += 1

    tutup_daftar()
    return "\n".join(keluar)


GAYA = """
@page { size: A4; margin: 16mm 15mm; }
body {
  font-family: "DejaVu Sans", "Noto Sans", sans-serif;
  font-size: 10.5pt; line-height: 1.5; color: #1b1b1b;
}
h1 { font-size: 20pt; margin: 0 0 14pt; }
h2 { font-size: 15pt; margin: 18pt 0 8pt; border-bottom: 2px solid #1b1b1b; padding-bottom: 3pt; page-break-after: avoid; }
h3 { font-size: 12.5pt; margin: 14pt 0 6pt; page-break-after: avoid; }
p { margin: 0 0 8pt; }
ul, ol { margin: 0 0 8pt; padding-left: 18pt; }
li { margin-bottom: 3pt; }
li.selesai { color: #235c3a; }
code { font-family: "DejaVu Sans Mono", monospace; font-size: 9.5pt; background: #f0f0ee; padding: 0 2pt; }
table { border-collapse: collapse; width: 100%; margin: 0 0 10pt; page-break-inside: avoid; font-size: 9.5pt; }
th, td { border: 1px solid #8a8a86; padding: 3pt 5pt; text-align: left; vertical-align: top; }
th { background: #ececea; }
hr { border: none; border-top: 1px solid #b8b8b4; margin: 14pt 0; }
"""


def main() -> None:
    sumber, tujuan = sys.argv[1], sys.argv[2]
    isi = open(sumber, encoding="utf-8").read()
    dokumen = (
        "<!DOCTYPE html>\n<html lang=\"id\">\n<head>\n"
        "<meta charset=\"utf-8\"/>\n"
        f"<style>{GAYA}</style>\n</head>\n<body>\n{ubah(isi)}\n</body>\n</html>\n"
    )
    open(tujuan, "w", encoding="utf-8").write(dokumen)
    print(f"HTML ditulis: {tujuan}")


if __name__ == "__main__":
    main()
