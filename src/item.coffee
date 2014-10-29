require('./define')
{Serializer, registerConstructor} = require './serializer'
_ = require('./underscore')
makeBasicCommand = require('./commandStream').makeCommand
# =============================================================
item_command_config = {
}
class Item extends Serializer
  constructor: (@config, additionalConfig) ->
    cfg = {
      slot: [],
      count: 1,
      serverId: -1, #For Client
      id: config.classId
    }
    if @config.expiration then savingCfg.date = -1
    super(config, _.extend(cfg, additionalConfig))
#TODO:the 907
    if @config.id is 907
      console.log("The 907 is comming")
      showMeTheStack()
    Object.defineProperty(this, 'config', {enumerable:false, writable: false})

  spaceCount: () -> if @storeOnly then return 0 else return 1

  command_config: item_command_config


installCommandExtention = require('./commandStream').installCommandExtention
installCommandExtention(Item)
# =============================================================
ENHANCE_TYPE_STONE = 0
ENHANCE_TYPE_ITEM = 1

equipment_command_config = {
  install_enhancement: {
    description: '安装一个强化',
    parameters: {
      enhancement: '强化数组',
      scheduled: '是否需要计时'
    }
  },
  incress_property: {
    description: '提升装备属性',
    parameters: {
        property: '属性'
    },

    execute: (parameter) ->
      parameter.obj = parameter.obj.property()
      @cmd_incressProperty = makeBasicCommand('incress_property')
      @cmd_incressProperty.execute(parameter)

    undo: (obj, properties) -> @cmd_incressProperty.undo()
  }
  install_skill: {
    description: '给装备安装技能',
    parameters: {
        id: '技能id',
        level: '等级*'
    },
    execute: (parameter) ->
      parameter.obj.skill = [] unless parameter.obj.skill
      parameter.obj.skill.push(_(parameter).pick('id', 'level'))
  }
  update_appearance: {
    execute: (parameter) ->
      config = parameter.obj.config
      parameter.obj._appearance = config.effecta

      if parameter.gender?
        if parameter.gender and config.effectm
          parameter.obj._appearance = config.effectm
        else if config.effectf
          parameter.obj._appearance = config.effectf
  },
  change_appearance: {
    execute: (parameter) ->
      _(parameter.obj._appearance).extend(parameter.appearance)
  }
}

class Equipment extends Item
  command_config: equipment_command_config

  constructor: (@config) ->
    savingCfg = {xp: 0, enhancement: [], status: 0}
    super(config, savingCfg)
    @_property = {}
    _.extend(@_property, config.basic_properties) if config.basic_properties
    @_appearance = { }

  property: (key, val) ->
    return @_property unless key?

    @_property[key] = val if val?

    return @_property[key]

  appearance: () -> return @_appearance

  deleteProperty: (key) -> delete @_property[key]

  installEnhancement: (enhancementItem) ->
    cfg = {type: ENHANCE_TYPE_ITEM, id: enhancementItem.getInitialData()}
    #TODO:if enhancementItem.expiration then cfg.timestamp = libTime.currentTime()
    @enhancement.push(cfg)
    @executeCommand(enhancementItem.command)

  equipUpgradeXp: () ->
    return -1 unless @upgradeTarget
    return @upgradeXp if @upgradeXp
    cfg = queryTable(TABLE_UPGRADE, @rank)
    return -1 unless cfg
    return cfg.xp

# =============================================================
class Enhance_Stone extends Item
  constructor: (@config) ->
    super(config)

  getCommandConfig: (commandName) -> return enhance_stone_command_config[commandName]

enhance_stone_command_config = {
}
# =============================================================
item_type_config = [
  { category: -1, constructor: Item },
  { category: 1, constructor: Equipment },
  { category: 5, constructor: Enhance_Stone },
]
initConstructors = (config, defaultConstructor) ->
  indexer = {}
  config.forEach((e) -> indexer[e.category] = e.constructor)

  return (data) ->
    if typeof data is 'number'
      id = data
      data = queryTable(TABLE_ITEM, id)
    else if data.id?
      id = data.id
      data = _(data).extend(queryTable(TABLE_ITEM, id))

    if indexer[data.category]
      return new indexer[data.category](data)
    else
      return new defaultConstructor(data)
# ============================================================
class Card extends Item
  constructor: (@id) -> super queryTable(TABLE_CARD, @id)

exports.Card = Card
exports.Enhance_Stone = Enhance_Stone
exports.createItem = initConstructors(item_type_config, Item)

for k, v of item_type_config
  registerConstructor(exports.createItem, v.constructor.name)

exports.fileVersion = -1
