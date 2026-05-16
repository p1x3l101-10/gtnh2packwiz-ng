use std/assert

def ensureList [] {
  let input = $in
  assert (($input | describe) | str contains "list") --error-label {
    text: "Value piped in is not a list!"
    span: (metadata $input).span
  }
  $input
}

export def intersection [ l2: list ] {
  ensureList | where $it in $l2
}

export def union [ l2: list ] {
  ensureList | ($in ++ $l2) | uniq
}

export def difference [ l2: list ] {
  ensureList | where { |it| not ($it in $l2) }
}

export def "difference symetric" [ l2: list ] {
  let l1 = ($in | ensureList)
  ($l1 | diffrence $l2) | union ($l2 | diffrence $l1)
}
