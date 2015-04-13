moment = require('moment')

class Shop
  @ersion = 0
  @tock = []

  addProduct: (index, product)->
    return unless product? and index?
    @stock[index] = product
    @version += 1

  removeProduct: (index)->
    delete @stock[index]
    @version += 1

  sellProduct: (index, count, version, player)->
    return RET_ShopVersionNotMatch unless @version is version
    return RET_PlayerInfoError unless player?
    if not count? or count < 0
      count = 1
    p = @stock[index]

    if (p.limit?)
      if (p.limit.vip? and p.limit.vip > player.vipLevel())
        return RET_VipLevelIsLow
      if (p.limit.count?)
        if (p.limit.count <= player.getPurchasedCount(p.id))
          return RET_SoldOut
        else if (count > p.limit.count)
          count = p.limit.count

      dateLimit = p.limit.date
      if (dateLimit?)
        nowTime = moment()
        if (not (nowTime.diff(moment(dateLimit.begin)) >0 and nowTime.diff(moment(dateLimit.end)) < 0))
          return RET_SoldOut

    cost = p.price.amount*count
    if (not player.addMoney(p.price.type, -(cost)))
      if (p.price.type is 'gold') return RET_NotEnoughGold
      if (p.price.type is 'diamond') return RET_NotEnoughDiamond
   

    logUser({
      name : player.name,
      action : 'buy',
      product : 'shop',
      index : index,
      item : p.id,
      count : count,
      payMethod: p.price.type,
      cost : cost
    })

    if (p.count?)
      count *= p.count

    ret = player.aquireItem(p.id, count, true)
    if (ret? and ret.length > 0)
      if (p.limit)  player.addPurchasedCount(p.id, count)
      return ret.concat(NTF: Event_InventoryUpdateItem, arg:god:player.gold, dim:player.diamond)
     else
      player.addMoney(p.price.type, cost)
      return RET_InventoryFull
   
 

  dump :(player) ->
     items = gShop.stock.filter(function (p)
          #if (p.limit and p.limit.vip not = null and p.limit.vip > player.vipLevel()) return false
          return true
        )
      .map(function (p, index)
       ret =
        sid : index,
        cid : p.id
     
      if (p.count) ret.cnt = p.count
      if (p.price)
        ret.cost =
        if (p.price.type is 'gold') ret.cost.gold = p.price.amount
        if (p.price.type is 'diamond') ret.cost.diamond = p.price.amount
     
      if(p.limit and p.limit.date)
          ret.date = p.limit.date
     
      return ret
    )

     categories = gShop.stock.reduce(function (r, l, cid)
      if (l.category)
        l.category.forEach(function (c)
          if (c)
            if (r[c.id] == null) r[c.id] = []
            r[c.id].push(cid)
         
          return r
        )
     
      return r
    , [])

    if (items.length <= 0)
      logError(type:'emptyShopList', stock: gShop.stock)
   

    return items : items, categories : categories, version : @version
 

  #--------------------------------------------------------------------------#

  sell :(customer, index, count, version) ->
       ret =
      if( @version not == version )
          ret.error =
              message: 'Version miss match',
              data:
                  source: @version,
                  remote: version
             
         
          return ret
     
      if( customer == null ) throw new Error('Missing customer')
      if( index == null ) throw new Error('Missing index')
      if( count == null or count < 0 ) count = 1

       good = @goods[index]
      if( not good ) throw new Error('Missing good')

      if( good.limit )
          if (good.limit.vip not = null and good.limit.vip > customer.vipLevel())
              ret.error =
                  message: 'Insufficient vip level',
                  data:
                      index: index,
                      level: good.limit.vip
                 
             
              return ret
         

          if( good.limit.date not = null )
               dateLimit = good.limit.date
               nowTime = moment()
              if (not ( nowTime.diff(moment(dateLimit.begin))>0 and nowTime.diff(moment(dateLimit.end))<0 ))
                  ret.error =
                      message: 'sold out',
                      data:
                          index: index
                     
                 
                  return ret
             
         

          if( good.limit.count not = null )
              if( good.limit.count <= 0 )
                  ret.error =
                      message: 'sold out',
                      data:
                          index: index
                     
                 
                  return ret
             
              if( good.limit.count < count )
                  count = good.limit.count
             
         
     

       cost = good.price * count
      if( customer.addMoney(@currency, -cost) is false )
          ret.error =
              message: 'Insufficient money',
              data:
                  index: 0,
                  currency: @currency,
                  amount: cost
             
         
          return ret
     

       itemCount = good.count * count
      ret.ret = []
      ret.ret = customer.aquireItem(good.id, itemCount, true)
      if( not (ret.ret and ret.ret.length > 0) )
          customer.addMoney(@currency, cost)
          ret.error =
              message: 'Inventory full'
         
          return ret
     
      ret.ret.push(NTF: Event_InventoryUpdateItem, arg:god:customer.gold, dim:customer.diamond, mst:customer.masterCoin)

      if( good.limit and good.limit.count not = null )
          good.limit.count -= count
          @version += 1
          ret.version = @version
     

      ret.result =
          good: id:good.id, count:count, price:good.price
     

      return ret
 

  dump2: () ->
       crc = @currency
       goods = @goods.filter(function (p)
          #if (p.limit and p.limit.vip not = null and p.limit.vip > player.vipLevel()) return false
          return true
      ).map(function (p, index)
           ret =
              idx : index,
              cid : p.id,
              cnt : p.count
         
          ret.cost =
          ret.cost[crc] = p.price
          if(p.limit and p.limit.date)
              ret.date = p.limit.date
         
          return ret
      )

      if (goods.length <= 0)
          logError(type:'emptyShopList', goods: @goods)
     

      return
          goods: goods,
          version: @version,
          currency: @currency,
          resetTime: @resetTime,
          refCost: @refreshCurrentCost,
          refTimes: @refreshTimes
     
 

   createShop = function(config, shop, refresh)
      if( not config ) throw new Error('Missing Config')
      if( not config.type ) throw new Error('Missing Type')
      if( not config.currency ) throw new Error('Missing currency')
      if( not config.goods ) throw new Error('Missing goods')

      if( shop == null )
          shop = new Shop()
      else
          if( refresh )
              shop.refreshTimes = (shop.refreshTimes or 0) + 1
         
          shop.version = (shop.version or 0) + 1
     

      shop.goods = []
      for(  index in config.goods )
           cfg_good = config.goods[index]
           good =
          switch (config.type)
              case 'fixed':
                  break
              case 'random':
                  if( Array.isArray(cfg_good))
                      cfg_good = selectElementFromWeightArray(cfg_good, Math.random())
                 
                  break
              default :

         
          if( not cfg_good.id ) throw new Error('Missing id')
          good.id = cfg_good.id
          if( not cfg_good.price ) throw new Error('Missing price')
          good.count = cfg_good.count or 1
          good.price = cfg_good.price
          if(cfg_good.limit) good.limit = deepCopy(cfg_good.limit)

          shop.goods.push(good)
     

      shop.type = config.type
      shop.currency = config.currency

      if( config.resetTime )
           nowTime = moment()
          if( nowTime.hour() < config.resetTime.hour or
              (nowTime.hour() == config.resetTime.hour and nowTime.minute() < config.resetTime.minute) )
              nowTime.subtract(1, 'day')
         
          nowTime.hour(config.resetTime.hour or 0)
          nowTime.minute(config.resetTime.minute or 0)
          nowTime.second(0)
          shop.resetTime = config.resetTime
          shop.createTime = nowTime.format()
     

      # refreshBasicCost:currency:'diamond', price:50
      shop.refreshBasicCost = deepCopy(config.refreshBasicCost)

       REFRESH_FACTOR = 0.5
      shop.refreshCurrentCost = deepCopy(config.refreshBasicCost)
      shop.refreshCurrentCost.price = Math.floor(shop.refreshBasicCost.price * ( 1 + (shop.refreshTimes or 0) * REFRESH_FACTOR ))

      return shop
 

exports.createShop = createShop
exports.Shop = Shop

gShop = new Shop()
