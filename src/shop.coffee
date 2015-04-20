moment = require('moment')
{Serializer, registerConstructor} = require('./serializer')

class Shop extends Serializer
  constructor: () ->
    @version = 0
    @stock = []

  addProduct: (index, product) ->
    return unless product? and index?
    @stock[index] = product
    @version += 1

  removeProduct: (index) ->
    delete @stock[index]
    @version += 1

  sellProduct: (index, count, version, player) ->
    return RET_ShopVersionNotMatch unless @version is version
    return RET_PlayerInfoError unless player?
    unless count? and count >= 0
      count = 1
    p = @stock[index]
    if p.limit?
      if p.limit.vip? and p.limit.vip > player.vipLevel()
        return RET_VipLevelIsLow
      if p.limit.count?
        if p.limit.count <= player.getPurchasedCount(p.id)
          return RET_SoldOut
        else if count > p.limit.count
          count = p.limit.count
      dateLimit = p.limit.date
      if dateLimit?
        nowTime = moment()
        if not (nowTime.diff(moment(dateLimit.begin)) > 0 and nowTime.diff(moment(dateLimit.end)) < 0)
          return RET_SoldOut
    cost = p.price.amount * count
    if p.price and not player.addMoney(p.price.type, -cost)
      if p.price.type is 'gold'
        return RET_NotEnoughGold
      if p.price.type is 'diamond'
        return RET_NotEnoughDiamond
    logUser
      name: player.name
      action: 'buy'
      product: 'shop'
      index: index
      item: p.id
      count: count
      payMethod: p.price.type
      cost: cost
    if p.count?
      count *= p.count
    ret = player.aquireItem(p.id, count, true)
    if ret? and ret.length > 0
      if p.limit?
        player.addPurchasedCount p.id, count
      ret.concat
        NTF: Event_InventoryUpdateItem
        arg:
          god: player.gold
          dim: player.diamond
    else
      player.addMoney p.price.type, cost
      RET_InventoryFull

  dump: (player) ->
    items = gShop.stock.filter((p) ->
      #if (p.limit && p.limit.vip? && p.limit.vip > player.vipLevel()) return false;
      true
    ).map((p, index) ->
      ret =
        sid: index
        cid: p.id
      if p.count
        ret.cnt = p.count
      if p.price
        ret.cost = {}
        if p.price.type is 'gold'
          ret.cost.gold = p.price.amount
        if p.price.type is 'diamond'
          ret.cost.diamond = p.price.amount
      if p.limit and p.limit.date
        ret.date = p.limit.date
      ret
    )
    categories = gShop.stock.reduce(((r, l, cid) ->
      if l.category
        l.category.forEach (c) ->
          if c?
            r[c.id] ?= []
            r[c.id].push cid
          r
      r
    ), [])
    if items.length <= 0
      logError
        type: 'emptyShopList'
        stock: gShop.stock
    {
      items: items
      categories: categories
      version: @version
    }

#--------------------------------------------------------------------------//

  sell: (customer, index, count, version) ->
    ret = {}
    if @version isnt version
      ret.error =
        message: 'Version miss match'
        data:
          source: @version
          remote: version
      return ret
    throw new Error('Missing customer') unless customer?
    throw new Error('Missing index') unless index?
    count = 1 unless count? and count >= 0
    good = @goods[index]
    throw new Error('Missing good') unless good?
    if good.limit?
      if good.limit.vip? and good.limit.vip > customer.vipLevel()
        ret.error =
          message: 'Insufficient vip level'
          data:
            index: index
            level: good.limit.vip
        return ret
      if good.limit.date?
        dateLimit = good.limit.date
        nowTime = moment()
        unless (nowTime.diff(moment(dateLimit.begin)) > 0 and nowTime.diff(moment(dateLimit.end)) < 0)
          ret.error =
            message: 'sold out'
            data: index: index
          return ret
      if good.limit.count?
        if good.limit.count <= 0
          ret.error =
            message: 'sold out'
            data: index: index
          return ret
        if good.limit.count < count
          count = good.limit.count
    cost = good.price * count
    if customer.addMoney(@currency, -cost) is false
      ret.error =
        message: 'Insufficient money'
        data:
          index: 0
          currency: @currency
          amount: cost
      return ret
    itemCount = good.count * count
    ret.ret = []
    ret.ret = customer.aquireItem(good.id, itemCount, true)
    unless (ret.ret and ret.ret.length > 0)
      customer.addMoney @currency, cost
      ret.error = message: 'Inventory full'
      return ret
    ret.ret.push
      NTF: Event_InventoryUpdateItem
      arg:
        god: customer.gold
        dim: customer.diamond
        mst: customer.masterCoin
    if good.limit and good.limit.count?
      good.limit.count -= count
      @version += 1
      ret.version = @version
    ret.result = good:
      id: good.id
      count: count
      price: good.price
    ret

  dump2: ->
    crc = @currency
    goods = @goods.filter((p) ->
      #if (p.limit && p.limit.vip? && p.limit.vip > player.vipLevel()) return false;
      true
    ).map((p, index) ->
      ret =
        idx: index
        cid: p.id
        cnt: p.count
      ret.cost = {}
      ret.cost[crc] = p.price
      if p.limit and p.limit.date
        ret.date = p.limit.date
      ret
    )
    if goods.length <= 0
      logError
        type: 'emptyShopList'
        goods: @goods
    {
      goods: goods
      version: @version
      currency: @currency
      resetTime: @resetTime
      refCost: @refreshCurrentCost
      refTimes: @refreshTimes
    }

createShop = (config, shop, refresh) ->
  unless config?
    throw new Error('Missing Config')
  unless config.type?
    throw new Error('Missing Type')
  unless config.currency?
    throw new Error('Missing currency')
  unless config.goods?
    throw new Error('Missing goods')
  if not shop?
    shop = new Shop
  else
    if refresh
      shop.refreshTimes = (shop.refreshTimes or 0) + 1
    shop.version = (shop.version or 0) + 1
  shop.goods = []
  for index of config.goods
    cfg_good = config.goods[index]
    good = {}
    switch config.type
      when 'fixed'
        break
      when 'random'
        if Array.isArray(cfg_good)
          cfg_good = selectElementFromWeightArray(cfg_good, Math.random())
    unless cfg_good.id?
      throw new Error('Missing id')
    good.id = cfg_good.id
    unless cfg_good.price?
      throw new Error('Missing price')
    good.count = cfg_good.count or 1
    good.price = cfg_good.price
    if cfg_good.limit
      good.limit = deepCopy(cfg_good.limit)
    shop.goods.push good
  shop.type = config.type
  shop.currency = config.currency
  if config.resetTime
    nowTime = moment()
    if nowTime.hour() < config.resetTime.hour or nowTime.hour() is config.resetTime.hour and nowTime.minute() < config.resetTime.minute
      nowTime.subtract 1, 'day'
    nowTime.hour config.resetTime.hour or 0
    nowTime.minute config.resetTime.minute or 0
    nowTime.second 0
    shop.resetTime = config.resetTime
    shop.createTime = nowTime.format()
  # refreshBasicCost:{currency:'diamond', price:50}
  shop.refreshBasicCost = deepCopy(config.refreshBasicCost)
  REFRESH_FACTOR = 0.5
  shop.refreshCurrentCost = deepCopy(config.refreshBasicCost)
  shop.refreshCurrentCost.price = Math.floor(shop.refreshBasicCost.price * (1 + (shop.refreshTimes or 0) * REFRESH_FACTOR))
  shop

exports.createShop = createShop
exports.Shop = Shop
root = exports ? @
root.gShop = new Shop()
