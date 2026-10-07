#!/usr/bin/env bash
# Cetak ulang PRD.pdf dari PRD.md.
#
# Memakai python3 (tanpa paket tambahan) untuk mengubah markdown menjadi HTML,
# lalu chromium headless untuk mencetaknya. Tidak ada unduhan apa pun: keduanya
# sudah ada di sistem.
#
# Pemakaian: tool/prd-ke-pdf.sh        (dari mana saja)
#
# Catatan: setiap pencetakan menghasilkan berkas yang berbeda byte-nya karena
# chromium menuliskan waktu pembuatan, jadi PRD.pdf akan selalu tampak berubah
# di git walau isinya sama. Bandingkan isinya (mis. dengan pdftotext) sebelum
# menganggap ada perubahan sungguhan.

set -euo pipefail

akar="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kerja="$(mktemp -d)"
trap 'rm -rf "$kerja"' EXIT

python3 "$akar/tool/prd_ke_html.py" "$akar/PRD.md" "$kerja/PRD.html"

chromium --headless=new --no-sandbox --disable-gpu \
  --user-data-dir="$kerja/profil" \
  --no-pdf-header-footer --virtual-time-budget=10000 \
  --print-to-pdf="$akar/PRD.pdf" "file://$kerja/PRD.html" 2>&1 | tail -1

ls -la "$akar/PRD.pdf" | awk '{print "PRD.pdf: " $5 " byte"}'
