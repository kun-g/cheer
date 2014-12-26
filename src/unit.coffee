"use strict"
require('./define')
{Wizard} = require('./spell')
_ = require('./underscore')
makeBasicCommand = require('./commandStream').makeCommand
# =============================================================

flagCreation = false

class Unit extends Wizard
  constructor: () ->
    super
    @isVisible = false
    @unitProperty = {}
    @unitAppearance = {}
    @skill = []
    @uniform = {}

  calculatePower: () ->
    ret = @health + @attack*6 + @speed*2 + @critical*2 + @strong*2 + @reactivity*2 + @accuracy*2
    return if ret then ret else 0

  getActiveSpell: () ->
    roleConfig = queryTable(TABLE_ROLE, @class) if @class?
    return -1 unless roleConfig?.property?.activeSpell?
    return roleConfig.property.activeSpell

  levelUp: () ->
    roleConfig = queryTable(TABLE_ROLE, @class) if @class?
    return false unless roleConfig?.levelId?
    lvConfig = queryTable(TABLE_LEVEL, roleConfig.levelId)
    cfg = lvConfig.levelData

    while cfg[@level]?.xp <= @xp
      data = cfg[@level]
      @modifyProperty(data.property)
      if data.skill?
        for s in data.skill when not s.classLimit? or s.classLimit is @class
          @installSpell(s.id, s.level)
      @level += 1
      console.log('LevelUp ', JSON.stringify(data.property)) if flagCreation

  initWithConfig: (roleConfig) ->
    @roleID = roleConfig.classId
    return false unless roleConfig?
    @type = Unit_Boss if roleConfig.bossFlag
    @collectId = roleConfig.collectId if roleConfig.collectId?
    @modifyProperty(roleConfig.property) if roleConfig.property?
    @faction = roleConfig.faction
    @dropInfo = roleConfig.dropInfo
    if flagCreation
      console.log('Property ', JSON.stringify(roleConfig.property))

    if roleConfig.xproperty? and @rank? > 0
      @health = Math.ceil(@health*@rank)
      @attack = Math.ceil(@attack*@rank)
      xproperty = {}
      for k,v of roleConfig.xproperty
        xproperty[k] = Math.ceil(v*@rank)
      @modifyProperty(xproperty)
      console.log('xRank ', @rank) if flagCreation
      console.log('xProperty ', JSON.stringify(xproperty)) if flagCreation

    @installSpell(s.id, s.level) for s in roleConfig.skill if roleConfig.skill?

  modifyProperty: (properties) ->
    return false unless properties?
    for k, v of properties
      if this[k]?
        this[k] += v
      else
        this[k] = v
    
  gearUp: () ->
    return false unless @equipment?
    for k, e of @equipment when e
      @modifyProperty(e.property()) if e.property?
      if e.skill?
        for s in e.skill when not s.classLimit? or s.classLimit is @class
          @installSpell(s.id, s.level)

      console.log('Equipment ', JSON.stringify(e)) if flagCreation
      if e.eh?
        for enhancement in e.eh
          enhance = queryTable(TABLE_ENHANCE, enhancement.id)
          continue unless enhance?.property?[enhancement.level]?
          @modifyProperty(enhance.property[enhancement.level])
          if flagCreation
            console.log('Enhancement ',
              JSON.stringify(enhance.property[enhancement.level])
            )

  modifyAppearance: (appearance) ->
    return false unless appearance?
    this.appearance ?= {}
    for k, v of appearance
      this.appearance[k] = v

  subProperty: (properties) ->
    return false unless properties?
    for k, v of properties
      if this[k]?
        this[k] -= v

  gearOn: () ->
    return false unless @uniform?
    for k, e of @uniform when e
      @modifyProperty(e.basic_properties) if e.basic_properties?
      @modifyAppearance(e.appearance) if e.appearance?
      if e.skill?
        for s in e.skill when not s.classLimit? or s.classLimit is @class
          @installSpell(s.id, s.level)

      console.log('Equipment ', JSON.stringify(e)) if flagCreation
      if e.eh?
        for enhancement in e.eh
          enhance = queryTable(TABLE_ENHANCE, enhancement.id)
          continue unless enhance?.property?[enhancement.level]?
          @modifyProperty(enhance.property[enhancement.level])
          if flagCreation
            console.log('Enhancement ',
              JSON.stringify(enhance.property[enhancement.level])
            )

  gearDown: () ->
    return false unless @uniform?
    for k, e of @uniform when e
      @subProperty(e.basic_properties) if e.basic_properties?
      if e.skill?
        for s in e.skill when not s.classLimit? or s.classLimit is @class
          @removeSpell(s.id, s.level)

      console.log('Equipment ', JSON.stringify(e)) if flagCreation
      if e.eh?
        for enhancement in e.eh
          enhance = queryTable(TABLE_ENHANCE, enhancement.id)
          continue unless enhance?.property?[enhancement.level]?
          @subProperty(enhance.property[enhancement.level])
          if flagCreation
            console.log('Enhancement ',
              JSON.stringify(enhance.property[enhancement.level])
            )

    return false unless @unitProperty?
    for k, v of @unitProperty
      if this[k]?
        this[k] -= v
    return false unless @unitAppearance?
    for k, v of @unitAppearance
      if v?
        this.appearance[k] = v

  clearUnitPro: () ->
    return false unless @unitProperty?
    for k of @unitProperty
      @unitProperty[k] = 0
    return false unless @unitAppearance?
    for k of @unitAppearance
      @unitAppearance[k] = null
    @skill=[]

  addUnitPro: (unitPro) ->
    return false unless unitPro?
    for q, u of unitPro
      switch u.type
        when 'incress_property'
          for k, v of u.property
            if @unitProperty[k]?
              @unitProperty[k] += v
            else
              @unitProperty[k] = v
        when 'change_appearance'
          for k, v of u.appearance
            @unitAppearance[k] = this.appearance[k]
            this.appearance[k] = v
        when 'install_skill'
          @skill.push({id: u.id, level: u.level})

  caculateUnitPro: () ->
    return false unless @uniform?
    suitArr = {}
    for k, e of @uniform when e
      if e.suit_config?.suitId?
        if suitArr[e.suit_config.suitId]?
          suitArr[e.suit_config.suitId].count++
        else
          suitArr[e.suit_config.suitId] = e.suit_config
          suitArr[e.suit_config.suitId].count = 1

    @clearUnitPro()
    for k, v of suitArr
      for l, s of v
        if isNaN(parseInt(l, 10)) == false and parseInt(l, 10) <= v.count
          @addUnitPro(s)

    for k, v of @unitProperty
      if this[k]?
        this[k] += v
      else
        this[k] = v

  equip: (equipItem) ->
    @gearDown()
    @uniform[equipItem.getConfig().subcategory] = equipItem
    @gearOn()
    @caculateUnitPro()

  isMonster: () -> false
  isHero: () -> false
  getCommandConfig: (commandName) -> return unit_command_config[commandName]

