require('./define')
{Serializer, registerConstructor} = require './serializer'

class Item extends Serializer
  constructor: (id) ->
    super
    @attrSave('slot', [])
    @attrSave('count', 1)
    if id? and typeof id is 'object' then id = id.id
    @attrSave('id', id) if id?
    @initialize() if @id?

  getConfig: () -> queryTable(TABLE_ITEM, @id)

  spaceCount: () ->
    if @storeOnly then return 0
    return 1

  initialize: () ->
    @restore(@getConfig()) if @id?
    @attrSave('id', @id) if @id?
    @attrSave('xp', 0) if @category is ITEM_EQUIPMENT and not @xp?
    @attrSave('enhancement', []) if @category is ITEM_EQUIPMENT and not @enhancement?

class Card extends Item
  constructor: (id) -> super id

  getConfig: () -> queryTable(TABLE_CARD, @id)

registerConstructor(Card)
registerConstructor(Item)

exports.Item = Item
exports.Card = Card
exports.fileVersion = -1
