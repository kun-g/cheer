"use strict"
require('./define')
require('./shared')
{Wizard} = require './spell'
{DBWrapper} = require './dbWrapper'
{createUnit, Hero, Mirror} = require './unit'
{Item, Card} = require './item'
{CommandStream, Environment } = require('./commandStream')
{Bag, CardStack} = require('./container')
{parse, TriggerManager} = require('./trigger')
{generateReward} = require('./reward')

seed_random = require('./seed_random')
speedFormula = { 'a' : 1, 'b' : 60, 'c' : 0.5}
hitFormula = { 'a' : 1, 'b' : 150, 'c' : 0.75, downLimit : 0.5 }
criticalFormula = { 'a' : 7, 'b' : 140, 'c' : 0.1, upLimit : 0.4 }

flagShowRand = false

mapDiff = (source, excludeLst) ->
  result ={}
  for k, v of source when k not in excludeLst and v?
    result[k] =v
  return result


compete = (formula, dungeon) ->
  return (p1, p2) ->
    x = p1 - p2
    ret = 0
    if x > 0
      ret = formula.c + x/(formula.b+formula.a*x)
    else
      x = Math.abs(x)
      ret = formula.c - x/(formula.b+formula.a*x)

    if formula.downLimit? and formula.downLimit > ret then ret = formula.downLimit
    if formula.upLimit? and formula.upLimit < ret then ret = formula.upLimit

    rnd = dungeon.random()

    return  rnd < ret

privateRand = (round) ->
  ret = Math.floor(@random() * 1000000000)
  return if round then ret%round else ret

changeSeed = (seed) ->
  seed = rand() unless seed?
  @randSeed = seed
  randomFunc = seed_random.seedrandom(seed)

  @random = () ->
    ret = randomFunc()
    console.log('Rand:', ret) if flagShowRand
    #showMeTheStack()
    return ret

  Object.defineProperty(this, 'random', {enumerable:false})

calcInfiniteX = (infiniteLevel) ->
  if infiniteLevel % 10 is 0
    infiniteLevel/10
  else if infiniteLevel % 5 is 0
    infiniteLevel/5 - Math.floor(infiniteLevel/10)
  else
    infiniteLevel - Math.floor(infiniteLevel/5) - Math.floor(infiniteLevel/10)

calcInfiniteRank = (infiniteLevel, id) ->
  x = calcInfiniteX(infiniteLevel)
  if id? and id is 1
   return 1.5*x*x + 2*x + 1
  else
    return Math.ceil(0.1 * x*x + 0.1*x + 1)

# 创建怪物的设计：
# 指定位置 pos
# 指定属性 property
# 指定数量（单层，所有层，不多于，不少于） id* count from to
# 从池子里抽取（多个池子，池子附加属性） xx pool
createUnits = (rules, randFunc) ->
  rand = (mod) ->
    mod = 30 unless mod?
    r = randFunc()
    if r < 1 then r *= mod
    return r
  
  translateRule = (cRule) ->
    return [] unless cRule
    return cRule.map( (r) ->
      return r unless r.from? or r.to?
      currentRule = {}
      for k, v of r when k isnt 'from' and k isnt 'to'
        currentRule[k] = v
      if r.from? or r.to?
        if r.from? and r.to?
          currentRule.count = r.from + rand() % (r.to - r.from+1)
        else if r.from?
          currentRule.count = r.from + rand()
        else
          currentRule.count %= r.to+1
      return currentRule
    )

  levelRule = []
  levelOtherKey =[]
  for l in rules.levels
    levelRule.push(translateRule(l.objects))
  
    otherKeys = mapDiff(l,['objects','levels'])
    levelOtherKey.push(otherKeys)
 
  globalRule = translateRule(rules.global)

  levelConfig = []
  for i, l of levelRule
    cfg = {id: i, total: 0, limit: Infinity, takenPos:{}}
    for r in l when not (r.id? or r.pool?)
      if r.count? then cfg.limit = r.count
    levelConfig.push(cfg)

  selectFromPool = (poolID, count) ->
    (
      for i in [0..count-1]
        selectElementFromWeightArray(rules.pool[poolID].objects, rand())
    )

  selectPos = (positions, lConfig) ->
    pos = positions.filter( (p) -> not lConfig.takenPos[p] )
    if pos.length > 0 then return pos[rand()%pos.length]
    return -1

  placeUnit = (lRule, lConfig, single) ->
    result = []
    for r in lRule when r.id? or r.pool?
      count = r.count ? 1
      if single then count = 1
      if count + lConfig.total > lConfig.limit
        count = lConfig.total-lConfig.limit + count
      continue if count <= 0
      if r.id? then idList = [r]
      if r.pool?
        idList = selectFromPool(r.pool, count)
        count = 1
        proList = mapDiff(rules.pool[r.pool], ['objects'])
      idList.forEach( (c) ->
        if c?
          u = {}
          u[k] = v for k, v of c when k isnt 'levels'
          u[k] = v for k, v of proList
          u[k] = v for k, v of levelOtherKey[lConfig.id] if levelOtherKey[lConfig.id]?
          u[k] = v for k, v of mapDiff(r,['pool', 'levels', 'count'])
          u.count = count
          if r.pos
            if typeof r.pos is 'number' then u.pos = r.pos
            if Array.isArray(r.pos) then u.pos = selectPos(r.pos, lConfig)
            lConfig.takenPos[r.pos] = true
          lConfig.total += count
          result.push(u)
      )
    return result

  result = []
  result.push(placeUnit(l, levelConfig[i])) for i, l of levelRule

  for rule in globalRule
    gi = 0

    filterLevels = () ->
      cfg = levelConfig.filter( (c) -> c.total < c.limit )
      if rule.levels?.from? then cfg = cfg.filter( (c) -> c.id >= rule.levels.from )
      if rule.levels?.to? then cfg = cfg.filter( (c) -> c.id < rule.levels.to )
      return cfg

    while gi < rule.count
      cfg = filterLevels()

      if cfg.length <= 0 then break
      cfg = cfg[rand()%cfg.length]
      result[cfg.id] = result[cfg.id].concat(placeUnit([rule], cfg, true))

      gi++

  return result

exports.createUnits = createUnits

