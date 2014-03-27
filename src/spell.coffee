require('./define')

getSpellConfig = (spellID) ->
  cfg = queryTable(TABLE_SKILL, spellID)
  return null if not cfg?
  return cfg.config

getProperty = (origin, backup) ->
  return if backup? then backup else origin

getLevelConfig = (cfg, level) ->
  level -= 1
  return if cfg.levelConfig and cfg.levelConfig[level]? then cfg.levelConfig[level] else {}

plusThemAll = (config, env) ->
  return 0 unless config? and env?
  sum = 0
  if Array.isArray(env)
    sum += plusThemAll(config, e) for e in env
  else
    sum = config.c ? 0
    for k, v of config
      sum += env[k]*v if env[k]?
  return sum

calcFormular = (e, s, t, config) ->
  c = if config.c then config.c else 0
  return Math.ceil(plusThemAll(config.environment, e) + plusThemAll(config.src, s) + plusThemAll(config.tar, t) + c)

class Wizard
  constructor: () ->
    @wSpellDB = {}
    @wTriggers = {}
    @wSpellMutex = {}
    @wPreBuffState = { rs : BUFF_TYPE_NONE, ds : BUFF_TYPE_NONE, hs : BUFF_TYPE_NONE }

  faction: (newFaction) ->
    if newFaction? then @faction = newFaction
    return @faction

  installSpell: (spellID, level, cmd, delay = 0) ->
    cfg = getSpellConfig(spellID)
    level = 1 unless level? > 0
    return false unless cfg?
    levelConfig = getLevelConfig(cfg, level)

    @removeSpell(spellID, cmd) if @wSpellDB[spellID]
    @wSpellDB[spellID] = {level: level, delay: delay}

    @setupTriggerCondition(spellID, cfg.triggerCondition, levelConfig, cmd)
    @setupAvailableCondition(spellID, cfg.availableCondition, levelConfig, cmd)
    @doAction(@wSpellDB[spellID], cfg.installAction, levelConfig, @selectTarget(cfg, cmd), cmd)
    @spellStateChanged(cmd)

  setupAvailableCondition: (spellID, conditions, level, cmd) ->
    return false unless conditions
    thisSpell = @wSpellDB[spellID]
    for limit in conditions
      switch limit.type
        when 'effectCount' then thisSpell.effectCount = 0
        when 'tick'
          thisSpell.tick = {} unless thisSpell.tick?
          thisSpell.tick[limit.tickType] = 0
        when 'event' then @installTrigger(spellID, limit.event)

  setupTriggerCondition: (spellID, conditions, level, cmd) ->
    return false unless conditions?
    thisSpell = @wSpellDB[spellID]

    for limit in conditions
      switch limit.type
        when 'countDown' then thisSpell.cd = 0
        when 'event' then @installTrigger(spellID, limit.event)

  spellStateChanged: (cmd) ->
    return false unless cmd?
    cmd.routine?({id: 'SpellState', wizard:@, state: @calcBuffState()})

  removeSpell: (spellID, cmd) ->
    cfg = getSpellConfig(spellID)

    if cfg.triggerCondition?
      @removeTrigger(spellID, c.event) for c in cfg.triggerCondition when c.type is 'event'

    if cfg.availableCondition?
      @removeTrigger(spellID, c.event) for c in cfg.availableCondition when c.type is 'event'

    if cfg.uninstallAction?
      @doAction(@wSpellDB[spellID], cfg.uninstallAction, {}, @selectTarget(cfg, cmd), cmd)

    delete @wSpellDB[spellID]
    @spellStateChanged(cmd)

  installTrigger: (spellID, event) ->
    return false unless event?
    thisSpell = @wSpellDB[spellID]
    @wTriggers[event] = [] unless @wTriggers[event]?
    @wTriggers[event].push(spellID) if @wTriggers[event].indexOf(spellID) == -1
    thisSpell.eventCounters = {} unless thisSpell.eventCounters?
    thisSpell.eventCounters[event] = 0

  removeTrigger: (spellID, event) ->
    return false unless event? and @wTriggers[event]
    @wTriggers[event] = (id for id in @wTriggers[event] when id != spellID)
    delete @wTriggers[event] unless @wTriggers[event].length > 0

  castSpell: (spellID, level, cmd) ->
    cfg = getSpellConfig(spellID)
    thisSpell = @wSpellDB[spellID]
    level = thisSpell.level if thisSpell?
    return 'InvalidLevel' unless level?
    level = getLevelConfig(cfg, level)

    target = @selectTarget(cfg, cmd)

    [canTrigger, reason] = @triggerCheck(thisSpell, cfg.triggerCondition, level, target, cmd)
    return reason unless canTrigger

    @doAction(thisSpell, cfg.action, level, target, cmd)
    @updateCDOfSpell(spellID, true, cmd)
    @removeSpell(spellID, cmd) unless @availableCheck(spellID, cfg, cmd)
    delay = 0
    delay = thisSpell.delay if thisSpell?
    cmd.routine?({id:'Casting', spell:cfg.basic, caster:this, castee:target, delay: delay}) if cfg.basic?
    return true

  onEvent: (event, cmd) ->
    return true unless @wTriggers[event]?

    for id in @wTriggers[event]
      thisSpell = @wSpellDB[id]
      thisSpell.eventCounters[event]++ if thisSpell?
      @castSpell(id, null, cmd)

  clearSpellCD: (spellID, cmd) ->
    return false unless spellID? and @wSpellDB[spellID]?
    thisSpell = @wSpellDB[spellID]
    if thisSpell.cd? and thisSpell.cd isnt 0
      thisSpell.cd = 0
      cmd.routine?({id: 'SpellCD', cdInfo: thisSpell.cd}) if @isHero()

  updateCDOfSpell: (spellID, isReset, cmd) ->
    cfg = getSpellConfig(spellID)
    thisSpell = @wSpellDB[spellID]
    return [false, 'NotLearned'] unless thisSpell
    return [true, 'NoCD'] unless cfg.triggerCondition
    return [false, 'Dead'] unless @health > 0

    cdConfig = (c for c in cfg.triggerCondition when c.type == 'countDown')
    return [true, 'NoCD'] unless cdConfig.length > 0
    cdConfig = cdConfig[0]
    level = getLevelConfig(cfg, thisSpell.level)
    cd = getProperty(cdConfig.cd, level.cd)
    preCD = thisSpell.cd
    if isReset
      thisSpell.cd = cd
    else if @health <= 0
      thisSpell.cd = -1
    else
      thisSpell.cd -= 1 unless thisSpell.cd == 0

    cmd.routine?({id: 'SpellCD', cdInfo: thisSpell.cd}) if thisSpell.cd isnt preCD and @isHero()

  haveMutex: (mutex) -> @wSpellMutex[mutex]?

  setMutex: (mutex, count) ->
    @wSpellMutex[mutex] = count

  tickMutex: () ->
    for mutex, count of @.wSpellMutex
      count -= 1
      @.wSpellMutex[mutex] = count
      delete @.wSpellMutex[mutex] if count is 0

  tickSpell: (tickType, cmd) ->
    @tickMutex()

    for spellID, thisSpell of @wSpellDB
      @updateCDOfSpell(spellID, false, cmd)
      thisSpell.tick[tickType] += 1 if thisSpell.tick? and thisSpell.tick[tickType]? and tickType?
      @removeSpell(spellID, cmd) unless @availableCheck(spellID, getSpellConfig(spellID), cmd)

  availableCheck: (spellID, cfg, cmd) ->
    thisSpell = @wSpellDB[spellID]
    return false unless thisSpell

    conditions = cfg.availableCondition
    return true unless conditions

    level = getLevelConfig(cfg, thisSpell.level)
    for limit in conditions
      switch limit.type
        when 'effectCount' then return false unless thisSpell.effectCount < getProperty(limit.count, level.count)
        when 'tick' then return false unless thisSpell.tick[limit.tickType] < getProperty(limit.ticks, level.ticks)
        when 'event'
          count = getProperty(limit.eventCount, level.eventCount) ? 1
          return false unless thisSpell.eventCounters[limit.event] < count

    return true
  
  calcBuffState: () ->
    roleState = { rs : BUFF_TYPE_NONE, ds : BUFF_TYPE_NONE, hs : BUFF_TYPE_NONE }

    for spellID, thisSpell of@wSpellDB
      cfg = getSpellConfig(spellID)
      continue unless cfg.buffType?
      switch cfg.buffType
        when 'RoleDebuff' then roleState.rs = BUFF_TYPE_DEBUFF
        when 'HealthDebuff' then roleState.hs = BUFF_TYPE_DEBUFF
        when 'AttackDebuff' then roleState.ds = BUFF_TYPE_DEBUFF
        when 'HealthBuff' then roleState.hs = BUFF_TYPE_BUFF
        when 'AttackBuff' then roleState.ds = BUFF_TYPE_BUFF
        when 'RoleBuff' then roleState.rs = BUFF_TYPE_BUFF

    res = {}
    for k, s of roleState
      res[k] = s unless @wPreBuffState[k] is s
      switch k
        when 'hs' then res.hp = @health
        when 'ds' then res.dc = @attack

    @wPreBuffState = roleState

    return res
  
  selectTarget: (cfg, cmd) ->
    return [] unless cfg.targetSelection? and cfg.targetSelection.pool
    return [] unless cfg.targetSelection.pool is 'Self' or cmd?
    env = cmd.getEnvironment() if cmd?
    switch cfg.targetSelection.pool
      when 'Enemy' then pool = env.getEnemyOf(@)
      when 'Team' then pool = env.getTeammateOf(@).concat(@)
      when 'Teammate' then pool = env.getTeammateOf(@)
      when 'Self' then pool = @
      when 'Target' then pool = env.variable('tar')
      when 'Source', 'Attacker' then pool = env.variable('src')
      when 'SamePosition' then pool = env.getBlock(@pos).getRef()
      when 'RoleID' then pool = (m for m in env.getObjects() when m.id is cfg.targetSelection.roleID)
      when 'Block'
        blocks = cfg.targetSelection.blocks
        pool = if blocks? then (env.getBlock(b) for b in blocks) else env.getBlock()

    pool = [] unless pool?
    pool = [pool] unless Array.isArray(pool)

    if cfg.targetSelection.filter? and pool.length > 0
      for filter in cfg.targetSelection.filter
        switch filter
          when 'Alive' then pool = (p for p in pool when p.health > 0)
          when 'Visible' then pool = (p for p in pool when p.isVisible)
          when 'Hero' then pool = (p for p in pool when p.isHero())
          when 'Monster' then pool = (p for p in pool when not p.isHero())
          when 'SameBlock' then pool = (p for p in pool when p.pos is @pos)

    count = cfg.targetSelection.count ? 1
    if cfg.targetSelection.method? and pool.length > 0
      switch cfg.targetSelection.method
        when 'Rand'
          pool = env.randMember(pool, count)
          pool = [pool] unless Array.isArray(pool)
        when 'LowHealth' then pool = [pool.sort( (a, b) -> return a.health - b.health )[0]]

    if cfg.targetSelection.anchor and env?
      tmp = pool
      pool = []
      for t in tmp
        if not t.isBlock then t = env.getBlock(t.pos)
        x = t.pos % Dungeon_Width
        y = (t.pos-x) / Dungeon_Width
        for a in cfg.targetSelection.anchor when 0 <= a.x+x < Dungeon_Width and 0 <= a.y+y < Dungeon_Height
          pool.push(env.getBlock(a.x+x + (a.y+y) * Dungeon_Width ))

    return pool

  triggerCheck: (thisSpell, conditions, level, target, cmd) ->
    return [true] unless conditions?
    env = cmd.getEnvironment()
    for limit in conditions
      switch limit.type
        when 'chance' then return [false, 'NotFortunate'] unless env.chanceCheck(getProperty(limit.chance, level.chance))
        when 'card' then return [false, 'NoCard'] unless env.haveCard(limit.id)
        when 'alive' then return [false, 'Dead'] unless @health > 0
        when 'visible' then return [false, 'visible'] unless @isVisible
        when 'needTarget' then return [false, 'No target'] unless target?
        when 'countDown'
          return [false, 'NotLearned'] unless thisSpell?
          return [false, 'NotReady'] unless thisSpell.cd <= 0
        when 'myMutex'
          return [false, 'TargetMutex'] if @haveMutex(limit.mutex)
        when 'targetMutex'
          return [false, 'NoTarget'] unless target?
          return [false, 'TargetMutex'] if target.some( (t) -> return t.haveMutex(limit.mutex) )
        when 'event'
          return [false, 'NotLearned'] unless thisSpell?
          return [false, 'EventCount'] if limit.eventCount? and limit.eventCount > thisSpell.eventCounters[limit.event]
          thisSpell.eventCounters[limit.event] = 0 if limit.reset
        when 'property'
          from = limit.from ? -Infinity
          to = limit.to ? Infinity
          return [false, 'Property'] unless limit.property? and from < this[limit.property] < to

    return [true]

  getActiveSpell: () -> -1

  doAction: (thisSpell, actions, level, target, cmd) ->
    return false unless actions?
    env = cmd?.getEnvironment() # some action can't be triggerred when levelup
    for a in actions
      variables = {}
      variables = env.variable() if env?
      formularResult = calcFormular(variables, @, target, getProperty(a.formular, level.formular)) if getProperty(a.formular, level.formular)?

      delay = 0
      delay = thisSpell.delay if thisSpell?
      if a.delay
        delay += if typeof a.delay is 'number' then a.delay else env.rand() * a.delay.base + env.rand()*a.delay.range

      switch a.type
        when 'modifyVar' then env.variable(a.x, formularResult)
        when 'ignoreHurt' then env.variable('ignoreHurt', true)
        when 'replaceTar' then env.variable('tar', @)
        when 'setTargetMutex' then t.setMutex(getProperty(a.mutex, level.mutex), getProperty(a.count, level.count)) for t in target
        when 'setMyMutex' then @setMutex(getProperty(a.mutex, level.mutex), getProperty(a.count, level.count))
        when 'resetSpellCD' then t.clearSpellCD(t.getActiveSpell(), cmd) for t in target
        when 'ignoreCardCost' then env.variable('ignoreCardCost', true)
        when 'dropItem' then cmd.routine?({id:'DropItem', list: a.dropList})
        when 'rangeAttack', 'attack' then cmd.routine?({id: 'Attack', src: @, tar: t, isRange: true}) for t in target
        when 'showUp' then cmd.routine?({id: 'ShowUp', tar: t}) for t in target
        when 'costCard' then cmd.routine?({id: 'CostCard', card: a.card})
        when 'showExit' then cmd.routine?({id: 'ShowExit' })
        when 'resurrect' then cmd.routine?({id: 'Resurrect', tar: target})
        when 'randTeleport' then cmd.routine?({id: 'TeleportObject', obj: @})
        when 'kill' then cmd.routine?({id: 'Kill', tar: t}) for t in target
        when 'shock' then cmd?.routine?({id: 'Shock', time: a.time, delay: a.delay, range: a.range})
        when 'blink' then cmd.routine?({id: 'Blink', time: a.time, delay: a.delay, color: a.color})
        when 'changeBGM' then cmd.routine({id: 'ChangeBGM', music: a.music, repeat: a.repeat})
        when 'whiteScreen' then cmd.routine({id: 'WhiteScreen', mode: a.mode, time: a.time, color: a.color})
        when 'endDungeon' then cmd.routine({id: 'EndDungeon', result: a.result})
        when 'openBlock' then cmd.routine({id: 'OpenBlock', block: a.block})
        when 'playSound' then cmd.routine({id: 'SoundEffect', sound: a.sound})
        when 'chainBlock' then cmd.routine({id: 'ChainBlock', src: src, tar: a.target}) for src in a.source
        when 'castSpell' then @castSpell(a.spell, a.level ? 1, cmd)
        when 'heal'
          if a.self
            cmd.routine?({id: 'Heal', src: @, tar: @, hp: formularResult})
          else
            cmd.routine?({id: 'Heal', src: @, tar: t, hp: formularResult}) for t in target
        when 'installSpell'
          for t in target
            delay = 0
            delay = thisSpell.delay if thisSpell?
            if a.delay?
              delay += if typeof a.delay is 'number' then a.delay else a.delay.base + env.rand()*a.delay.range
            t.installSpell(getProperty(a.spell, level.spell), getProperty(a.level, level.level), cmd, delay)
        when 'damage'
          cmd.routine?({id: 'Damage', src: @, tar: t, damageType: a.damageType, isRange: a.isRange, damage: formularResult, delay: delay}) for t in target
        when 'playAction'
          if a.pos is 'self'
            cmd.routine?({id: 'SpellAction', motion: a.motion, ref: @ref})
          else if a.pos is 'target'
            cmd.routine?({id: 'SpellAction', motion: a.motion, ref: t.ref}) for t in target
        when 'tutorial' then cmd.routine?({id: 'Tutorial', tutorialId: act.tutorialId})
        when 'playEffect'
          if a.pos is 'self'
            cmd.routine?({id: 'Effect', delay: delay, effect: a.effect, pos: @pos})
          else if a.pos is 'target'
            cmd.routine?({id: 'Effect', delay: delay, effect: a.effect, pos: t.pos}) for t in target
          else if typeof a.pos is 'number'
            cmd.routine?({id: 'Effect', delay: delay, effect: a.effect, pos: a.pos})
          else if Array.isArray(a.pos)
            cmd.routine?({id: 'Effect', delay: delay, effect: a.effect, pos: pos}) for pos in a.pos
        when 'delay'
          c = {id: 'Delay'}
          if a.delay? then c.delay = a.delay
          cmd = cmd.next(c)
        when 'setProperty'
          modifications = getProperty(a.modifications, level.modifications)
          thisSpell.modifications = {} unless thisSpell.modifications?
          for property, formular of modifications
            val = calcFormular(variables, @, null, formular)
            @[property] += val
            thisSpell.modifications[property] = 0 unless thisSpell.modifications[property]?
            thisSpell.modifications[property] += val
        when 'resetProperty'
          for property, val of thisSpell.modifications
            @[property] -= val
          delete thisSpell.modifications
        when 'clearDebuff', 'clearBuff'
          if a.type is 'clearDebuff'
            _buffType = ['RoleDebuff', 'HealthDebuff', 'AttackDebuff']
          else
            _buffType = ['RoleBuff', 'HealthBuff', 'AttackBuff']
          for h in target
            for spellID, thisSpell of h.wSpellDB
              cfg = getSpellConfig(spellID)
              h.removeSpell(spellID, cmd) if _buffType.indexOf(cfg.buffType) != -1
        when 'createMonster'
          c = {
            id: 'CreateObject',
            classID: getProperty(a.monsterID, level.monsterID),
            count: getProperty(a.objectCount, level.objectCount),
            withKey: getProperty(a.withKey, level.withKey),
            collectID: getProperty(a.collectID, level.collectID),
            effect: getProperty(a.effect, level.effect)
          }
          c.pos = @pos unless a.randomPos
          c.pos = a.pos if a.pos?
          cmd.routine?(c)
        when 'dialog' then cmd.routine?({id: 'Dialog', dialogId: a.dialogId})

    thisSpell.effectCount += 1 if thisSpell?.effectCount?

exports.Wizard = Wizard
exports.fileVersion = -1
