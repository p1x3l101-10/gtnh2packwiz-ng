#!/usr/bin/env nu

use util/packwiz.nu
use util/logging.nu [ log ]

def main [] {
  let packDir = "./gtnh" | path expand
  let config = open ($packDir | path join config.nuon)
  let overlayDir = "./overlays" | path join $config.version | path expand
  let outDir = "./gtnh-patched" | path expand
  if ($outDir | path exists) { rm -r $outDir }
  if ($overlayDir | path exists) {
    $"Applying overlay for version ($config.version)" | log
    packwiz applyOverlay $packDir $overlayDir $outDir
  } else {
    "No overlay to apply" | log
  }
}
