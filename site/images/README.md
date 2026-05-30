# site/images

Slots wired into the magazine. Drop files at these exact paths and they'll appear automatically — no HTML edits.

## app-icon.png
Already populated from the iOS bundle. Drives the masthead mark, favicon, and Open Graph image.

## screens/
App screenshots from the iOS simulator (filled by the simulator capture step).

- `home.png` — Home screen (download phone stack, left)
- `result.png` — A scored Result screen (download phone stack, center)
- `store.png` — Store / catalog screen (download phone stack, right)
- `capture.png` — Camera/capture screen (Vision section)

PNG, portrait, ~1206×2622 (iPhone 17 Pro native). The CSS clips to the 9:19.5 device aspect ratio.

## products/
Editorial product photographs you provide — they appear in the "From the Field" gallery between the Cover and Method sections.

- `01.jpg` … `06.jpg` — six polaroid slots.
- JPEG, roughly 4:5 portrait. Any size; CSS will cover-crop.

Empty slots fall back to a hatched placeholder so the layout never breaks.
