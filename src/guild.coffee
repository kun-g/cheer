class Upgradeable
  constructor: (@getter,@setter) ->

  upgrade: (oprator) ->

  currentLevel:(level) ->
    if level?
      @setter(level)
    else
      @getter()

  upgradeCost: (level) ->

  canUpgrade: () ->

class Guild
