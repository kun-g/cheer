require('./define')
{Serializer, registerConstructor} = require './serializer'

class Item extends Serializer
  constructor: (data) ->
    if typeof data is 'number' then data = {id: data}
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
exports.fileVersion = -1
