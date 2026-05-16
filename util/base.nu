use std/dirs
use logging.nu [ log lvl ]

# Nushell non-bug workaround
export-env {
    use std/dirs []
}

export def mktemp [] {
  $nu.temp-dir | path join (random uuid)
}

export def agecheck [
  maxAge: duration
] {
  let file = $in
  (ls -l $file | get 0.modified) <= ((date now) - $maxAge)
}

export def extract [
  destPath: string
  --force-overwrite(-f)
] {
  let zipFile = $in
  # Check if we should skip this step
  if (($destPath | path exists) and ((ls -l $zipFile | get 0.modified) <= (ls -l $destPath | get 0.created)) and (not ($force_overwrite))) {
    "Extracted contents are up to date" | log $lvl.trace
    return
  } else {
    if ($destPath | path exists) {
      rm -r $destPath
    }
  }
  let tempDir = mktemp
  mkdir $tempDir
  dirs add $tempDir
  ^unzip $zipFile
  | ignore
  dirs drop
  if ((ls $tempDir | length) > 1) {
    mv $tempDir $destPath
  } else {
    let outPath = ls $tempDir | get 0.name
    mv $outPath $destPath
    rm -r $tempDir # Cleanup
  }
}
