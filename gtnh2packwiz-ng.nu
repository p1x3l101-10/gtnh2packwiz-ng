#!/usr/bin/env nu

use util/base.nu [ "agecheck" "extract" ]
use util/logging.nu [ log lvl ]
use util/modExceptionHandling.nu [ problemChildren problemHandling fixVersion alterVersion ]
use util [ "config" "set" "extTools" ]

export-env {
  use util/extTools.nu
}

const sysTempDir = $nu.temp-dir | path join "gtnh2packwiz"
const maxAge = 6hr

def main [] {
  mkdir $sysTempDir
  let assemblerDir = $sysTempDir | path join "packMetadata"
  let packDir = $sysTempDir | path join "packConfig"
  let assemblerZip = [$assemblerDir ".zip"] | str join

  let assemblerDownload = (
    $config.assemblerRepo
    | url parse
    | update path { |url|
      $url.path | path join "archive/refs/heads/master.zip"
    }
    | url join
  )


  # Perform needed downloads
  if ((not ($assemblerZip | path exists)) or ($assemblerZip | agecheck $maxAge)) {
    "Downloading pack info" | log
    http get $assemblerDownload | save -fp $assemblerZip
  }

  "Extracting pack info" | log
  $assemblerZip | extract $assemblerDir

  let releaseManifest = open ($assemblerDir | path join (["releases/manifests/" $config.version ".json"] | str join))
  let packAssets = open ($assemblerDir | path join "gtnh-assets.json")
  let packData = open ($assemblerDir | path join "gtnh-modpack.json")
  # Fetch the pack config version from the pack info
  let packConfigVersion = $releaseManifest | get config
  ([ "True pack version is" $packConfigVersion] | str join " ") | log $lvl.trace
  let packDlInfo = $packAssets.config.versions | where $it.version_tag == $packConfigVersion | get 0
  let packZip = $sysTempDir | path join $packDlInfo.filename
  let packDownload = $packDlInfo.browser_download_url

  if (not ($packZip | path exists)) {
    "Downloading pack configs" | log
    print $packDownload
    http get $packDownload | save -fp $packZip
  }

  "Extracting pack configs" | log
  $packZip | extract $packDir

  # Generate configs
  let outWorkDir = $sysTempDir | path join "packGenerated"
  let exclusions = (
    {
      server: ($packData | get "server_exclusions")
      client: ($packData | get "client_exclusions")
    }
    | insert both { |exclusions|
      $exclusions.client | set intersection $exclusions.server
    }
    | update server { |exclusions|
      $exclusions.server | set difference $exclusions.both
    }
    | update client { |exclusions|
      $exclusions.client | set difference $exclusions.both
    }
  )
  "Copying pack configs" | log
  # This makes side effects
  let fileList = (
    glob ([$packDir "/**/*"] | str join) | each { str replace $"($packDir)/" "" }
    | set difference $exclusions.both
    | each { |path| $packDir | path join $path }
    | where { ($in | path type) == file }
    | par-each { |file|
      let destFile = $file | str replace $packDir $outWorkDir
      extTools link -p $file $destFile
      (["Linked file" $file] | str join " ") | log $lvl.trace
      $destFile
    }
  )

  "Generating pack metadata" | log $lvl.trace
  let modList = (
    [
      ($releaseManifest | get github_mods   | items { |k,v| { name: $k, ...$v }} | each { insert type "internal" })
      ($releaseManifest | get external_mods | items { |k,v| { name: $k, ...$v }} | each { insert type "external" })
    ] | flatten | each { |mod|
      {
        manifestPath: $"mods/($mod.name | str downcase).pw.toml"
        ...$mod
      }
    }
  )

  "Writing pack metadata" | log
  mkdir ($sysTempDir | path join "modDownloads")
  $modList | each { |mod|
    (["Generating metadata for mod:" $mod.name] | str join " ") | log $lvl.trace
    let modAsset = $packAssets.mods | where $it.name == $mod.name | get 0
    let fixedVersion = (fixVersion $mod.name $mod.version)
    let modVersion = $modAsset.versions | where $it.version_tag == $fixedVersion | get 0

    let downloadUrl = (
      # Why is it a universal constant that with every rule exists the most stupid exception
      # Note to self: Beg the pack developers to make the mod download slightly more accessable to anyone attempting to build when not blessed with an api key
      if ($mod.name in (problemChildren)) {
        problemHandling $mod
      } else {
        if ($mod.type == "external") {
          $modVersion.download_url
        } else {
          $modVersion.browser_download_url
        }
      }
    )
    let localCopy = $sysTempDir | path join "modDownloads" | path join (random uuid -v 5 -n oid -s $"($mod.name)____(alterVersion $mod.name $mod.version)")
    if (not ($localCopy | path exists)) {
      (["Caching mod"] | str join " ") | log $lvl.trace
      http get $downloadUrl | save -fp $localCopy
    }
    let hash = open --raw $localCopy | hash sha256
    {
      x-manifest-path: $mod.manifestPath
      name: $mod.name
      filename: $modVersion.filename
      side: ($mod.side | str downcase | str replace "_java9" "")
      download: {
        url: $downloadUrl
        "hash-format": sha256
        hash: $hash
      }
    }
  }
  | par-each { |manifest|
    $manifest
    | reject "x-manifest-path"
    | to toml | save -f ($outWorkDir | path join $manifest.x-manifest-path)
  }

  "Generating index" | log
  "Saving builder config into the index" | log $lvl.trace
  $config | to nuon | save -f ($outWorkDir | path join "config.nuon")
  (($fileList
    | par-each { |file| { file: $file } }
  ) ++ ($modList
    | par-each { |meta|
      {
        file: ($outWorkDir | path join $meta.manifestPath)
        metafile: true
      }
    }
  ) ++ [
    {
      file: ($outWorkDir | path join "config.nuon")
    }
  ])
  | par-each { |index|
    $index
    | insert hash (open --raw ($index.file) | hash sha256)
    | update file ($index.file | str replace $"($outWorkDir)/" "")
  }
  | sort-by file
  | {
    "hash-format": sha256
    files: $in
  }
  | to toml | save -f ($outWorkDir | path join "index.toml")

  "Generating modpack file" | log
  {
    name: $packAssets.config.name
    author: "DreamMasterXXL"
    version: $packConfigVersion
    pack-format: "packwiz:1.1.0"
    index: {
      file: "index.toml"
      hash-format: sha256
      hash: (open --raw ($outWorkDir | path join "index.toml") | hash sha256)
    }
    versions: {
      minecraft: "1.7.10"
      forge: "10.13.4.1614"
      unsup: "1.1.5" # Not needed for running, just for unsup to stay up to date
    }
  }
  | to toml | save -f ($outWorkDir | path join "pack.toml")

  "Moving working directory to output" | log $lvl.trace
  let outputDir = "." | path join "gtnh" | path expand
  if ($outputDir | path exists) { rm -r $outputDir }
  mv $outWorkDir $outputDir
  "Done" | log
}