installCommandExtention = require('./commandStream').installCommandExtention
installCommandExtention(Unit)

unit_command_config = {
}
# =============================================================
class Hero extends Unit
  constructor: (heroData) ->
    super
    return false unless heroData?

    @type = Unit_Hero
    @blockType = Block_Hero

    @isVisible = true
    this[k] = v for k, v of heroData
    @xp = 0 unless @xp?
    @equipment = [] unless @equipment?
    {createItem} = require('./item')
    @equipment = @equipment.map((e) -> createItem({id: e.cid, enhancement: e.eh}))
    

    @initialize()

  initialize: () ->
    cfg = queryTable(TABLE_ROLE, @class) if @class?
    @initWithConfig(cfg) if cfg?
    @level = 0
    @levelUp()
    @gearUp()
    if not @isAlive() then @health = 1
    if @attack <= 0 then @attack = 1
    @maxHP = @health
    @originAttack = @attack
    console.log('Hero ', JSON.stringify(@)) if flagCreation

  isHero: () -> true

class Mirror extends Unit
  constructor: (heroData) ->
    super
    return false unless heroData?

    @type = Unit_Mirror
    @blockType = Block_Enemy

    @isVisible = false
    @keyed = true

    @initialize(heroData)

  initialize: (heroData) ->
    hero = new Hero({
      name: heroData.nam,
      class: heroData.cid,
      gender: heroData.gen,
      hairStyle: heroData.hst,
      hairColor: heroData.hcl,
      equipment: heroData.itm,
      xp: heroData.exp,
    })
    battleForce = hero.calculatePower()

    cfg = queryTable(TABLE_ROLE, heroData.cid)
    cid = cfg.transId
    cfg = queryTable(TABLE_ROLE, cfg.transId)
    @initWithConfig(cfg) if cfg?
    @class = cid
    @level = 0
    @xp = heroData.exp
    @levelUp()

    @counterAttack = true
    @health = Math.ceil(battleForce * (6/18.5))
    @attack = Math.ceil(battleForce * (0.3/18.5))
    @critical = battleForce * (1/18.5)
    @strong = battleForce * (1/18.5)
    @accuracy = battleForce * (1/18.5) + 30
    @reactivity = battleForce * (1/18.5) - 60
    @speed = battleForce * (1/18.5) + 20
    @maxHP = @health
    @equipment = heroData.itm
    @name = heroData.nam
    @gender = heroData.gen
    @hairStyle = heroData.hst
    @hairColor = heroData.hcl
    @ref = heroData.ref
    @id = cid
    @originAttack = @attack

class Monster extends Unit
  constructor: (data) ->
    super
    return false unless data?

    @type = Unit_Enemy
    @blockType = Block_Enemy
    this[k] = v for k,v of data

    @initialize()

  isMonster: () -> true

  initialize: () ->
    cfg = queryTable(TABLE_ROLE, @id) if @id?
    @initWithConfig(cfg) if cfg?
    @maxHP = @health

    console.log('Monster ', JSON.stringify(@)) if flagCreation

class Npc extends Unit
  constructor: (data) ->
    super
    return false unless data?

    @type = Unit_NPC
    @blockType = Block_Npc
    this[k] = v for k,v of data

    @initialize()

  isMonster: () -> false

  initialize: () ->
    cfg = queryTable(TABLE_ROLE, @id) if @id?
    @initWithConfig(cfg) if cfg?

createUnit = (config) ->
  cfg = queryTable(TABLE_ROLE, config.id) if config?.id?
  throw Error('No such an unit:'+config?.id + ' cfg: '+ config) unless cfg?

  switch cfg.classType
    when Unit_Enemy then return new Monster(config)
    when Unit_NPC then return new Npc(config)
    when Unit_Hero then return new Mirror(config)

exports.createUnit = createUnit
exports.Hero = Hero
exports.Unit = Unit
exports.fileVersion = -1
