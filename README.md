# tlpr-zig

## Library

Most ESC/POS commands are implemented in `src/commands.zig`.

## CLI

```
usage: tlpr --ip <ip> [options]
       tlpr --stdout  [options]
    Thermal Line Printer application.
    Prints stdin through thermal printer.

    -c cut paper after printing.
    -e emphasis
    -n don't initialize the printer when connecting
    -r reverse black/white printing
    -u underline
    -uu double underline
    --height <1-8> select character height
    --image <path> print an image
    --ip the IP address of the printer
    --justify <left|right|center>
    --rotate rotate 90 degrees clockwise
    --stdout write commands to standard out instead of sending over a socket
    --threshold <value> image b/w threshold, 0-255 (default 150).
    --threshold <min-max> image b/w threshold, randomized between min-max per pixel
    --upsidedown enable upside down mode
    --width <1-8> select character width
```
