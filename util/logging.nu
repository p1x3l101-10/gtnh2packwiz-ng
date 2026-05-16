export const lvl = {
  fatal: 0
  error: 1
  warning: 2
  info: 3
  trace: 4
}

const defaultLogLevel = $lvl.info

const lvlMessages = [
  "FTAL"
  "ERRR"
  "WARN"
  "INFO"
  "TRCE"
]

const lvlColors = [
  (ansi bg_red)
  (ansi red)
  (ansi yellow)
  (ansi blue)
  (ansi light_gray_dimmed)
]

def defLvl [
  lvl?: int
] {
  get ($lvl | default $defaultLogLevel)
}

export def log [
  lvl?: int
] {
  let msg = $in
  let fullMessage = [
    ($lvlColors | defLvl $lvl)
    "["
    ($lvlMessages | defLvl $lvl)
    "]: "
    $msg
    (ansi reset)
  ]
  print ($fullMessage | str join "")
}
