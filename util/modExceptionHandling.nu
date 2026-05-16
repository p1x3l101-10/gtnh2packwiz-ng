# It agonizes me that I must do this, but here we are

const mavenUrl = "https://nexus.gtnewhorizons.com/repository/releases"

const mavenCoordDB = {
  "Catwalks-2": "com/github/GTNewHorizons/Catwalks-2"
  "Galaxy-Space-GTNH": "com/github/GTNewHorizons/Galaxy-Space-GTNH"
  "harvestcraft": "com/github/GTNewHorizons/harvestcraft"
  "Tinkers-Gregworks": "com/github/GTNewHorizons/TinkersGregworks"
}

const mavenNameUpdates = {
  "Tinkers-Gregworks": "TinkersGregworks"
}

const versionCorrections = {
  "Industrial Craft 2": {
    "2.2.82a-experimental": "2.2.2.828"
  }
}

const versionAlterations = {
  # Source went down, perhaps I can fudge it slightly with a newer version?
  "Tinkers-Gregworks": {
    "1.0.28": "GTNH-1.0.30"
  }
}

export def problemChildren [] {
  $mavenCoordDB | columns
}

export def fixVersion [
  name: string
  givenVersion: string
] {
  if ($name in ($versionCorrections | columns)) {
    let versions = $versionCorrections | get $name
    if ($givenVersion in ($versions | columns)) {
      return ($versions | get $givenVersion)
    }
  }
  $givenVersion
}

def fixMvnName [] {
  let name = $in
  if ($name in ($mavenNameUpdates | columns)) {
    return ($mavenNameUpdates | get $name)
  }
  return $name
}

export def alterVersion [
  name: string
  givenVersion: string
] {
  if ($name in ($versionAlterations | columns)) {
    let versions = $versionAlterations | get $name
    if ($givenVersion in ($versions | columns)) {
      return ($versions | get $givenVersion)
    }
  }
  $givenVersion
}

export def problemHandling [
  mod: record
] {
  getDLFromMaven $mod.name (alterVersion $mod.name $mod.version)
}

def getDLFromMaven [
  name: string
  version: string
] {
  $mavenUrl
  | url parse
  | update path { |url|
    $url.path | path join ($mavenCoordDB | get $name) | path join $version | path join ([($name | fixMvnName) "-" $version ".jar"] | str join)
  }
  | url join
}
