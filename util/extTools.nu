export-env {
  if ((which ln | where $it.type == "external") != []) {
    $env.SUPPORTS_HARDLINKS = true
  } else {
    $env.SUPPORTS_HARDLINKS = false
  }
}

def getINode [] {
  ^ls -i $in | split words | get 0 | into int
}

export def link [
  file: string
  dest: string
  --create-parent(-p)
] {
  if ($create_parent) {
    mkdir ($dest | path dirname)
  }

  if ($env.SUPPORTS_HARDLINKS) {
    if ($dest | path exists) {
      if (($file | getINode) == ($dest | getINode)) {
        return
      } else {
        rm $dest
      }
    }
    ln $file $dest
  } else {
    cp $file $dest
  }
}
