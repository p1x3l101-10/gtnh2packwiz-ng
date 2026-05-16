# gtnh2packwiz-ng
---

A full rewrite of the previous tool in a language that is more suited to the task

~Now actually functional!~

To build, you just run the tool `./gtnh2packwiz-ng.nu`

To apply an overlay (Like one of mine that can be found [here](./overlays)) run ./overlay.nu and it will apply one that matches the version.

To change the version being built, update the version number in [`./util/mod.nu`](./util/mod.nu)

---
## Requirements
- [Nushell](https://www.nushell.sh/) version 0.112.2
    - Should work with other versions, but this is the version I used for development and Nushell updates tend to break things occasionally
- An unzip binary on your `$PATH`
- A POSIX compliant system
    - Not strictly required, however I do not do development on Windows so running the script directly probably won't work
    - Also does not apply to some Linux distros (NixOS), but they should still work if you have the needed executables available
