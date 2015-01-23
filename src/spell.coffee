"use strict"
require('./define')
triggerLib = require('./trigger')

getSpellConfig = (spellID) ->
  cfg = queryTable(TABLE_SKILL, spellID)
  return null if not cfg?
  return cfg.config

getSpellProperty = (config, key, level) -> #getSpellProperty 
  level -= 1
  if config['#'+key]
    return config['#'+key][level]
  else
    return config[key]

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

calcFormular = (e, s, t, config, level) ->
  if config.func
    c = if config.c then config.c else {}
    return Math.ceil(config.func.apply(null,[e, s, t, c]))

  c = if config.c then config.c else 0
  return Math.ceil(
    plusThemAll(config.environment, e) +
    plusThemAll(config.src, s) +
    plusThemAll(config.tar, t) +
    c
  )
findObjWithKeyPair = (obj, keyPare) ->
  keyName =keyPare.name
  values = keyPare.values
  for k, v of obj
    if typeof v is 'object'
      result = findObjWithKeyPair(v, keyPare)
      return result if result?
    if k is keyName and values.indexOf(v) isnt -1
      return obj
  return null

exports.findObjWithKeyPair = findObjWithKeyPair #exports for testsuit

getValidatePlayerSelectPointFilter = (cfg,wizard, env) ->
  selectCfg = findObjWithKeyPair(cfg.targetSelection,
    {name:'pool', values:['select-object', 'select-block']})
  return null unless selectCfg?
  filterCfg = selectCfg.filter
  filterCfg = filterCfg.filter((e) -> e.type isnt 'count')
  pool = selectCfg.pool.replace(/select-(\w+)/, '$1s')
  objs = wizard.selectTarget({targetSelection:{pool:pool,filter:filterCfg}}, env)
  return objs.map((e) -> e.pos)

exports.getValidatePlayerSelectPointFilter = getValidatePlayerSelectPointFilter


