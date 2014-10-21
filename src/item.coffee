require('./define')
{Serializer, registerConstructor} = require './serializer'
_ = require('./underscore')

class Thing extends Serializer
  constructor: (@config) ->
    _.extend(@property, config.property) if config.property
    _.extend(@enhancement, config.enhancement) if config.enhancement

    #super(config, config.serialize_config)

class Item extends Serializer
  constructor: (data) ->
    if typeof data is 'number' then data = {id: data}
#TODO:the 907
    if data.id is 907
      console.log("The 907 is comming")
      showMeTheStack()
    cfg = {
      slot: [],
      count: 1,
      id: data.id
    }

    @id = data.id
    if @getConfig()
      if @getConfig().category is ITEM_EQUIPMENT
        cfg.xp = 0
        cfg.enhancement = []
      if @getConfig().expiration then cfg.date = -1

    super(data, cfg, {})
    @initialize() if @id?

  getConfig: () -> queryTable(TABLE_ITEM, @id)

  spaceCount: () ->
    if @storeOnly then return 0
    return 1

  initialize: () ->
    @restore(JSON.parse(JSON.stringify(@getConfig()))) if @id?

class Card extends Item
  constructor: (id) -> super id

  getConfig: () -> queryTable(TABLE_CARD, @id)

registerConstructor(Card)
registerConstructor(Item)

exports.Item = Item
exports.Card = Card
exports.Thing = Thing
exports.fileVersion = -1