class Dungeon
  constructor: (data) ->
    @effectCounter = 0
    @killingInfo = []
    @prizeInfo = []
    @currentLevel = -1
    @cardStack = CardStack(5)
    @actionLog = []
    @revive = 0
    @factionDB = queryTable(TABLE_FACTION)

    @triggerManager = new TriggerManager(queryTable(TABLE_TRIGGER))
    return false unless data?

    this[k] = v for k, v of data
    @quests = deepCopy(@initialQuests) if @initialQuests?
    @config = @getConfig()
    cfg = @config
    if cfg.triggers
      @triggerManager.installTrigger(t, {}, @) for t in cfg.triggers

  onEvent: (event, cmd) -> @triggerManager.onEvent(event, cmd)
  newFaction: (name) -> @factionDB[name] = {} unless @factionDB[name]
  factionAttack: (src, dst, flag) -> changeFactionRelaction(src, dst, 'attackable', flag)
  factionHeal: (src, dst, flag) -> changeFactionRelaction(src, dst, 'healable', flag)
  changeFactionRelaction: (src, dst, relation, flag) ->
    return false unless @factionDB[src]?
    @factionDB[src][dst] = {} unless @factionDB[src][dst]?
    @factionDB[src][dst][relation] = flag

  rand: () -> privateRand.apply(this, arguments)

  changeSeed: () -> changeSeed.apply(this, arguments)

  getInitialData: () ->
    ret = { stage: @stage, randSeed: @randSeed, initialQuests: @initialQuests, team: @team, abIndex: @abIndex}
    ret.infiniteLevel = @infiniteLevel if @infiniteLevel?
    ret.blueStar = @blueStar if @blueStar?
    ret.baseRank = @baseRank if @baseRank
    ret.PVP_Pool = @PVP_Pool if @PVP_Pool
    return ret

  getStageConfig: () -> return queryTable(TABLE_STAGE, @stage, @abIndex)
  getConfig: () -> return queryTable(TABLE_DUNGEON, @getStageConfig().dungeon, @abIndex)

  initialize: () ->
    @speedCompete = compete(speedFormula, this)
    @hitCompete = compete(hitFormula, this)
    @criticalCompete = compete(criticalFormula, this)
    Object.defineProperty(this, 'speedCompete', {enumerable:false})
    Object.defineProperty(this, 'hitCompete', {enumerable:false})
    Object.defineProperty(this, 'criticalCompete', {enumerable:false})

    if @randSeed? then @changeSeed(@randSeed) else @changeSeed()

    cfg = @getConfig()

    @goldRate = cfg.goldRate ? 1
    @xpRate = cfg.xpRate ? 1
    @wxpRate = cfg.wxpRate ? 1
    @baseRank = 0 unless @baseRank?
    @baseRank = cfg.rank if cfg.rank
    if @infiniteLevel?
      @baseRank += calcInfiniteRank(@infiniteLevel, @formularId)
      infiniteLevel = @infiniteLevel
      if infiniteLevel % 10 is 0
        @goldRate *= 1.5
        @xpRate *= 1.5
      else if infiniteLevel % 5 is 0
        @goldRate *= 1.3
        @xpRate *= 1.3
      else
        @goldRate = 1.1
        @xpRate *= 1.1

    if @PVP_Pool
      cfg = JSON.parse(JSON.stringify(cfg))
      cfg.pool.PVP ={}
      cfg.pool.PVP.objects = @PVP_Pool.map((e) ->
        e.weight = 10
        e.id = e.cid
        return e
      )

    creation = createUnits(cfg, () => @rand())
    arrCollectID = []
    quests = if @quests? then @quests else []
    for qid, qst of quests
      q = queryTable(TABLE_QUEST, qid, @abIndex)
      arrCollectID.push(o.collect) for o in q.objects
    @unitCreation = creation.map(
      (level) ->
        return level.filter(
          (e) ->
            if e.questOnly
              return arrCollectID.indexOf(e.collectId) != -1
            else
              return true
        )
    )

    @initiateHeroes(@team)
    @nextLevel()
    @replayActionLog()

  initiateHeroes: (team) ->
    team = [] unless team
    ref = 0
    this.heroes = team.map((e) ->
      if not e.needMirror
        data = {
          name: e.nam,
          class: e.cid,
          gender: e.gen,
          hairStyle: e.hst,
          hairColor: e.hcl,
          equipment: e.itm,
          xp: e.exp,
          order: ref,
          ref :ref++
        }
        return new Hero(data)
      else
        e.order = ref
        e.ref = ref++
        new Mirror(e, 'teammate')
    )
    dummyHero = new Hero({})
    dummyHero.health =0
    this.heroes.push(dummyHero)
    this.heroes.forEach( (e) -> e.faction = 'hero' )
    thiz = @
    @cardStack.map((card) ->
      if card?.func?
        thiz.getDummyHero().installSpell(card.func,1))

  getDummyHero: () -> @heroes[@heroes.length-1]

  aquireCard: (id) ->
    card = new Card(id)
    @getDummyHero().installSpell(card.func, 1)
    return @cardStack.add(card, 1, true)
  
  costCard: (slot, count) -> return @cardStack.remove(null, count ? 1, slot)

  getCard: (slot) -> @cardStack.get(slot)

  getInitialInfo: () -> {syn: 0, pat: @team, stg: @stage}

  getHeroes: (withDummy) -> if withDummy then @heroes else @heroes.slice(0, @heroes.length-1)

  getAliveHeroes: () -> @getHeroes().filter( (hero) -> hero.isAlive())

  getMonsters: () -> @level?.getMonsters().filter( (o) -> o.isAlive())

  getEnemyOf: (obj) ->
    if obj.isMonster?()
      return @getHeroes()
    else if obj.isHero?()
      return @getMonsters()
    else
      return []

  getTeammateOf: (obj) ->
    return [] unless obj.isMonster?
    list = []
    if obj.isMonster()
      list = @getMonsters()
    else if obj.isHero()
      list = @getHeroes(true)
    return list.filter( (o) -> o.ref isnt obj.ref )

  getEntrance: () -> @level?.entrance

  getExit: () -> @level?.exit

  moveHeroes: (positions) ->
    for k, p of positions when @heroes[k]? and @level?.blocks[p]?
      obj = @heroes[k]
      @level.blocks[obj.pos]?.removeRef(obj)
      obj.pos = p
      @level.blocks[obj.pos]?.addRef(obj)

  explore: (tar) ->
    return ExploreResult_Explored if @level.blocks[tar].explored
    return ExploreResult_Entrance if tar is @getEntrance()
    return ExploreResult_Entrance if Array.isArray(@getEntrance()) and @getEntrance().indexOf(tar) isnt -1

    access = false
    for i in [0..3]
      nx = tar%DG_LEVELWIDTH
      ny = Math.floor(tar/DG_LEVELWIDTH)
      switch (i)
        when UP then ny--
        when RIGHT then nx++
        when DOWN then ny++
        when LEFT then nx--

      n = nx + ny*DG_LEVELWIDTH
      return ExploreResult_Entrance if @level.blocks[n]?.explored

    @onReplayMissMatch()
    return ExploreResult_DeadEnd

  getRank: () -> @level?.rank

  getUnitAtBlock: (block) -> @level.blocks[block].getRef(-1) if @level?.blocks[block]?

  doAction: (req) ->
    cmd = req?.CMD ? req?.CNF
    switch cmd
      when RPC_GameStartDungeon then action = DUNGEON_ACTION_ENTER_DUNGEON
      when Request_DungeonSpell
        action = DUNGEON_ACTION_CAST_SPELL
        req.arg ?= {}
        req.arg.idx ?= 0
        req.arg.pos ?= -1
        arg = {i:+req.arg.idx, p:req.arg.pos}
      when REQUEST_CancelDungeon then action = DUNGEON_ACTION_CANCEL_DUNGEON
      when Request_DungeonRevive then action = DUNGEON_ACTION_REVIVE
      when Request_DungeonCard
        action = DUNGEON_ACTION_USE_ITEM_SPELL
        arg = {s: +req.arg.slt}
      when Request_DungeonTouch
        action = DUNGEON_ACTION_TOUCHBLOCK
        arg = {b:+req.arg.tar, p:[+req.arg.pos, +req.arg.pos1, +req.arg.pos2]}
      when Request_DungeonExplore
        action = DUNGEON_ACTION_EXPLOREBLOCK
        arg = {b:+req.arg.tar, p:[+req.arg.pos, +req.arg.pos1, +req.arg.pos2]}
      when Request_DungeonActivate
        action = DUNGEON_ACTION_ACTIVATEMECHANISM
        arg = {t:+req.arg.tar}
      when Request_DungeonAttack
        action = DUNGEON_ACTION_ATTACK
        arg = {t: +req.arg.tar, p:[+req.arg.pos, +req.arg.pos1, +req.arg.pos2]}
      when Request_DungeonValidatePos
        action = DUNGEON_ACTION_GETVALIDATE_POS
        arg = {id: +req.arg.id}

    return @act(action, arg)

  act: (action, arg, replayMode = false, showResult = false, randNumber = 0) ->
    if replayMode
      r = @rand()
      if r isnt randNumber
        console.log('Unmatched rand number', action, arg, randNumber, r) unless randNumber is r
        return @onReplayMissMatch()
    else
      @actionLog[@currentLevel] = [] unless @actionLog[@currentLevel]?
      @actionLog[@currentLevel].push({a: action, g: arg, r: @rand()})
    ret = []

    aliveHeroes = @getAliveHeroes().filter( (h) -> return h? ).sort( (a,b) -> return a.order - b.order )
    hero = aliveHeroes[0] if aliveHeroes?.length > 0

    switch action
      when DUNGEON_ACTION_ENTER_DUNGEON
        ret.push({NTF:Event_DungeonEnter, arg:this.getInitialInfo()})
        cmd = DungeonCommandStream({id: 'EnterDungeon'}, this)
        cmd.next({id: 'ResultCheck'})
        cmd.process()
      when DUNGEON_ACTION_CANCEL_DUNGEON
        cmd = DungeonCommandStream({id: 'CancelDungeon'}, this)
        cmd.process()
      when DUNGEON_ACTION_USE_ITEM_SPELL
        cmd = DungeonCommandStream({id: 'BeginTurn', type: 'Item', src: hero}, this)
        cmd.next({id: 'UseItem', slot: arg.s})
           .next({id: 'EndTurn', type: 'Item', src: hero})
           .next({id: 'ResultCheck'})
        cmd.process()
      when DUNGEON_ACTION_CAST_SPELL
        hero = @heroes[0]
        ret = [] #[{NTF: Event_Fail, arg : {msg:'Main Hero Is Dead'}}]
        if hero.isAlive()
          cmd = DungeonCommandStream({id: 'BeginTurn', type: 'Spell', src: hero}, this)
          spellId = hero.activeSpell[arg.i]
          cmd.next({id: 'CastSpell', me: hero, spell: spellId, playerChoice: arg.p})
             .next({id: 'EndTurn', type: 'Spell', src: hero})
             .next({id: 'ResultCheck'})
          cmd.process()
      when DUNGEON_ACTION_TOUCHBLOCK
        cmd = DungeonCommandStream({id: 'TouchBlock', block: arg.b, positions: arg.p}, this)
        cmd.process()
      when DUNGEON_ACTION_ATTACK
        cmd = DungeonCommandStream({id: 'InitiateAttack', block: arg.t, positions: arg.p}, this)
        cmd.process()
      when DUNGEON_ACTION_ACTIVATEMECHANISM
        cmd = DungeonCommandStream({id: 'ActivateMechanism', block: arg.t, positions: arg.p}, this)
        cmd.next({id: 'EndTurn', type: 'Activate', src: hero})
        cmd.process()
      when DUNGEON_ACTION_EXPLOREBLOCK
        cmd = DungeonCommandStream({id: 'BeginTurn', type: 'Move', src: hero}, this)
        cmd.next({id: 'ExploreBlock', block: arg.b, positions: arg.p, src: hero})
           .next({id: 'EndTurn', type: 'Move', src: hero})
           .next({id: 'ResultCheck'})
        cmd.process()
      when DUNGEON_ACTION_REVIVE
        @revive++
        cmd = DungeonCommandStream({id: 'Revive'}, this)
        cmd.process()
      when DUNGEON_ACTION_GETVALIDATE_POS
        cmd = DungeonCommandStream({id: 'ValidatePosList', spell: arg.id}, this)
        cmd.process()
      else
        return @onReplayMissMatch()
    ret.push({NTF:Event_DungeonAction, arg: cmd.translate()}) unless not cmd or (replayMode and not showResult)
    return ret

  onReplayMissMatch: () ->
    if @replayMode then throw Error('ReplayFailed')

  replayActionLog: (actionLog) ->
    @replayMode = true
    actionLog = actionLog ? []
    @replayActions(actions) for actions in actionLog when actions?
    @replayMode = false
    @actionLog = actionLog

  replayActions: (actions) ->
    @act(a.a, a.g, true, true, a.r) for a in actions

  getActionLog: (level) -> if level? then @actionLog[level] else @actionLog

  nextLevel: () ->
    @currentLevel++

    cfg = @getConfig()
    if @currentLevel < cfg.levelCount
      lvConfig = cfg.levels[@currentLevel]
      @level = new Level()
      @level.rand = (r) => @rand(r)
      @level.random = (r) => @random(r)
      Object.defineProperty(@level, 'random', {enumerable:false})
      Object.defineProperty(@level, 'rand', {enumerable:false})
      @level.init(lvConfig, @baseRank, @getHeroes(), @unitCreation[@currentLevel])