class Wizard
  constructor: () ->
    @wSpellDB = {}
    @wTriggers = {}
    @wSpellMutex = {}
    @wPreBuffState = { rs : BUFF_TYPE_NONE, ds : BUFF_TYPE_NONE, hs : BUFF_TYPE_NONE }
    @activeSpell = []

  isAlive: () ->
    return @health > 0

  getActiveSpell: () ->
    return @activeSpell if @activeSpell.length > 0
    return [-1]

  installSpell: (spellID, level, cmd, delay = 0) ->
    cfg = getSpellConfig(spellID)
    level = 1 unless level? > 0
    return false unless cfg?

    @removeSpell(spellID, cmd) if @wSpellDB[spellID]
    @wSpellDB[spellID] = {level: level, delay: delay}
    @activeSpell.push(spellID)

    @setupTriggerCondition(spellID, cfg.triggerCondition,  cmd)
    @setupAvailableCondition(spellID, cfg.availableCondition,  cmd)
    @doAction(@wSpellDB[spellID], cfg.installAction,  @selectTarget(cfg, cmd?.getEnvironment()), cmd)
    @spellStateChanged(spellID, cmd)

  setupAvailableCondition: (spellID, conditions, cmd) ->
    return false unless conditions
    thisSpell = @wSpellDB[spellID]
    for limit in conditions
      switch limit.type
        when 'effectCount' then thisSpell.effectCount = 0
        when 'tick'
          thisSpell.tick = {} unless thisSpell.tick?
          thisSpell.tick[limit.tickType] = 0
        when 'event' then @installTrigger(spellID, limit.event)

  setupTriggerCondition: (spellID, conditions, cmd) ->
    return false unless conditions?
    thisSpell = @wSpellDB[spellID]

    for limit in conditions
      switch limit.type
        when 'countDown' then thisSpell.cd = 0
        when 'event' then @installTrigger(spellID, limit.event)

  calcEffectState: (spellID) ->
    cfg = getSpellConfig(spellID)
    if cfg.basic?.buffEffect?
      if @wSpellDB[spellID]
        return {id: cfg.basic.buffEffect}
      else
        return {id: cfg.basic.buffEffect, uninstall: true}
    else
      return null

  spellStateChanged: (spellID, cmd) ->
    return false unless cmd?
    cmd.routine?({id: 'SpellState', wizard:@, effect: @calcEffectState(spellID)})

  removeSpell: (spellID, cmd) ->
    return false unless @wSpellDB[spellID]
    cfg = getSpellConfig(spellID)

    if cfg.triggerCondition?
      @removeTrigger(spellID, c.event) for c in cfg.triggerCondition when c.type is 'event'

    if cfg.availableCondition?
      @removeTrigger(spellID, c.event) for c in cfg.availableCondition when c.type is 'event'

    if cfg.uninstallAction?
      @doAction(@wSpellDB[spellID], cfg.uninstallAction, @selectTarget(cfg, cmd?.getEnvironment()), cmd)

    delete @wSpellDB[spellID]
    @activeSpell = @activeSpell.filter((e) -> e isnt spellID)
    @spellStateChanged(spellID, cmd)

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

  castSpell: (spellID, cmd) ->
    cfg = getSpellConfig(spellID)
    return false unless cfg?
    thisSpell = @wSpellDB[spellID]

    target = @selectTarget(cfg, cmd?.getEnvironment())

    [canTrigger, reason] = @triggerCheck(thisSpell, cfg.triggerCondition, target, cmd)
    return reason unless canTrigger

    @doAction(thisSpell, cfg.action, target, cmd)
    return false unless cfg?
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
      @castSpell(id, cmd)

  clearSpellCD: (spellIDList, cmd) ->
    return false unless Array.isArray(spellIDList)
    for spellID in spellIDList
      continue unless @wSpellDB[spellID]?
      thisSpell = @wSpellDB[spellID]
      if thisSpell.cd? and thisSpell.cd isnt 0
        thisSpell.cd = 0
        cmd.routine?({id: 'SpellCD', cdInfo: thisSpell.cd}) if @isHero()

  getSpellCD:() ->
    for spellID, thisSpell of @wSpellDB
      return thisSpell.cd if thisSpell.cd?

  updateCDOfSpell: (spellID, isReset, cmd) ->
    cfg = getSpellConfig(spellID)
    thisSpell = @wSpellDB[spellID]
    return [false, 'NotLearned'] unless thisSpell
    return [true, 'NoCD'] unless cfg.triggerCondition
    return [false, 'Dead'] unless @isAlive()

    cdConfig = (c for c in cfg.triggerCondition when c.type == 'countDown')
    return [true, 'NoCD'] unless cdConfig.length > 0
    cd = getSpellProperty(cdConfig[0], 'cd', thisSpell.level)
    preCD = thisSpell.cd
    if isReset
      thisSpell.cd = cd
    else if not @isAlive()
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

    for limit in conditions
      switch limit.type
        when 'effectCount'
          return false unless thisSpell.effectCount < getSpellProperty(limit, 'count', thisSpell.level)
        when 'tick'
          return false unless thisSpell.tick[limit.tickType] < getSpellProperty(limit, 'ticks', thisSpell.level)
        when 'event'
          count = getSpellProperty(limit, 'eventCount', thisSpell.level) ? 1
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
  
  selectTarget: (cfg, env) ->
    return [] unless cfg.targetSelection? and cfg.targetSelection.pool
    return [] unless cfg.targetSelection.pool is 'self' or env?
    switch cfg.targetSelection.pool
      when 'self' then pool = @
      when 'target' then pool = env.variable('tar')
      when 'source' then pool = env.variable('src')
      when 'objects' then pool = env.getObjects()
      when 'select-object'
        playerChoice = +env.variable('playerChoice')
        pool = env.getObjects().filter((obj) -> obj.pos is playerChoice)
      when 'select-block' then pool = env.getBlock(env.variable('playerChoice'))
      when 'blocks'
        blocks = cfg.targetSelection.blocks
        pool = if blocks? then (env.getBlock(b) for b in blocks) else env.getBlock()

    pool = [] unless pool?
    pool = [pool] unless Array.isArray(pool)

    if cfg.targetSelection.filter? and pool.length > 0
      pool = triggerLib.filterObject(this, pool, cfg.targetSelection.filter, env)

    pool = [] unless pool?
    pool = [pool] unless Array.isArray(pool)

    return pool

  triggerCheck: (thisSpell, conditions, target, cmd) ->
    return [true] unless conditions?
    env = cmd.getEnvironment()
    for limit in conditions
      switch limit.type
        when 'chance'
          unless env.chanceCheck(getSpellProperty(limit, 'chance', thisSpell.level))
            return [false, 'NotFortunate']
        when 'card' then return [false, 'NoCard'] unless env.haveCard(limit.id)
        when 'alive' then return [false, 'Dead'] unless @isAlive()
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

  getActiveSpell: () -> [-1]

  getValidatePlayerSelectPoint: (spellID,env)->
    cfg = getSpellConfig(spellID)
    getValidatePlayerSelectPointFilter(cfg,@, env)


  doAction: (thisSpell, actions, target, cmd) ->
    return false unless actions?
    env = cmd?.getEnvironment() # some action can't be triggerred when levelup
    bakTarget = target
    for a in actions
      variables = {}
      if env?
        variables = env.variable()
        variables.heroCount = env.getAliveHeroes().length
        variables.totalMonsterCount = env.getMonsters().length
        variables.visibleMonsterCount = env.getMonsters().filter( (m) -> m.isVisible ).length
      if getSpellProperty(a, 'formular', thisSpell.level)?
        formularResult = calcFormular(
          variables,
          @,
          target,
          getSpellProperty(a, 'formular', thisSpell.level)
        )

      delay = 0
      delay = thisSpell.delay if thisSpell?
      if a.delay
        delay += if typeof a.delay is 'number' then a.delay else env.rand() * a.delay.base + env.rand()*a.delay.range

      target = bakTarget
      if a.target
        target = @selectTarget({targetSelection: a.target}, cmd?.getEnvironment())

      switch a.type
        when 'modifyVar' then env.variable(a.x, formularResult)
        when 'ignoreHurt' then env.variable('ignoreHurt', true)
        when 'ignoreAttack' then env.variable('ignoreAttack', true)
        when 'replaceTar' then env.variable('tar', @)
        when 'setTargetMutex'
          for t in target
            t.setMutex(
              getSpellProperty(a, 'mutex', thisSpell.level),
              getSpellProperty(a, 'count', thisSpell.level)
            )
        when 'setMyMutex'
          @setMutex(
            getSpellProperty(a, 'mutex', thisSpell.level),
            getSpellProperty(a, 'count', thisSpell.level)
          )
        when 'resetSpellCD' then t.clearSpellCD(t.getActiveSpell(), cmd) for t in target
        when 'ignoreCardCost' then env.variable('ignoreCardCost', true)
        when 'dropItem' then cmd.routine?({id:'DropItem', list: a.dropList})
        when 'dropPrize'
          cmd.routine?({ id:'DropPrize', dropID: a.dropID, me: @, showPrize: a.showPrize, motion: a.motion, ref: @.ref, effect: a.effect, pos:@pos})
        when 'rangeAttack', 'attack'
          aeffect = getSpellProperty(a, 'effect', thisSpell.level)
          adelay = getSpellProperty(a, 'delay', thisSpell.level)
          cmd.routine?({id: 'Attack', src: @, tar: t, isRange: true,hurtDelay:a.hurtDelay, eff:aeffect, effDelay:a.effDelay}) for t in target
        when 'showUp' then cmd.routine?({id: 'ShowUp', tar: t}) for t in target
        when 'costCard' then cmd.routine?({id: 'CostCard', card: a.card})
        when 'showExit' then cmd.routine?({id: 'ShowExit' })
        when 'resurrect' then cmd.routine?({id: 'Resurrect', tar: target})
        when 'randTeleport' then cmd.routine?({id: 'TeleportObject', obj: @})
        when 'kill'
          if a.self
            cmd.routine?({id: 'Kill', tar: @, cod: a.cod})
          else
            cmd.routine?({id: 'Kill', tar: t, cod: a.cod}) for t in target
        when 'shock' then cmd?.routine?({id: 'Shock', time: a.time, delay: a.delay, range: a.range})
        when 'tremble'
          switch a.act
            when 'self'
              cmd.routine?({id: 'Tremble', act:@ref, time: a.time, delay: a.delay, range: a.range})
            when 'target'
              for t in target
                cmd.routine?({id: 'Tremble', act:t.ref, time: a.time, delay: a.delay, range: a.range})
        when 'blink' then cmd.routine?({id: 'Blink', time: a.time, delay: a.delay, color: a.color})
        when 'changeBGM' then cmd.routine({id: 'ChangeBGM', music: a.music, repeat: a.repeat})
        when 'whiteScreen' then cmd.routine({id: 'WhiteScreen', mode: a.mode, time: a.time, color: a.color})
        when 'endDungeon' then cmd.routine({id: 'EndDungeon', result: a.result})
        when 'openBlock' then cmd.routine({id: 'OpenBlock', block: a.block})
        when 'playSound' then cmd.routine({id: 'SoundEffect', sound: a.sound})
        when 'chainBlock' then cmd.routine({id: 'ChainBlock', src: src, tar: a.target}) for src in a.source
        when 'castSpell' then @castSpell(a.spell, cmd)
        when 'newFaction' then env.newFaction(a.name)
        when 'changeFaction' then t.faction = a.faction for t in target
        when 'factionAttack' then env.factionAttack(a.src, a.tar, a.flag)
        when 'factionHeal' then env.factionHeal(a.src, a.tar, a.flag)
        when 'heal'
          if a.self
            cmd.routine?({id: 'Heal', src: @, tar: @, hp: formularResult, delay: delay})
          else
            cmd.routine?({id: 'Heal', src: @, tar: t, hp: formularResult, delay: delay}) for t in target
        when 'removeSpell' then t.removeSpell(a.spell, cmd) for t in target
        when 'installSpell'
          for t in target
            delay = 0
            delay = thisSpell.delay if thisSpell?
            if a.delay?
              delay += if typeof a.delay is 'number' then a.delay else a.delay.base + env.rand()*a.delay.range
            t.installSpell(
              getSpellProperty(a, 'spell', thisSpell.level),
              getSpellProperty(a, 'level', thisSpell.level),
              cmd,
              delay
            )
        when 'damage'
          cmd.routine?({id: 'Damage', src: @, tar: t, damageType: a.damageType, isRange: a.isRange, damage: formularResult, delay: delay}) for t in target
        when 'playAction'
          if a.pos is 'self'
            cmd.routine?({id: 'SpellAction', motion: a.motion, ref: @ref})
          else if a.pos is 'target'
            cmd.routine?({id: 'SpellAction', motion: a.motion, ref: t.ref}) for t in target
        when 'tutorial' then cmd.routine?({id: 'Tutorial', tutorialId: a.tutorialId})
        when 'playEffect'
          continue unless env?
          effect = getSpellProperty(a, 'effect', thisSpell.level)
          pos = getSpellProperty(a, 'pos', thisSpell.level)
          dir = getSpellProperty(a, 'dir', thisSpell.level)
          dir ?= env.variable('effdirlst')
          dir ?= [5]

          if pos?
            if pos is 'self'
              cmd.routine?({id: 'Effect', delay: delay, effect: effect, effdir:dir[0],pos: @pos})
            else if pos is 'target'
              for t, idx in target
                cmd.routine?({id: 'Effect', delay: delay, effect: effect, effdir:dir[idx],pos: t.pos})
            else if typeof pos is 'number'
              cmd.routine?({id: 'Effect', delay: delay, effect: effect, effdir:dir[0],pos: pos})
            else if Array.isArray(pos)
              for pos, idx in pos
                cmd.routine?({id: 'Effect', delay: delay, effect: effect, effdir:dir[idx],pos: pos})
          else
            switch a.act
              when 'self'
                cmd.routine?({id: 'Effect', delay: delay, effect: effect, effdir:dir[0],act: @ref})
              when 'target'
                for t, idx in target
                  cmd.routine?({id: 'Effect', delay: delay, effect: effect, effdir:dir[idx],act: t.ref})
        when 'delay'
          c = {id: 'Delay'}
          if a.delay? then c.delay = a.delay
          cmd = cmd.next(c)
        when 'setProperty'
          modifications = getSpellProperty(a, 'modifications', thisSpell.level)
          thisSpell.modifications = {} unless thisSpell.modifications?
          for property, formular of modifications
            val = calcFormular(variables, @, target, formular)
            @[property] += val
            thisSpell.modifications[property] = 0 unless thisSpell.modifications[property]?
            thisSpell.modifications[property] += val
        when 'resetProperty'
          continue unless thisSpell
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
        when 'collect' then cmd.routine({id: 'CollectID', collectId: a.collectID})
        when 'createMonster'
          c = {
            id: 'CreateObject',
            classID: getSpellProperty(a, 'monsterID', thisSpell.level),
            count: getSpellProperty(a, 'objectCount', thisSpell.level),
            withKey: getSpellProperty(a, 'withKey', thisSpell.level),
            collectID: getSpellProperty(a, 'collectID', thisSpell.level),
            effect: getSpellProperty(a, 'effect', thisSpell.level)
          }
          c.pos = @pos unless a.randomPos
          c.pos = a.pos if a.pos?
          cmd.routine?(c)
        when 'dialog' then cmd.routine?({id: 'Dialog', dialogId: a.dialogId})
        when 'rangeAttackEff'
          a.effect = level.effect if level.effect?
          cmd.routine?({id: 'RangeAttackEffect', dey: a.delay, eff: a.effect, src:@, tar: target})
        when 'showBubble'
          pos = getSpellProperty(a, 'pos', thisSpell.level)
          if pos?
            if pos is 'self'
              cmd.routine?({id: 'ShowBubble', pos:@pos, eff:a.effect, typ:a.bubbleType, cont:a.content, dey:a.delay, dur:a.duration})
            else if pos is 'target'
              for t in target
                cmd.routine?({id: 'ShowBubble', pos: t.pos, eff:a.effect, typ:a.bubbleType, cont:a.content, dey:a.delay, dur:a.duration})
            else if typeof pos is 'number'
              cmd.routine?({id: 'ShowBubble', pos: pos, eff:a.effect, typ:a.bubbleType, cont:a.content, dey:a.delay, dur:a.duration})
            else if Array.isArray(pos)
              for pos in pos
                cmd.routine?({id: 'ShowBubble', pos: pos, eff:a.effect, typ:a.bubbleType, cont:a.content, dey:a.delay, dur:a.duration})
          else
            switch a.act
              when 'self'
                cmd.routine?({id: 'ShowBubble', act:@ref, eff:a.effect, typ:a.bubbleType, cont:a.content, dey:a.delay, dur:a.duration})
              when 'target'
                for t in target
                  cmd.routine?({id: 'ShowBubble', act:t.ref, eff:a.effect, typ:a.bubbleType, cont:a.content, dey:a.delay, dur:a.duration})

    thisSpell.effectCount += 1 if thisSpell?.effectCount?

exports.Wizard = Wizard
exports.fileVersion = -1
