require('./define')
{Serializer, registerConstructor, objectlize} = require './serializer'

STACK_TYPE_SINGLE_STACK = 1
STACK_TYPE_MULTIPLE_STACK = 2
 
class Bag extends Serializer
  constructor: (data) ->
    cfg = {
      container: [],
      limit: 0,
      type: 0,
      stackType: 0
    }
    super(data, cfg, {})


  validate: () ->
    @container.map( (item, index) =>
      return null unless item?
      if not item.id? or not item.getConfig()?
        logInfo({action: 'clearSlot', index: index})
        @removeItemAt(index)
      if item.count <= 0
        item.count = 1
        logInfo({action: 'fixCount', index: index})
      if @queryItemSlot(item) isnt index
        logInfo({action: 'fixSlot', index: index, origin: @queryItemSlot(item)})
        item.slot[@type] = index
      return item
    )
  getMaxLength: () -> @container.reduce( ((r, l) ->
    if l and l.spaceCount() is 0 then return r+1
    return r
  ),
  @limit )

  countSpace: () -> @container.reduce( ((r, l) ->
    if l then return r - l.spaceCount()
    return r
  ),
  @limit )

  add: (item, count, allOrFail) ->
    return false unless item?
    ret = []
  
    try
      if Array.isArray(item)
        for e in item
          tmp = @add(e.item, e.count, allOrFail)
          throw 'No can do' unless tmp
          ret = ret.concat(tmp)
      else
        bag = this.container
        stack = item.stack
        sameSlot = []
        emptySlot = []
        if not count then count = 1
        if not stack then stack = 1
        for i, e of bag
          if e?
            if e.id is item.id then sameSlot.push(+i)
          else
            emptySlot.push(+i)
  
        if @container.length < @getMaxLength()
          for i in [@container.length..@getMaxLength()-1]
            emptySlot.push(i)
        else if item.spaceCount() is 0
          for i in [@container.length..@container.length+count]
            emptySlot.push(i)

        if @stackType is STACK_TYPE_SINGLE_STACK
          if sameSlot.length > 0
            emptySlot = []
          else if emptySlot.length > 0
            emptySlot = [emptySlot[0]]
  
        slots = sameSlot.filter((s) -> bag[s].count < stack).concat(emptySlot)

        left = count
        for e in slots when left > 0
          eCount = 0
          tmpCount = 0
          if bag[e]
            eCount = bag[e].count
            tmpCount = if left > stack-eCount then stack else left+eCount
          else
            tmpCount = if left > stack then stack else left
            if count is 1
              bag[e] = item
            else
              constructor = item.getConstructor()
              tmp = new constructor(item.dump().save)
              bag[e] = tmp

          bag[e].count = tmpCount
          left -= (tmpCount-eCount)
          bag[e].slot[this.type] = e
          ret.push({
            slot: e,
            id: item.id,
            oldAmount: eCount,
            count: bag[e].count,
            delta: bag[e].count-eCount,
            bagType: this.type,
            opration: 'add'
          })
        if left > 0
          if allOrFail
            throw 'No can do'
          else
            ret = [{left: left}]
    catch err
      if err is 'No can do'
        @reverseOpration(ret)
        return false

    return ret

  #/* id   count   slot
  # * null null    null  -> nop
  # * null null    s     -> delete all item in slot s
  # * null n       null  -> nop
  # * null n       s     -> delete n items from slot s 
  # * i    null    null  -> delete all items which id matches i
  # * i    null    s     -> delete all items in slot s if the id matches i
  # * i    n       null  -> delete n items which id matches i
  # * i    n       s     -> delete n items which id matches i, slot s must be included
  # */
  removeById: (id, count, allOrFail) -> @remove(id, count, null, allOrFail)
  removeItemAt: (slot, count, allOrFail) -> @remove(null, count, slot, allOrFail)
  remove: (id, count, slot, allOrFail) ->
    return [] unless id? or slot?
  
    ret = []
  
    try
      if Array.isArray(id)
        for e in id
          tmp = @remove(e.item, e.count, null, allOrFail)
          throw 'No can do' unless tmp
          ret = ret.concat(tmp)
      else
        if id? and typeof id is 'object'
          slot = this.queryItemSlot(id)
          id = id.id
        
        that = this
        bag = @container
        sameSlot = []
  
        if bag[slot] and (not id? or id is bag[slot].id) then sameSlot.push(bag[slot])

        if id? then sameSlot.push(item) for i, item of @container when item? and item.id is id and @queryItemSlot(item) isnt slot
        
        amount = 0
        ret = sameSlot.reduce( ((res, e, s) ->
          if not count? or count > amount
            tmpCount = if (count and amount+e.count>count) then count-amount else e.count
            amount += tmpCount
            e.count -= tmpCount
            if e.count <= 0 then bag[that.queryItemSlot(e)] = null
            return res.concat({
              slot: that.queryItemSlot(e),
              id: e.id,
              oldAmount: e.count+tmpCount,
              count : e.count,
              item : e,
              bagType : that.type,
              opration : 'remove'
            })

          return res
        ), [])
  
        if count and amount < count
          throw 'No can do' if allOrFail
          ret.left = count - amount
    catch err
      if err is 'No can do'
        this.reverseOpration(ret)
        return false
      else
        logError({action: 'containerAdd', err:err.stack})
    return ret

  size: (size) ->
    if size?
      this.limit += size
    return this.limit
  
  get: (slot) -> this.container[slot]
  
  queryItemSlot: (item) ->
    if item?
      return item.slot[this.type]
    return -1
  
  reverseOpration: (ret) ->
    bag = this.container
    that = this
    ret.forEach((e) ->
      if e.opration is 'add'
        that.remove(null, e.delta, e.slot, false)
      else
        bag[e.slot] = e.item
        bag[e.slot].count = e.oldAmount
    )
  
  map: (func) -> this.container.map(func)
  filter: (func) -> this.container.filter(func)
  
CONTAINER_TYPE_BAG = 0
CONTAINER_TYPE_CARD_STACK = 1
CONTAINER_TYPE_FURANCE = 2

CardStack = (count) ->
  bag = new Bag({
    type: CONTAINER_TYPE_CARD_STACK,
    limit: count,
    stackType: STACK_TYPE_SINGLE_STACK
  })
  return bag

PlayerBag = (count) ->
  bag = new Bag({
    type: CONTAINER_TYPE_BAG,
    limit: count,
    stackType: STACK_TYPE_MULTIPLE_STACK
  })
  return bag

exports.Bag = PlayerBag
exports.CardStack = CardStack

registerConstructor(Bag)
exports.fileVersion = -1