exports.Dungeon = Dungeon
#////////////////////// Block
class Block extends Wizard
  constructor: () ->
    super
    @refList = []
    @passable = [false, false, false, false]
    @explored = false
    @tileType = Block_Empty
    @isBlock = true

  addRef: (obj) -> @refList.push(obj)

  removeRef: (obj) -> @refList = @refList.filter( (e) -> e.ref isnt obj.ref )

  getRef: (index) ->
    return @refList unless index?
    return @refList[index] unless index is -1
    objLst = (o for o in @refList when o.isAlive())

    return if objLst.length is 0 then null else objLst

  getType: () ->
    return @tileType if @tileType is Block_Exit or @tileType is Block_LockedExit or @getRef(-1) is null
    return @getRef(-1)[0].blockType if @getRef(-1)?[0]?

#///////////////////// Level
class Level
  constructor: () ->
    @objects = []
    @ref =  HEROTAG

  init: (lvConfig, baseRank, heroes, objectConfig) ->
    @objects = @objects.concat(heroes)
    @rank = baseRank
    @rank += lvConfig.rank if lvConfig.rank?
    @generateBlockLayout(lvConfig)
    @setupEnterAndExit(lvConfig)
    @placeMapObjects(objectConfig)

    return @entrance

  createBlocks: () ->
    @blocks = []
    i = 0
    @blocks.push(new Block()) until i++ >= DG_BLOCKCOUNT
    return @blocks

  generateBlockLayout: (config) ->
    blocks = @createBlocks()
    e.pos = +i for i, e of blocks
    if config?.layout?
      for k in [0..DG_BLOCKCOUNT-1]
        blocks[k].passable = [true, true, true, true]
        blocks[k].passable[UP] = false if config.layout[k] & 1
        blocks[k].passable[DOWN] = false if config.layout[k] & 2
        blocks[k].passable[LEFT] = false if config.layout[k] & 4
        blocks[k].passable[RIGHT] = false if config.layout[k] & 8
        blocks[k].explored = true if config.layout[k] & 16
    else
      # open holds id of blocks that about to be processed
      # close holds id of blocks that has been processed
      # when all blocks is in close, whole procedure is done
      open = []
      close = []
      openCount = 0
      closeCount = 0
      neighbor = []
      neighborCount = 0
      open[openCount++] = 1
      open[openCount++] = DG_LEVELWIDTH
      close[closeCount++] = 0
  
      while openCount != 0
        p = @rand(openCount)
        x = open[p]
        xx = x % DG_LEVELWIDTH
        xy = Math.floor(x / DG_LEVELWIDTH)
        neighborCount = 0
        for i in [0..3]
          nx = xx
          ny = xy
          switch (i)
            when UP then ny--
            when RIGHT then nx++
            when DOWN then ny++
            when LEFT then nx--

          if nx<0 or ny<0 or nx>=DG_LEVELWIDTH or ny>=DG_LEVELHEIGHT then continue
          n = nx + ny*DG_LEVELWIDTH
  
          ninclose = false
          for j in [0..closeCount-1]
            if close[j] is n
              ninclose = true
              break
          if ninclose
            neighbor[neighborCount++] = n
          else
            ninopen = false
            for j in [0..openCount-1]
              if open[j] == n
                ninopen = true
                break
            if !ninopen
              open[openCount++] = n
  
        z = neighbor[this.rand(neighborCount)]
        zx = z%DG_LEVELWIDTH
        zy = Math.floor(z/DG_LEVELWIDTH)
        if zx != xx
          if zx < xx
            blocks[z].passable[RIGHT] = true
            blocks[x].passable[LEFT] = true
          else
            blocks[z].passable[LEFT] = true
            blocks[x].passable[RIGHT] = true

        if zy != xy
          if zy < xy
            blocks[z].passable[DOWN] = true
            blocks[x].passable[UP] = true
          else
            blocks[z].passable[UP] = true
            blocks[x].passable[DOWN] = true

        close[closeCount++] = x
        if p != openCount-1 then open[p] = open[openCount-1]
        openCount--

  setupEnterAndExit: (config) ->
    @entrance = this.rand(DG_BLOCKCOUNT)
    @entrance = JSON.parse(JSON.stringify(config.entrance)) if config?.entrance?
    @exit = this.rand(DG_BLOCKCOUNT-1)
    @exit = DG_BLOCKCOUNT-1 if @exit is @entrance or (@entrance.indexOf? and @entrance.indexOf(@exit) isnt -1)
    @exit = config.exit if config?.exit?
    @blocks[@exit].tileType = Block_Exit if @blocks[@exit]?

  lockUp: (isLock) ->
    @blocks[@exit]?.tileType = if isLock then Block_LockedExit else Block_Exit

  createObject: (arg) ->
    cfg = {}
    for k, v of arg
      cfg[k] = v
    cfg.rank = @rank
    cfg.ref = @ref
    o = createUnit(cfg)

    if arg.skill?
      o.installSpell(skill.id,skill.lv) for skill in arg.skill

    if arg.property?.skill?
      o.installSpell(skill.id,skill.lv) for skill in arg.property.skill

    o.installSpell(DUNGEON_DROP_CARD_SPELL, 1)

    if arg.property?
      for k, v of arg.property
        o[k] = v

    @lockUp(true) if cfg.keyed
    o.collectId = cfg.collectId if cfg.collectId?
    o.effect = cfg.effect
    o.pos = cfg.pos
    @ref += 1
    @blocks[cfg.pos].addRef(o)
    @objects.push(o)
    return o

  placeObjects: (arg) ->
    count = arg.count ? 1
    indexes = (i for i in [0..DG_BLOCKCOUNT-1] when @blocks[i].getType() is Block_Empty)
    if Array.isArray(@entrance)
      indexes = (i for i in indexes when @entrance.indexOf(i) is -1)
    else
      indexes = (i for i in indexes when @entrance isnt i)

    return [] unless indexes.length > count
    for i in [1..count]
      pos = indexes.splice(@rand() % indexes.length, 1)[0]
      arg.pos = pos
      @createObject(arg)

  placeMapObjects: (cfg) ->
    return false unless cfg?
    for o in cfg
      if o.pos?
        @createObject(o)

    for o in cfg
      if not o.pos?
        @placeObjects(o)

  getMonsters: () -> @objects.filter( (e) -> e.isMonster() )

  print: () ->
    for y in [0..Dungeon_Height-1]
      up = []
      row = []
      for x in [ 0..Dungeon_Width-1 ]
        b = @blocks[ Dungeon_Width * y + x ]
        if Dungeon_Width * y + x  is @entrance or @entrance.indexOf? and @entrance.indexOf(Dungeon_Width * y + x) isnt -1
          row.push('E')
        else
          if b.explored || b.getType() is 1
            row.push(b.getType())
          else
            row.push(6)

        if b.passable[RIGHT]
          row.push(' ')
        else
          row.push('|')
        up.push(b.passable[UP])

      strUp = ' '
      for e in up
        if e
          strUp += '   '
        else
          strUp += '___'
 
        strUp += ' '

      console.log(strUp)
      str = '  '
      for i, e of row
        switch (e)
          when 0 then str += '  '
          when 1 then str += 'O '
          when 2 then str += 'X '
          when 3 then str += 'N '
          when 5 then str += 'D '
          when 10 then str += 'H '
          when 6
            str += y*Dungeon_Width+i/2
            if y*Dungeon_Width+i/2 < 10 then str+=' '
          else str += e+' '
      console.log(str)


