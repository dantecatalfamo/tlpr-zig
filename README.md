# tlpr-zig

## Library

Most ESC/POS commands are implemented in `src/commands`.

## CLI

```
usage: tlpr --ip <ip> [options]
    Thermal Line Printer application.
    Prints stdin through thermal printer.

    -c cut paper after printing.
    --justify <left|right|center>
    -u underline
    -uu double underline
    -e emphasis
    --rotate rotate 90 degrees clockwise
    --upsidedown enable upside down mode
    --height <1-8> select character height
    --width <1-8> select character width
    -r reverse black/white printing
    -n don't initialize the printer when connecting
    --image <path> print an image
    --threshold <value> image b/w threshold (default 150).
    --threshold <min-max> image b/w threshold, randomized between min-max per pixel
```
