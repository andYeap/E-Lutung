#!/usr/bin/env bash
#
# Menolak huruf asing yang tidak pernah dipakai di proyek ini.
#
# Proyek ini ditulis dalam bahasa Indonesia dan nama simbolnya ASCII, kecuali
# Sigma dan tanda minus tipografis di rumus PRD.md. Karena itu huruf Han,
# Hiragana, Katakana, Hangul, atau Cyrillic tidak punya alasan sah untuk
# muncul: kemunculannya berarti ada teks yang rusak, dan harus tertangkap
# sebelum sampai ke commit.
#
# Pemakaian:
#   tool/check-charset.sh            # semua berkas terlacak + untracked
#   tool/check-charset.sh --staged   # hanya yang sedang di-stage
#
# Escape hatch: bila suatu baris memang perlu huruf asing (mis. contoh teks
# untuk menguji OCR), tambahkan penanda @charset-allow di baris yang sama.

set -uo pipefail

cd "$(dirname "$0")/.."

# Han, Hiragana, Katakana, Hangul, Cyrillic.
# Greek sengaja tidak dilarang karena PRD.md memakai Sigma untuk penjumlahan.
readonly FORBIDDEN='[\x{4e00}-\x{9fff}\x{3400}-\x{4dbf}\x{3040}-\x{30ff}\x{ac00}-\x{d7af}\x{0400}-\x{04ff}]'

readonly SKIP_EXT='\.(png|jpg|jpeg|pdf|gif|webp|ico|jar|keystore|jks|ttf|otf|woff2?)$'

if [[ "${1:-}" == "--staged" ]]; then
  mapfile -t files < <(git diff --cached --name-only --diff-filter=ACM | grep -vE "$SKIP_EXT" || true)
else
  mapfile -t files < <(
    { git ls-files; git ls-files --others --exclude-standard; } \
      | sort -u \
      | grep -vE "$SKIP_EXT" \
      || true
  )
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "check-charset: tidak ada berkas untuk diperiksa."
  exit 0
fi

jumlah_bermasalah=0

for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue

  # Lewati berkas biner yang lolos saringan ekstensi.
  grep -Iq . "$f" 2>/dev/null || continue

  offender=$(grep -nP "$FORBIDDEN" "$f" 2>/dev/null | grep -v '@charset-allow' || true)
  [[ -n "$offender" ]] || continue

  jumlah_bermasalah=$((jumlah_bermasalah + 1))
  echo "---------------------------------------------------------------"
  echo "BERKAS: $f"
  # Batasi 10 baris per berkas supaya output tetap terbaca.
  echo "$offender" | head -10 | sed 's/^/  /'

  total=$(printf '%s\n' "$offender" | wc -l | tr -d ' ')
  if [[ "$total" -gt 10 ]]; then
    echo "  ... dan $((total - 10)) baris lain"
  fi
done

if [[ $jumlah_bermasalah -gt 0 ]]; then
  echo "---------------------------------------------------------------"
  echo "GAGAL: $jumlah_bermasalah berkas memuat huruf asing yang tidak disengaja."
  echo "Ganti dengan huruf Latin/ASCII yang benar, atau tambahkan penanda"
  echo "@charset-allow bila memang diperlukan."
  exit 1
fi

echo "check-charset: OK (${#files[@]} berkas diperiksa)."