class DungeonEnvironment extends Environment
  constructor: (@dungeon) ->

  installTrigger: (name) -> @dungeon.triggerManager.installTrigger(name)

  haveCard: (card) -> return @indexOfCard(card) != -1

  rand: () -> @dungeon.random()

  getVar:(key) ->
    switch key
      when 'currentLevel' then return @getCurrentLevel()
      else return undefined

  doAction: (act, variables, cmd) ->
    a = act
    switch a.type
      when 'dialog' then cmd.routine?({id: 'Dialog', dialogId: act.dialogId})
      when 'tutorial' then cmd.routine?({id: 'Tutorial', tutorialId: act.tutorialId})
      when 'modifyEnvVariable' then @variable(a.name, a.value)
      when 'shock' then cmd.routine?({id: 'Shock', time: a.time, delay: a.delay, range: a.range})
      when 'tremble' then cmd.routine?({id: 'Tremble', time: a.time, delay: a.delay, range: a.range})
      when 'blink' then cmd.routine?({id: 'Blink', time: a.time, delay: a.delay, color: a.color})
      when 'changeBGM' then cmd.routine({id: 'ChangeBGM', music: a.music, repeat: a.repeat})
      when 'whiteScreen' then cmd.routine({id: 'WhiteScreen', mode: a.mode, time: a.time, color: a.color})
      when 'playSound' then cmd.routine({id: 'SoundEffect', sound: a.sound})

  indexOfCard: (card) ->
    return -1 unless @dungeon?
    if typeof card == 'number'
      card = @dungeon.cardStack.filter((c) ->
        return c? and c.classId == card
      )[0]
    return @dungeon.cardStack.queryItemSlot(card)

  getTeammateOf: (wizard) -> @dungeon?.getTeammateOf(wizard)

  getEnemyOf: (wizard) -> @dungeon?.getEnemyOf(wizard)

  getCardStack: () -> if @dungeon? then @dungeon.cardStack.container else []

  getFactionConfig: (src, tar, flag) ->
    factionDB = @dungeon.factionDB
    return false unless factionDB? and factionDB[src]? and factionDB[src][tar]?
    if flag? then return factionDB[src][tar][flag]
    return factionDB[src][tar][flag]

  isLevelInitialized: () -> @dungeon.level.initialized
  levelInitialized: () -> @dungeon.level.initialized = true
  isEntranceExplored: () ->
    entrance = @dungeon.getEntrance()
    if Array.isArray(entrance)
      return false for e in entrance when not @dungeon.level.blocks[e].explored
      return true
    else
      return @dungeon?.level?.blocks[entrance].explored

  getAliveHeroes: () -> @dungeon?.getAliveHeroes()

  getHeroes: () -> @dungeon?.getHeroes()

  getMonsters: () -> @dungeon?.getMonsters()

  getObjects: () -> @dungeon?.level?.objects

  getBlock: (id) ->
    return [] unless @dungeon?.level?
    return @dungeon.level.blocks unless id?
    return @dungeon.level.blocks[id]

  initiateHeroes: (data) ->
    @dungeon.initiateHeroes(data)
    heroes = @dungeon.getAliveHeroes()
    objects = @dungeon.level.objects
    @dungeon.level.objects = heroes.concat(objects.slice(heroes.length, objects.length))

  incrReviveCount: () -> @dungeon?.reviveCount++

  getInitialData: () -> @dungeon?.getInitialData()

  getEntrance: () -> @dungeon?.getEntrance()

  getExit: () -> @dungeon?.getExit()

  lockUp: (flag) -> @dungeon?.level?.lockUp(flag)

  exploreBlock: (block) -> @dungeon?.explore(block)

  newFaction: (name) -> @dungeon.newFaction(name)
  factionAttack: (src, dst, flag) -> @dungeon.factionAttack(src, dst, flag)
  factionHeal: (src, dst, flag) -> @dungeon.factionHeal(src, dst, flag)

  getFirstObjectAtBlock: (block) -> return @getBlock(block).getRef(-1)?[0]

  getCurrentLevel: () -> return @dungeon?.currentLevel

  moveHeroes: (positions) -> @dungeon?.moveHeroes(positions)

  compete: (type, a, b) ->
    switch type
      when 'speed' then @dungeon.speedCompete(a, b)
      when 'hit' then @dungeon.hitCompete(a, b)
      when 'critical' then @dungeon.criticalCompete(a, b)

  incrEffectCount: () -> return @dungeon.effectCounter++
  aquireCard: (id) -> @dungeon?.aquireCard(id)
  costCard: (slot, count) -> @dungeon?.costCard(slot, count)
  getCard: (slot) -> @dungeon?.getCard(slot)
  getQuests: () -> @dungeon?.quests
  nextLevel: () -> @dungeon?.nextLevel()
  isDungeonFinished: () -> return @dungeon.currentLevel >= @dungeon.getConfig().levelCount
  createObject: (cfg) -> @dungeon?.level?.createObject(cfg)
  useItem: (spell, level, cmd) -> @dungeon.getDummyHero().castSpell(spell, cmd)
  getReviveCount: () -> @dungeon?.revive
  createSpellMsg: (actor, spell, delay) ->
    return [] unless actor? and spell?
    ret = []
    if spell.motion?
      ev = {id:ACT_SPELL, spl:spell.motion}
      if actor.isBlock then ev.pos = +actor.pos else ev.act = actor.ref
      ret.push(ev)

    if spell.effect?
      delay = delay
      delay += spell.delay if spell.delay?
      ev = {id:ACT_EFFECT, dey: delay, eff:spell.effect}
      if actor.isBlock then ev.pos = +actor.pos else ev.act = actor.ref
      if spell.dir? then ev.dir = spell.dir
      ret.push(ev)
    return ret

  notifyTurnEvent: (isBegin, turnType, src, tar, cmd) ->
    tailString = if isBegin then 'Begin' else 'End'
    allEvent = 'on'+turnType+'Turn'+tailString
    turnEvent = 'onTurn' + tailString
    for e in @getObjects().concat(@getBlock())
      e.onEvent(allEvent, cmd)
      e.onEvent(turnEvent, cmd)

    basicEvent = tailString+turnType+'Turn'
    onEvent(basicEvent, cmd, src, tar)

  onEvent: (event, cmd) -> @dungeon.onEvent(event, cmd)
  getFirstPace: (pace) ->
    pPace = []
    if Array.isArray(pace[0])
      pPace = pace.splice(0,1)[0]
    else if pace[0]?
      count = 0
      for i,p of pace
        if Array.isArray(p)
          count = 1
          break
        count++
      pPace = pace.splice(0, count)

    return pPace

  mergeFirstPace: (prev, next) ->
    #console.log('Try', prev, next)
    pPace = @getFirstPace(prev)
    nPace = @getFirstPace(next)

    #console.log('Subtract', pPace, nPace)

    nonInstant = (p.act for p in pPace when not isInstantAction(p.id) and p.act?)
    nextPace = []
    for i, p of nPace
      if not isInstantAction(p.id) and nonInstant.indexOf(p.act) isnt -1
        if p.id isnt ACT_HURT
          nextPace.push(p)
      else
        pPace.push(p)

    nPace = nextPace

    #console.log('Merged', pPace, nPace)

    ret = []
    if pPace.length > 1
      ret.push(pPace)
    else
      ret = ret.concat(pPace)
    ret = ret.concat(prev)
    if nPace.length > 1
      ret.push(nPace)
    else
      ret = ret.concat(nPace)
    ret = ret.concat(next)
    #console.log(ret)
    return ret

  pacelize: (pace) ->
    return pace if pace.length <= 1
    for p in pace when Array.isArray(p)
      return pace
    return [pace]

  translateDungeonAction: (cmd) ->
    return [] unless cmd?

    currentPace = cmd.output()
    currentPace = [] unless currentPace?

    for i, routine of cmd.cmdRoutine
      currentPace = @mergeFirstPace(currentPace, @translateDungeonAction(routine))

    return @pacelize(currentPace).concat(@translateDungeonAction(cmd.nextCMD))

  translate: (cmd) -> @translateDungeonAction(cmd)

