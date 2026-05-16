export const config = {
  assemblerRepo: "https://github.com/GTNewHorizons/DreamAssemblerXXL"
  version: "2.8.4"
}

export use base.nu
export use logging.nu
export use packwiz.nu
export use set.nu
export use extTools.nu
export use modExceptionHandling.nu

export-env {
  use extTools.nu
}
