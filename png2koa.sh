#!/bin/bash
# uso: ./png2koa.sh immagine.png [altre.png ...]
for f in "$@"; do
  out="${f%.*}.koa"
  png2prg -m koala -o "${f%.*}.prg" "$f" && \
    tail -c +3 "${f%.*}.prg" > "$out" && rm "${f%.*}.prg"
done