DungeonCommandStream = (cmd, dungeon=null) ->
  env = new DungeonEnvironment(dungeon)
  cmdStream = new CommandStream(cmd, null, dungeonCSConfig, env)
  return cmdStream

################################### combat
genUnitInfo = (h, withBasicInfo=false, buffState = null) ->
  return null unless h?.ref?

  unitInfo = {id: ACT_UnitInfo, ref: h.ref}
  flag = false

  if buffState
    for k,state of buffState
      unitInfo[k] = state
      flag = true

  if withBasicInfo
    unitInfo.hp = h.health
    unitInfo.dc = h.attack
    unitInfo.od = h.order
    flag = true

  return if flag then unitInfo else null

dungeonCSConfig = {
  EnterDungeon: {
    callback:(env) ->
      @routine({id: 'EnterLevel'})
      @routine({id:'UpdateLockStatues'})
    ,
    output: (env) ->
      ev = []
      ev.push({id: ACT_DROPITEM, sid: env.indexOfCard(c), typ: c.id, cnt: c.count}) for c in env.getCardStack() when c?
      return ev
  },
  EnterLevel: {
    callback: (env) ->
      entrance = env.getEntrance()
      env.onEvent('onEnterLevel', @)
      if env.isLevelInitialized()
        @routine({id: 'OpenBlock', block: e}) for e in [0..DG_BLOCKCOUNT-1] when env.getBlock(e).explored
        @routine({id: 'SpellCD', cdInfo:h.getSpellCD()}) for h in env.getObjects() when h.isHero()
        
      else
        env.levelInitialized()
        if Array.isArray(entrance)
          if not env.isEntranceExplored()
            @routine({id: 'ExploreBlock', block: e, positions: entrance}) for e in entrance
          else
            @routine({id: 'OpenBlock', block: e}) for e in entrance
        else
          if not env.isEntranceExplored()
            @routine({id: 'ExploreBlock', block: entrance})
          else
            @routine({id: 'OpenBlock', block: entrance})

        if Array.isArray(entrance)
          newPosition = entrance
          for i in [newPosition.length..env.getHeroes().length-1]
            newPosition.push( entrance[0] )
        else
          newPosition = [entrance, entrance, entrance]
        env.moveHeroes(newPosition)

        o.onEvent('onEnterLevel', @) for o in env.getObjects()
        @routine({id: 'TickSpell'})


      heroInfo = env.getAliveHeroes()
                  .filter((e) -> e?.ref? )
                  .sort((a, b) -> return a.order-b.order)
                  .map( (h, index) ->
                    t = {}
                    for k, v of h
                      t[k] = v
                    t.order = index
                    return t
                  )
                  .map( (h) -> return genUnitInfo(h, true) )
                  .filter( (e) -> e? )
      env.variable('heroInfo', heroInfo)

    ,
    output: (env) ->
      ev = {id: ACT_EnterLevel, "lvl": env.getCurrentLevel()}
      positions = (h.pos for h in env.getHeroes())
      ev.pos = positions[0] if env.getHeroes()[0]?.isAlive()
      ev.pos1 = positions[1] if env.getHeroes()[1]?.isAlive()
      ev.pos2 = positions[2] if env.getHeroes()[2]?.isAlive()
      ev.pos3 = positions[3] if env.getHeroes()[3]?.isAlive()

      heroInfo = env.variable('heroInfo')

      ret = [ev]
      ret = ret.concat(heroInfo)
      return ret
  },
  ExploreBlock: {
    callback: (env) ->
      block = env.variable('block')
      res = env.exploreBlock(block)
      env.variable('exploreResult', res)
      if res == 1
        @routine({id: 'OpenBlock', block: block})
        positions = env.variable('positions') ? [block, block, block]
        env.moveHeroes(positions)
    ,
    output: (env) ->
      switch env.variable('exploreResult')
        when ExploreResult_DeadEnd then {id : ACT_POPTEXT, arg : 'Invalid move'}
        when ExploreResult_Explored then {id : ACT_POPTEXT, arg : 'Explored block'}
        else []
  },
  SpellCD: {
    output: (env) -> [ {id:ACT_SkillCD, cd:env.variable('cdInfo')} ] if env.variable('cdInfo')?
  },
  SpellState: {
    callback: (env) ->
      state = env.variable('wizard').calcBuffState()
      env.variable('state', state)
    output: (env) ->
      ret =  genUnitInfo(env.variable('wizard'), false, env.variable('state'))
      return [] unless ret?
      if env.variable('effect')?
        effect = env.variable('effect')
        if ret? then ret = [ret]
        bid = effect.id
        actor = env.variable('wizard')
        ev = {id:ACT_EFFECT, eff: bid}
        if effect.uninstall then ev.rmf = true
        ev.sid = if actor.isBlock then (actor.pos+1)*100+bid else (actor.ref+1)*1000+bid
        if actor.isBlock then ev.pos = +actor.pos else ev.act = actor.ref
        ret.push(ev)
      return ret
  },
  TickSpell: {
    callback: (env) -> h.tickSpell(env.variable('tickType'), @) for h in env.getObjects()
  },
  OpenBlock: {
    callback: (env) ->
      return @suicide() unless env.getBlock(env.variable('block'))?
      env.getBlock(env.variable('block')).explored = true
      @routine({id: 'BlockInfo', block: env.variable('block')})
      block = env.getBlock(env.variable('block'))
      aliveHeroes = env.getAliveHeroes().filter( (h) -> return h? ).sort( (a,b) -> return a.order - b.order )
 
      blockType = block.getType()
      if block.getType() is Block_Npc or block.getType() is Block_Enemy
        if block.getRef(-1) isnt null
          who = if blockType is Block_Npc then 'Npc' else 'Monster'
          for npc in block.getRef(-1)
            @routine({id: 'UnitInfo', unit: npc})
            env.variable('monster', npc)
            env.variable('tar', npc)
            npc.onEvent('onShow', @)
            for hero in aliveHeroes
              onEvent(who+'Show', this, hero,npc)
            env.onEvent('on'+who+'Show', @)
            if npc?.isVisible isnt true
              npc.isVisible = true
  },
  BlockInfo: {
    output: (env) ->
      pos = env.variable('block')
      block = env.getBlock(pos)
      blockEv = {id: ACT_Block, pos: +pos, typ: block.getType(), pas: ''}
      blockEv.trs = block.proxy if block.proxy?
      for passable in block.passable
        if passable
          blockEv.pas += '1'
        else
          blockEv.pas += '0'

      return [blockEv]
  },
  UnitInfo: {
    output: (env) ->
      e = env.variable('unit')
      return [] if e.dead
      eEv = {
        id: ACT_Enemy,
        pos: e.pos,
        rid: e.id,
        hp: e.health,
        ref: e.ref,
        typ: e.type,
        keyed: e.keyed}
      eEv.dc = e.attack if e.attack?
      eEv.eff = e.effect if e.effect?
      if getBasicInfo(e) then eEv.role = getBasicInfo(e)
      return [eEv]
  },
  TouchBlock: {
    callback: (env) ->
      env.onEvent('onTouchBlock', @)
      block = env.getBlock(env.variable('block'))
      if block.explored
        tar = env.getFirstObjectAtBlock(env.variable('block'))
        aliveHeroes = env.getAliveHeroes().filter( (h) -> return h? ).sort( (a,b) -> return a.order - b.order )
        hero = aliveHeroes[0] if aliveHeroes?.length > 0
        if tar? and hero?
          if env.getFactionConfig(hero.faction, tar.faction, 'attackable')
            @routine({id: 'InitiateAttack', src: hero, tar: enemy})
        else
          @routine({id: 'ActivateMechanism', block: env.variable('block')})
      else
        @routine({id: 'ExploreBlock', block: env.variable('block')})
  },
  InitiateAttack: {
    callback: (env) ->
      enemy = env.getFirstObjectAtBlock(env.variable('block'))
      aliveHeroes = env.getAliveHeroes().filter( (h) -> return h? ).sort( (a,b) -> return a.order - b.order )
      hero = aliveHeroes[0] if aliveHeroes?.length > 0

      return @suicide() unless enemy? and hero?
      env.moveHeroes(env.variable('positions')) if env.variable('positions')
      attackActions = [{attacker:hero, attackee:enemy}]
      if enemy.counterAttack
        if env.compete('speed', hero.speed, enemy.speed)
          attackActions.push({attacker:enemy, attackee:hero})
        else
          attackActions.splice(0, 0, {attacker:enemy, attackee:hero})

      hero.order += env.getHeroes().length

      cmd = @next({id: 'BeginTurn', type: 'Battle', src: hero, tar: enemy})
      cmd = cmd.next({id: 'Attack', tar:a.attackee, src:a.attacker}) for a in attackActions
      cmd = cmd.next({id: 'EndTurn', type: 'Battle', src: hero, tar: enemy})
      cmd = cmd.next({id: 'ShiftOrder'}) if aliveHeroes?.length > 1
      cmd.next({id: 'ResultCheck'})
  },
  BeginTurn: {
    callback: (env) ->
      env.notifyTurnEvent(true, env.variable('type'), env.variable('src'), env.variable('tar'), @)
      @routine({id:'TickSpell', tickType: env.variable('type')})
  },
  EndTurn: {
    callback: (env) ->
      env.notifyTurnEvent(false, env.variable('type'), env.variable('src'), env.variable('tar'), @)
      @routine({id:'UpdateLockStatues'})
  },
  Attack: {
    callback: (env) ->
      src = env.variable('src')
      tar = env.variable('tar')
      return @suicide() unless src.isAlive() and tar.isAlive() and src.isVisible and tar.isVisible

      env.variable('damage', src.attack)
      onEvent('Target', @, src, tar)
      env.variable('hit', env.compete('hit', src.accuracy, tar.reactivity))
      onEvent('Hit', @, env.variable('src'), env.variable('tar'))

      if env.variable('hit')
        @routine({
          id:'Damage',
          ignoreHurt: env.variable('ignoreHurt'),
          src: env.variable('src'),
          tar: env.variable('tar'),
          damage: env.variable('damage'),
          damageType: 'Physical',
          hurtDelay: env.variable('hurtDelay'),
          hpDelay: env.variable('hpDelay'),
          isRange:env.variable('isRange')
        })
      else
        @routine({id:'Evade', src:tar, tar: src})
    ,
    output: (env) ->
      if env.variable('isRange')  and env.variable('eff')?
        src = env.variable('src')
        tar = env.variable('tar')
        rangeEff = [{
          id: ACT_RangeAttackEffect,
          dey:env.variable('effDelay'),
          eff:env.variable('eff'),
          src:{act: src.ref, pos: src.pos},
          tar:{act: tar.ref, pos: tar.pos} }]
      else
        rangeEff =[]

      if env.variable('hit')
        flag = HP_RESULT_TYPE_HIT
        if env.variable('critical')
          flag = HP_RESULT_TYPE_CRITICAL
      else
        flag = HP_RESULT_TYPE_MISS
      if env.variable('ignoreAttack')
        return [].concat(rangeEff)
      else
        return [{act: env.variable('src').ref, id: ACT_ATTACK, ref: env.variable('tar').ref, res:flag, rng:env.variable('isRange')}].concat(rangeEff)
  },
  ShiftOrder: {
    output: (env) -> [{id:ACT_SHIFTORDER}]
  },
  CancelDungeon: {
    callback: (env) -> @routine({id: 'ClaimResult', win: DUNGEON_RESULT_FAIL})
  },
  ClaimResult: {
    callback: (env) ->
      env.onEvent('onClaimResult', @)
      env.dungeon.result = env.variable('win')
    ,
    output: (env) -> [{id: ACT_DungeonResult, win: env.variable('win')}]
  },
  AllHeroAreDead: {
    output: (env) -> [{id: ACT_AllHeroAreDead, cnt: env.getReviveCount()}]
  },
  Revive: {
    callback: (env) ->
      env.initiateHeroes(env.getInitialData().team)
      env.incrReviveCount()
      for p in env.getAliveHeroes()
        p.pos = env.getEntrance()[0] ? env.getEntrance()
    ,
    output: (env) ->
      ret = ({id: ACT_Enemy, pos: p.pos, rid: p.class, hp: p.health, dc: p.attack, ref: p.ref, typ: Unit_Hero} for p in env.getAliveHeroes())
      ret.push({id:ACT_SkillCD, cd: 0})
      return ret
  },
  ResultCheck: {
    callback: (env) ->
      win = env.isDungeonFinished()
      if win
        @routine({id: 'CollectID', collectId: env.dungeon.getConfig().collectId}) if env.dungeon.getConfig().collectId
        @routine({id: 'ClaimResult', win: DUNGEON_RESULT_WIN})

      if env.getAliveHeroes().length <= 0
        @routine({id: 'AllHeroAreDead'})
  },
  ShowExit: {
    callback: (env) -> @routine({id: 'OpenBlock', block:env.getExit()})
  },
  Delay: {
    output: (env) -> if env.variable('delay') then [{id: ACT_Delay, tim: env.variable('delay')}] else []
  },
  SoundEffect: {
    output: (env) -> [{id: ACT_PlaySound, sod: env.variable('sound')}]
  },
  SpellAction: {
    output: (env) -> [{id: ACT_SPELL, spl: env.variable('motion'), act: env.variable('ref')}]
  },
  Blink: {
    output: (env) ->
      evt = {id: ACT_Blink, dey: env.variable('delay'), tim: env.variable('time')}
      evt.col = env.variable('color') if env.variable('color')?
      return [evt]
  },
  Shock: {
    output: (env) ->
      evt = {id: ACT_Shock, dey: env.variable('delay'), tim: env.variable('time')}
      evt.rag = env.variable('range') if env.variable('range')?
      return [evt]
  },
  Tremble: {
    output: (env) ->
      evt = {id: ACT_Tremble, act:env.variable('act'), dey: env.variable('delay'), tim: env.variable('time')}
      evt.rag = env.variable('range') if env.variable('range')?
      return [evt]
  },
  Dialog: { output: (env) -> [{id: ACT_Dialog, did: env.variable('dialogId')}] },
  Tutorial: { output: (env) -> [{id: ACT_Tutorial, tid: env.variable('tutorialId')}] },
  ChangeBGM: {
    output: (env) ->
      evt = {id: ACT_ChangeBGM}
      evt.mus = env.variable('music') if env.variable('music')?
      evt.rep = env.variable('repeat') if env.variable('repeat')?
      [evt]
  },
  ChainBlock: {
    callback: (env) ->
      src = env.getBlock(env.variable('src'))
      src.proxy = env.variable('tar') if src?
      if env.getBlock(env.variable('src')).explored
        @routine({id: 'BlockInfo', block: env.variable('src')})
  },
  EndDungeon: {
    callback: (env) -> @routine({id: 'ClaimResult', win: env.variable('result')})
  },
  WhiteScreen: {
    output: (env) -> [{id: ACT_WhiteScreen, mod: env.variable('mode'), tim: env.variable('time'), col: env.variable('color')}]
  },
  Kill: {
    callback: (env) ->
      return @suicide() unless env.variable('tar').isAlive()
      env.variable('tar').health = 0
      if not env.variable('tar').isVisible then env.variable('tar').dead = true
      @routine({id:'Dead', tar: env.variable('tar'), cod: env.variable('cod')})
  },
  ShowUp: {
    callback: (env) ->
      tar = env.variable('tar')
      tar.isVisible = true
      @routine({id: 'OpenBlock', block:tar.pos})
  },
  Hide: {
    callback: (env) -> @routine({id: 'TeleportObject', hiding: true, obj:env.variable('obj')})
  },
  TeleportObject: {
    callback: (env) ->
      obj = env.variable('obj')
      return @suicide() unless obj.isAlive()
      slot = env.variable('tarPos')
      isHiding = env.variable('hiding')
      if not slot?
        availableSlot = env.getBlock().filter( (e) -> e.getType() is Block_Empty )
        if isHiding
          hidePlace = availableSlot.filter( (e) -> not e.explored )
          if hidePlace.length > 0
            availableSlot = hidePlace
            obj.isVisible = false
          else
            env.variable('hiding', false)
            isHiding = false

        slot = env.randMember(availableSlot)
        slot = slot.pos if slot?
      return @suicide() unless slot?

      env.variable('orgPos', obj.pos)
      env.variable('tarPos', slot)
      if not isHiding
        env.getBlock(slot).explored = true
      env.getBlock(obj.pos).removeRef(obj)
      env.getBlock(slot).addRef(obj)
      obj.pos = slot
      return @suicide() unless env.variable('obj').isAlive()
      if not  isHiding
        @routine({id: 'BlockInfo', block: env.variable('tarPos')})
    ,
    output: (env) -> [{act: env.variable('obj').ref, id: ACT_TELEPORT, pos: env.variable('tarPos'), hide:env.variable('hiding')}]
  },
  DropPrize: {
    callback: (env) ->
      dropID = env.variable('dropID')
      dropID = env.variable('me').dropPrize unless dropID?
      showPrize = env.variable('showPrize')
      if dropID?
        if showPrize
          drop = generateReward(queryTable(TABLE_DROP),[dropID], () -> env.rand())
          if drop[0].type is 1
            env.variable('cid', -1)
          else
            env.variable('cid', drop[0].value)
          env.dungeon.prizeInfo = env.dungeon.prizeInfo.concat(drop)
        else
          env.dungeon.killingInfo.push( { dropInfo: dropID } )

    output: (env) -> [{id:  ACT_DropItem, eff: env.variable('effect'), spl: env.variable('motion'), act: env.variable('ref'), cid: env.variable('cid'),pos: env.variable('pos')}] if env.variable('cid')?
  },
  DropItem: {
    callback: (env) ->
      dropList = env.variable('list')
      card = selectElementFromWeightArray(dropList, env.rand())
      ret = env.aquireCard(card.item)

      return @suicide() unless ret.length > 0

      ret = ret[0]
      env.variable('slot', ret.slot)
      env.variable('type', ret.id)
      env.variable('count', ret.count)
    ,
    output: (env) -> [{ id: ACT_DROPITEM, sid: +env.variable('slot'), typ: env.variable('type'), cnt: env.variable('count') }]
  },
  Casting: {
    output: (env) ->
      src = env.variable('caster')
      tar = env.variable('castee')
      spell = env.variable('spell')
      delay = env.variable('delay')
      dir = env.variable('effdirlst')
      ret = env.createSpellMsg(src, { motion : spell.spellAction, delay : spell.spellDelay, effect : spell.spellEffect }, delay) if spell? and src?

      if tar?
        info = { motion : spell.targetAction, delay : spell.targetDelay, effect : spell.targetEffect }
        for t,idx in tar
          info.dir = dir[idx] if dir?[idx]?
          ret = ret.concat(env.createSpellMsg(t, info, delay))
      
      return ret
  },
  Effect: {
    output: (env) ->
      if env.variable('pos')?
        result = {id:ACT_EFFECT, dey: env.variable('delay'), eff: env.variable('effect'), pos: env.variable('pos')}
      else
        result = {id:ACT_EFFECT, dey: env.variable('delay'), eff: env.variable('effect'), act: env.variable('act')}
      #console.log('Effect', env.variable('effdir'))
      if env.variable('effdir')?
        result.dir = env.variable('effdir')
      [result]
  },
  CastSpell: {
    callback: (env) ->
      env.variable('me').castSpell(env.variable('spell'), @)
  },
  UseItem: {
    callback: (env) ->
      card = env.getCard(env.variable('slot'))
      env.useItem(card.func, 1, @) if card?
  },
  Resurrect: {
    callback: (env) -> t.health = Math.ceil(t.maxHP * 0.2) for t in env.variable('tar') when t.maxHP ,
    output: (env) -> ({ id: ACT_UnitInfo, ref: t.ref, hp:  t.health } for t in env.variable('tar'))
  },
  CostCard: {
    callback: (env) ->
      slot = env.variable('slot')
      card = env.variable('card')
      if env.variable('randCost')
        indexes = env.getCardStack()
                     .map( (c, i) -> return if c? then i else -1 )
                     .filter( (i) -> i!=-1 )
        slot = env.randMember(indexes)
      else if card?
        slot = i for i, c of env.getCardStack() when c?.classId == card

      return @suicide() unless env.getCard(slot)?

      env.variable('costCard', true)
      h.onEvent('onCostCard', @) for h in env.getHeroes()
      return @suicide() unless env.variable('costCard')

      ret = env.costCard(slot, 1)
      return @suicide() unless ret?.length > 0

      ret = ret[0]
      env.variable('slot', ret.slot)
      env.variable('type', ret.id)
      env.variable('count', ret.count)
    ,
    output: (env) -> [{ id: ACT_DROPITEM, sid: +env.variable('slot'), typ: env.variable('type'), cnt: env.variable('count') }]
  },
  CreateObject: {
    callback: (env) ->
      pos = env.variable('pos')
      if not pos?
        availableSlot = env.getBlock().filter( (e) -> e.getType() is Block_Empty )
        count = 1
        count = env.variable('count') if env.variable('count')?
        pos = env.randMember(availableSlot, count)
        pos = [pos] unless Array.isArray(pos)
        pos = (p.pos for p in pos)
      pos = [pos] unless Array.isArray(pos)
      env.variable('pos', pos)
      env.createObject({ id: env.variable('classID'), pos: p, keyed: env.variable('withKey'), collectId: env.variable('collectID'), effect: env.variable('effect')}) for p in pos
      env.getBlock(p).explored = true for p in pos
      env.getBlock(p).effect = env.variable('effect') for p in pos
      for p in env.variable('pos')
        @routine({id: 'OpenBlock', block: p})
  },
  Heal: {
    callback: (env) ->
      hp = env.variable('hp')
      return @suicide() unless hp? and hp > 0
      onEvent('Heal', @, env.variable('src'), env.variable('tar'))
      env.variable('tar').health += env.variable('hp')
    ,
    output: (env) ->
      [{act: env.variable('tar').ref, id: ACT_POPHP, num: env.variable('hp'), flg: HP_RESULT_TYPE_HEAL, dey: env.variable('delay') ? 0.3}]
  },
  Damage: {
    callback: (env) ->
      damageType = env.variable('damageType')
      isRange = env.variable('isRange')

      return @suicide() unless env.variable('tar')?.isAlive()

      env.variable('critical', env.compete('critical', env.variable('src').critical, env.variable('tar').strong)) if damageType is 'Physical'
      env.variable('damage', env.variable('damage')*2) if env.variable('critical')

      if isRange
        onEvent(damageType+'RangeDamage', @, env.variable('src'), env.variable('tar'))
      else
        onEvent(damageType+'Damage', @, env.variable('src'), env.variable('tar'))

      if env.variable('tar').health <= env.variable('damage')
        onEvent('DeathStrike', @, env.variable('src'), env.variable('tar'))
      env.variable('tar').health -= env.variable('damage')

      onEvent('CriticalDamage', @, env.variable('src'), env.variable('tar')) if env.variable('critical')
      @next({id: 'Dead', tar: env.variable('tar'), killer:env.variable('src'), damage: env.variable('damage')}) unless env.variable('tar').isAlive()

      @getPrevCommand('Attack')?.cmd?.critical = env.variable('critical')
      @getPrevCommand('Attack')?.cmd?.ignoreAttack = env.variable('ignoreAttack')
    ,
    output: (env) ->
      flag = if env.variable('critical') then HP_RESULT_TYPE_CRITICAL else HP_RESULT_TYPE_HIT
      damage = Math.ceil(env.variable('damage'))
      ret = []

      if damage > 0
        delay = 0.3
        delay = env.variable('hurtDelay') if env.variable('hurtDelay')
        delay = env.variable('delay') if env.variable('delay')
        ret.push({act:env.variable('tar').ref, id: ACT_HURT, dey:delay}) unless env.variable('ignoreHurt')
        ret.push({act:env.variable('tar').ref, id: ACT_POPHP, num:damage, flg:flag, dey:delay})

      return ret
  },
  UpdateLockStatues: {
    callback: (env) ->
      keys = env.getObjects()
                .filter( (m) -> return m.isAlive())
                .filter( (m) -> return m.keyed? and m.keyed )
      exit = env.getBlock(env.getExit())
      oldStatues = exit.getType() if exit?
      env.lockUp(keys.length != 0)

      return @suicide() unless exit? and oldStatues != exit.getType() and exit.explored
      @routine({id: 'BlockInfo', block: env.getExit()})
  },
  CollectID: {
    callback: (env) ->
      collectId = env.variable('collectId')

      questInfo = []
      for qid, quest of env.getQuests()
        continue unless quest?.counters?
        for i, objective of queryTable(TABLE_QUEST, qid, @abIndex).objects
          continue unless objective.type is QUEST_TYPE_NPC and objective.collect == collectId
          continue unless quest.counters[i]?
          quest.counters[i] += 1
          if quest.counters[i] > objective.count
            quest.counters[i] = objective.count
          else
            questInfo.push(packQuestEvent(env.getQuests(), qid))

      env.variable('questInfo', questInfo)
    ,
    output: (env) -> ({id:ACT_Event, event: e} for e in env.variable('questInfo'))
  },
  Dead: {
    callback: (env) ->
      killer = env.variable('killer')
      src = env.variable('tar')

      if src.collectId? then @routine({id: 'CollectID', collectId: src.collectId})

      onEvent('Kill', @, killer, src)
      env.getBlock(src.pos).removeRef(src) if env.getBlock(src.pos) and not src.isAlive()

      if not env.variable('tar').isAlive() and not env.variable('cod')? and env.variable('tar').dropInfo
        env.dungeon.killingInfo.push( { dropInfo: env.variable('tar').dropInfo } )

      @routine({id: 'BlockInfo', block: src.pos}) if src.isVisible
    ,
    output: (env) ->
      ret = []
      if env.variable('tar').isVisible and not env.variable('tar').isAlive()
        ret.push({act: env.variable('tar').ref, id: ACT_DEAD})
      return ret
  },
  Evade: {
    callback: (env) -> onEvent('Dodge', @, env.variable('src'), env.variable('tar'))
    output: (env) -> return [{act: env.variable('src').ref, id: ACT_EVADE, dey: 0}] # TODO:delay
  },
  ActivateMechanism: {
    callback: (env) ->
      block = env.getBlock(env.variable('block'))
      return @suicide() unless block.explored

      switch block.getType()
        when Block_Exit
          env.nextLevel()
          if env.isDungeonFinished()
            @routine({id:'ResultCheck'})
          else
            @routine({id:'EnterLevel'})
        when Block_Npc
          npc.onEvent('onBeActivate', this) for npc in block.getRef(-1)
  },
  RangeAttackEffect: {
    output: (env) ->
      src = env.variable('src')
      tar = env.variable('tar')
      return [{
        id: ACT_RangeAttackEffect,
        dey:env.variable('dey'),
        eff:env.variable('eff'),
        src:{act: src.ref, pos: src.pos},
        tar:tar.map((e) -> return {act: e.ref, pos: e.pos}) }]  if src? and tar?
  },
  ShowBubble: {
    output: (env) ->
      if env.variable('pos')?
        [{
          id:ACT_Bubble,
          pos:env.variable('pos'),
          eff:env.variable('eff'),
          typ:env.variable('typ'),
          cont:env.variable('cont'),
          dey:env.variable('dey'),
          dur:env.variable('dur')
        }]
      else
        [{
          id:ACT_Bubble,
          act:env.variable('act'),
          eff:env.variable('eff'),
          typ:env.variable('typ'),
          cont:env.variable('cont'),
          dey:env.variable('dey'),
          dur:env.variable('dur')
        }]
  },
  ValidatePosList: {
    output: (env) ->
      ret = env.variable('me').getValidatePlayerSelectPoint(env.variable('spell'), env)
      [{id:ACT_ShowValidatePosLst, ret:ret}]

  }
}

#////////////////////////////////// callBack
onEvent = (evt, cmd, src, tar) ->
  env = cmd.getEnvironment()
  env.variable('src', src)
  env.variable('tar', tar)
  if src
    src.onEvent('on'+evt, cmd)
    m.onEvent('onTeammate'+evt, cmd) for m in env.getTeammateOf(src)

  if tar
    tar.onEvent('onBe'+evt, cmd)
    m.onEvent('onTeammateBe'+evt, cmd) for m in env.getTeammateOf(tar)
  env.onEvent(evt, cmd)

exports.DungeonEnvironment = DungeonEnvironment
exports.DungeonCommandStream = DungeonCommandStream
exports.fileVersion = -1
