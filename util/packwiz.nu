use base.nu
use logging.nu [ log lvl ]
use set.nu
use std/assert
use extTools.nu [ link ]

export-env {
  use extTools.nu
}

export def metafileSchema [
  name: string
  filename: string
  side: string
] {
  let downloadData = $in
  {
    name: $name
    filename: $filename
    side: $side
    download: $downloadData
  }
}

export def metafileDownloadSchema [
  downloadUrl: string
  hashFormat?: string
  hashMessage?: string
  --generate-hash(-g)
] {
  if ((not $generate_hash) and (($hashFormat | is-empty) or ($hashMessage | is-empty))) {
    error make {
      msg: "You must either allow the downloader to generate it's own hash, or you must provide a hash of your own"
      labels: [
        { text: "This must be a valid hash format", span: (metadata $hashFormat).span }
        { text: "This must be a valid message digest", span: (metadata $hashMessage).span }
      ]
    }
  }
  if ($generate_hash) {
    let workFile = $nu.temp-dir | path join "gtnh2packwiz/modDownloads"
    "Downloading file for hash" | log $lvl.trace
    http get $downloadUrl | save $workFile
    let hashMessage = (open --raw $workFile | hash sha256)
    return {
      url: $downloadUrl
      "hash-format": "sha256"
      hash: $hashMessage
    }
  } else {
    return {
      url: $downloadUrl
      "hash-format": $hashFormat
      hash: $hashMessage
    }
  }
}

def genIndexFileJob [
  fileList: list
  --metafiles(-m)
] {
  job spawn {
    $fileList
    | par-each { |file|
      open --raw $file
      | hash sha256
      | {
        file: $file
        hash: $in
      }
      | (
        if ($metafiles) {
          insert metafile true
        } else {
          $in
        }
      )
    }
    | job send 0 --tag (job id)
  }
}

export def indexSchema [
  fileList: list
  metaFileList: list
  --no-internal-hashes
] {
  (
    if (not $no_internal_hashes) {
      [
        (genIndexFileJob $fileList)
        (genIndexFileJob $metaFileList --metafiles)
      ]
      | par-each { |jobId|
        job recv --tag $jobId
      }
      | flatten
      | sort-by file
    } else {
      [
        $fileList
        $metaFileList
      ]
      | flatten
      | sort-by file
    }
  )
  | {
    "hash-format": "sha256"
    files: $in
  }
}

export def packSchema [
  name: string
  author: string
  version: string
  indexFile: string
  componentVersions: record
] {
  open --raw $indexFile
  | hash sha256
  | {
    name: $name
    author: $author
    version: $version
    index: {
      file: ($indexFile | path basename)
      hash-format: "sha256"
      hash: $in
    }
    versions: $componentVersions
  }
}

def verifyHashSha256 [
  file: string
  hash: string
] {
  (open --raw $file | hash sha256) == $hash
}

def loadAndVerify [
  hashFormat: string
  baseDir: string
] {
  let indexRecord = $in
  let indexFilePath = $baseDir | path join $indexRecord.file
  assert ($hashFormat == "sha256") "This currently only supports sha256 hashing"
  assert (verifyHashSha256 $indexFilePath $indexRecord.hash) "Hash is not valid"
  open $indexFilePath
}

def mutateIndex [
  annotation: string
] {
  get files
  | par-each { |indexFile|
    $indexFile
    | insert x-overlay-source $annotation
  }
}

export def applyOverlay [
  packBaseDir: string
  overlayDir: string
  outputDir: string
  --use-base-info(-b)
] {
  let workDir = mktemp -d
  "Loading files" | log
  let packBase = open ($packBaseDir | path join "pack.toml")
  let overlay = open ($overlayDir | path join "pack.toml")
  let infoSource = (if ($use_base_info) {$packBase} else {$overlay})

  let baseIndex = $packBase.index | loadAndVerify $packBase.index.hash-format $packBaseDir | mutateIndex "base"
  let overlayIndex = $overlay.index | loadAndVerify $overlay.index.hash-format $overlayDir | mutateIndex "overlay"
  "Applying overlay" | log
  ($overlayIndex ++ $baseIndex)
  | uniq-by file
  | par-each { |indexFile|
    let sourceDir = (if ($indexFile.x-overlay-source == "base") {
      $packBaseDir
    } else {
      $overlayDir
    })
    let target = $workDir | path join $indexFile.file
    mkdir ($target | path dirname)
    cp ($sourceDir | path join $indexFile.file) $target
    $indexFile | reject x-overlay-source
  }
  | sort-by file
  | {
    hash-format: "sha256"
    files: $in
  }
  | to toml | save -f ($workDir | path join $infoSource.index.file)
  "Writing entrypoint" | log
  $infoSource
  | update index.hash (open --raw ($workDir | path join $infoSource.index.file) | hash sha256)
  | to toml | save -f ($workDir | path join "pack.toml")
  mv $workDir $outputDir
  "Done" | log
}
