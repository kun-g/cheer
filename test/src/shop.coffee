require 'should'
libShop = require('../js/shop')

selectElementFromWeightArray = (array, randNumber) ->
  if !array
    logError
      action: 'selectElementFromWeightArray'
      reason: 'emptyArray'
    return null
  total = array.reduce(((r, l) ->
    r + l.weight
  ), 0)
  if randNumber < 1
    randNumber *= total
  randNumber = Math.ceil(Math.abs(randNumber % total))
  for k of array
    if randNumber <= array[k].weight
      if !array[k]
        logError
          action: 'selectElementFromWeightArray'
          reason: 'emptyArray1'
      return array[k]
    randNumber -= array[k].weight
  logError
    action: 'selectElementFromWeightArray'
    reason: 'emptyArray2'
  null

deepCopy = (obj) ->
  if typeof obj == 'object'
    ret = {}
    if Array.isArray(obj)
      ret = []
    for k of obj
      `k = k`
      v = obj[k]
      ret[k] = deepCopy(v)
    ret
  else
    obj

describe 'Shop', ->
  it 'fixed shop', ->
    shop_config = 
      type: 'fixed'
      currency: 'gold'
      goods: [
        {
          id: 1
          count: 1
          price: 20
          limit: count: 5
        }
        {
          id: 2
          count: 1
          price: 20
        }
        {
          id: 3
          count: 1
          price: 20
          limit: vip: 5
        }
      ]
    libShop.createShop(shop_config).goods.should.eql [
      {
        id: 1
        count: 1
        price: 20
        limit: count: 5
      }
      {
        id: 2
        count: 1
        price: 20
      }
      {
        id: 3
        count: 1
        price: 20
        limit: vip: 5
      }
    ]
    return
  it 'random shop', ->
    shop_config = 
      type: 'random'
      currency: 'diamond'
      goods: [
        [
          {
            weight: 1
            id: 1
            price: 10
          }
          {
            weight: 1
            id: 2
            price: 1
          }
        ]
        [ {
          weight: 1
          id: 3
          price: 10
        } ]
      ]
    goods = libShop.createShop(shop_config).goods
    if goods.length != 2 or goods[0].id != 1 and goods[0].id != 2
      true.should.equal false
    return
  it 'none-optional parameters', ->
    (->
      libShop.createShop {}
      return
    ).should.throw 'Missing Type'
    (->
      libShop.createShop type: 'fixed'
      return
    ).should.throw 'Missing currency'
    (->
      libShop.createShop
        type: 'fixed'
        currency: 'gold'
      return
    ).should.throw 'Missing goods'
    (->
      libShop.createShop
        type: 'fixed'
        currency: 'gold'
        goods: [ { id: 1 } ]
      return
    ).should.throw 'Missing price'
    return
  it 'optional parameters', ->
    libShop.createShop(
      type: 'fixed'
      currency: 'gold'
      goods: [ {
        id: 1
        price: 10
      } ]).goods.should.eql [ {
      id: 1
      count: 1
      price: 10
    } ]
    return
  describe 'sell goods', ->
    shop_config = 
      type: 'fixed'
      currency: 'gold'
      goods: [
        {
          id: 1
          count: 1
          price: 20
          limit: count: 5
        }
        {
          id: 2
          count: 1
          price: 10
          limit: vip: 2
        }
        {
          id: 3
          count: 1
          price: 20
          limit: vip: 5
        }
      ]
    shop = libShop.createShop(shop_config)
    shop.version = 1
    customer = 
      addMoney: (currency, point) ->
        if point != null and point + @[currency] < 0
          return false
        if point != null
          @[currency] += point
        true
      vipLevel: ->
        2
      gold: 30
      aquireItem: ->
        [ {} ]
    it 'version check', ->
      do ->
        { error: shop.sell(customer, 0, 1, 0).error }
.should.eql error:
        message: 'Version miss match'
        data:
          source: shop.version
          remote: 0
      return
    it 'money check', ->
      do ->
        { error: shop.sell(customer, 0, 2, 1).error }
.should.eql error:
        message: 'Insufficient money'
        data:
          index: 0
          currency: shop_config.currency
          amount: 2 * 20
      return
    it 'vip check', ->
      do ->
        { error: shop.sell(customer, 2, 1, 1).error }
.should.eql error:
        message: 'Insufficient vip level'
        data:
          index: 2
          level: 5
      return
    it 'good trade', ->
      do ->
        { result: shop.sell(customer, 0, 1, 1).result }
.should.eql result: good:
        id: 1
        count: 1
        price: 20
      customer.gold.should.equal 10
      shop.goods[0].limit.count.should.equal 4
      shop.version.should.equal 2
      return
    it 'version changes if and only if data changes', ->
      do ->
        { result: shop.sell(customer, 1, 1, 2).result }
.should.eql result: good:
        id: 2
        count: 1
        price: 10
      customer.gold.should.equal 0
      shop.version.should.equal 2
      return
    return
  return
