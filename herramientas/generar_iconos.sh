#!/usr/bin/env bash
# Genera los iconos de la app a partir del logo completo (assets/icon/logo.png).
#
# Por qué hace falta este paso: el logo de marca es apaisado (~2:1) y viene con
# márgenes enormes dentro de su lienzo. Usado tal cual como icono se ve diminuto
# y perdido en el centro, y al aplicarle Android su máscara circular el texto
# queda cortado. Así que aquí se recorta el isotipo (el cilindro) y se centra a
# un tamaño que llene el icono.
#
# Produce:
#   assets/icon/logo_app.png          icono base (marca sobre blanco, sin alfa)
#   assets/icon/logo_adaptativo.png   capa frontal del icono adaptativo Android
#   android/.../drawable-*/ic_notification.png  icono de la barra de estado
#
# Uso:  ./herramientas/generar_iconos.sh   (requiere ImageMagick)
#       después:  dart run flutter_launcher_icons
set -euo pipefail

cd "$(dirname "$0")/.."
ORIGEN="assets/icon/logo.png"
RES="android/app/src/main/res"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v magick >/dev/null || { echo "Falta ImageMagick (magick)"; exit 1; }
[ -f "$ORIGEN" ] || { echo "No existe $ORIGEN"; exit 1; }

# 1. Quitar el blanco sobrante y quedarse con el isotipo (el tercio izquierdo).
magick "$ORIGEN" -fuzz 5% -trim +repage "$TMP/completo.png"
ancho=$(magick identify -format "%w" "$TMP/completo.png")
alto=$(magick identify -format "%h" "$TMP/completo.png")
# El recorte se da en píxeles en ambos ejes: mezclar píxeles con "100%" en la
# geometría no recorta lo que uno espera y se cuela parte del texto.
magick "$TMP/completo.png" -crop "$((ancho / 4))x${alto}+0+0" +repage \
  -fuzz 5% -trim +repage "$TMP/isotipo.png"

# 2. La silueta pasa a ser el canal alfa. Hace falta para las dos cosas: el
#    frente adaptativo necesita fondo transparente (el color lo pone la capa de
#    atrás), y el icono de notificación se dibuja SOLO con el alfa — Android
#    ignora el color y por eso un PNG opaco sale como un cuadrado blanco.
magick "$TMP/isotipo.png" -colorspace gray -alpha off -negate "$TMP/mask.png"
leer=$(magick identify -format "%wx%h" "$TMP/isotipo.png")
magick -size "$leer" xc:black "$TMP/mask.png" -alpha off \
  -compose copy_opacity -composite "$TMP/negro.png"
magick -size "$leer" xc:white "$TMP/mask.png" -alpha off \
  -compose copy_opacity -composite "$TMP/blanco.png"

# 3. Iconos de la app. Tamaño de la marca en el frente adaptativo: hay que
#    contar dos reducciones encadenadas. flutter_launcher_icons mete la capa en
#    un inset del 16% (se queda en el 68%), y encima Android solo enseña el 66%
#    central al aplicar su máscara. Con 780/1024 la marca acaba ocupando ~52%
#    del icono, que llena bien el círculo sin que la máscara le coma nada
#    (su diagonal, 57%, cabe en el 66% visible). Bajarlo la deja "lejos".
#    Los PNG salen como RGBA (PNG32) a propósito: en escala de grises con alfa
#    flutter_launcher_icons los procesa mal y escribe un foreground vacío, sin
#    dar ningún error — el icono queda como un cuadro liso.
magick "$TMP/negro.png" -resize x780 -background none -gravity center \
  -extent 1024x1024 PNG32:assets/icon/logo_adaptativo.png
magick "$TMP/negro.png" -resize x740 -background white -gravity center \
  -extent 1024x1024 -alpha remove -alpha off PNG24:assets/icon/logo_app.png

# 4. Icono de la barra de estado, en las densidades que pide Android.
for par in mdpi:24 hdpi:36 xhdpi:48 xxhdpi:72 xxxhdpi:96; do
  dens="${par%%:*}"; px="${par##*:}"
  mkdir -p "$RES/drawable-$dens"
  magick "$TMP/blanco.png" -resize "x$((px * 88 / 100))" -background none \
    -gravity center -extent "${px}x${px}" \
    "PNG32:$RES/drawable-$dens/ic_notification.png"
done

echo "Iconos generados. Ahora ejecuta: dart run flutter_launcher_icons"
