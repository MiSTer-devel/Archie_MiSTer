# [Acorn Archimedes](https://en.wikipedia.org/wiki/Acorn_Archimedes) for [MiSTer Board](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

### This is the port of [Archie](https://github.com/mist-devel/mist-board/tree/master/cores/archie) core from MiST by Stephen Leary

**CURRENTLY THIS CORE IS IN BETA STATUS**

1. Basic internals are implemented.
1. Basic Floppy disk support
1. Sound support added but may not work in all situations.
1. The core emulates a 4Mb A3000 type machine with an ARM2a with caches disabled for now (has an A3010 style joystick interface).
1. Core runs at ~91% of an ARM2 @ 8Mhz when using VGA Modes.
1. Some games now run. Expect issues.

## Installation

Copy the [*.rbf](https://github.com/MiSTer-devel/Archie_MiSTer/tree/master/releases) into a root folder of the SD card.
Copy a version of a RiscOS ROM into the "Archie" folder, renaming it to `riscos.rom`.

### Floppy disk images

The current version supports two floppy drives. Floppy disk images ADF format and of exactly 819200 bytes in size are currently required. This is the most common format for the Acorn Archimedes.

Images named `floppy0.adf` and `floppy1.adf` (from Archie folder) are auto-inserted into the floppy disk drives on startup. Other images can be selected via the on-screen-display (OSD) which can be opened using the **WIN+F12** key combo.


## OSD Menu

If the ROM is recognized the core should boot into Risc OS.
Press **Win+F12** to open the OSD menu.

* Floppy 0: Choose the floppy disk images to use for floppy 0
* Floppy 1: Choose the floppy disk images to use for floppy 1
* OS ROM: Choose the RISCOS rom to use
* Save config: Save current config for next boot

You can move to other pages of settings by pressing the right arrow key.

## Notes

* CPU module (amber23) has no reset signal, so the only way to reset the core is to reload it. MiSTer will help to reload the core if **USER** button is pressed (or reset combo pressed on keyboard) and core file is named as **"Archie.rbf"**. Otherwise you can reload the core manually from menu (**Win+Alt+F12**).


# License

This core uses the Amber CPU core from OpenCores which is LGPL.
The core itself is dual licensed LGPL/BSD.
