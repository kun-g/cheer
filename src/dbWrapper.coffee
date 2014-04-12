require('./globals')
dbLib = require './db'
moment = require 'moment'
async = require('async')
{Serializer, registerConstructor} = require './serializer'

gLoadingRecord = []

class DBWrapper extends Serializer
  constructor: () ->
    super

  setDBKeyName: (keyName) ->
    @dbKeyName = keyName
    @attrSave('dbKeyName', true)

  getDBKeyName: () -> @dbKeyName

  save: (handler) ->
    data = @dumpChanged()
    if data
      data[k] = JSON.stringify(v) for k, v of data when typeof v is 'object'
      logInfo({info:'Saving', data: data})
      dbClient.hmset(@getDBKeyName(), data, (err, e) => handler(err, this) if handler?)

  load: (handler) ->
    return gLoadingRecord[@getDBKeyName()].push(handler) if gLoadingRecord[@getDBKeyName()]?
    gLoadingRecord[@getDBKeyName()] = [handler]
    dbClient.hgetall(@getDBKeyName(), (err, attr) =>
      ret = null
      if attr?
        attributes = {}
        for k, v of attr
          try
            attributes[k] = JSON.parse(v)
          catch error
            attributes[k] = v
        @restore(attributes)
        ret = this

      for cb in gLoadingRecord[@getDBKeyName()] when cb?
        cb(err, ret)
      delete gLoadingRecord[@getDBKeyName()]
    )

exports.DBWrapper = DBWrapper

exports.updateReceipt = (receipt, state, handler) ->
  dbKey = makeDBKey([ReceiptPrefix, receipt])
  accountDBClient.hgetall(dbKey, (err, ret) ->
    if err then return handler(err)
    #if not ret?
    accountDBClient.hmset(dbKey, {time: moment().format('YYYYMMDDHHMMSS'), state: state}, handler)
    #if state is RECEIPT_STATE_AUTHORIZED
    #  newPendingReceipt(dbKey)
  )
exports.getReceipt = (receipt, handler) ->
  dbKey = makeDBKey([ReceiptPrefix, receipt])
  accountDBClient.hgetall(dbKey, handler)

############################ Mercenary
# 队友规则：
# 1. 随机选择一个基于自己战斗力的值（在一定范围内随机）
# 2. 选择这个值所指向的队列（根据活跃度排列的队列）
# 3. 在此队列里前n个中随机选一个作为这次选择的对象
mercenaryKeyList = (callback) -> dbClient.smembers(mercenaryPrefix+'Keys', callback)
mercenaryGet = (key, count, callback) -> dbClient.zrange(mercenaryPrefix+key, 0, count, callback)
mercenaryDel = (battleForce, member, callback) ->
  async.series([
        (cb) -> dbClient.zrem(mercenaryPrefix+battleForce, member, cb),
        (cb) -> mercenaryGet(battleForce, -1, cb)
      ], (err, result) ->
        if not err
          list = result[1]
          if not list or list.length <= 0
            dbClient.srem(mercenaryPrefix+'Keys', battleForce, callback)
            dbClient.del(mercenaryPrefix+battleForce)
        else
          if callback then callback(err, result)
      )

mercenaryAdd = (battleForce, member, callback) ->
  dbClient.zadd(mercenaryPrefix+battleForce, 0, member, callback)
  dbClient.sadd(mercenaryPrefix+'Keys', battleForce)

mercenaryDemote = (key, member, callback) -> dbClient.zincrby(mercenaryPrefix+key, 1, member, callback)

getPlayerHero = (name, callback) ->
  playerLib = require('./player')
  async.waterfall([
    (cb) -> dbClient.hget(sharedPrefix+name, "blueStar", cb),
    (blueStar, cb) -> dbClient.hmget(playerPrefix+name, 'hero', 'rmb', (err, h) ->
      cb(err, h[0], +h[1], blueStar))
    ,
    (hero, rmb, blueStar, cb) ->
      try
        vip = playerLib.getVip(rmb)
        hero = JSON.parse(hero)
        console.log(hero.equipment)
        hero.vipLevel = +vip.level
        hero.blueStar = +blueStar
      catch e
        err = e
        hero = null
      finally
        if callback then callback(err, hero)
        cb()
  ])
exports.getPlayerHero = getPlayerHero

exports.getMercenaryMember = (names, rangeFrom, rangeTo, count, handler) ->
  selectRange = (list) ->
    selector = []
    trys = 30
    while selector.length <= 0 and trys > 0
      selector = list.filter( (e) -> return e <= rangeTo and e >= rangeFrom; )
      rangeFrom -= 30
      rangeTo += 30
      trys -= 1
    return selector
  doFindMercenary = (list, cb) ->
    if list.length <= 0
      cb(new Error('Empty mercenarylist'))
    else
      selector = selectRange(list)
      battleForce = selector[rand()%selector.length]
      list = list.filter((i) -> return i != battleForce; )
      mercenaryGet(battleForce, count, (err, mList) ->
        if mList == null
          dbClient.srem(mercenaryPrefix+'Keys', battleForce, callback)
          dbClient.del(mercenaryPrefix+battleForce)
          mList = []

        mList = mList.filter((key) ->
          for name in names
            if key is name then return false
          return true
        )
        if mList.length is 0
          cb(null, list)
        else
          selectedName = mList[rand()%mList.length]
          console.log(selectedName, battleForce)
          getPlayerHero(selectedName, (err, hero) ->
            if hero
              cb(new Error('Done'), hero)
            else
              logError({action: 'RemoveInvalidMercenary', error: err, name: selectedName})
              mercenaryDel(battleForce, selectedName, (err) -> cb(null, list))
          )
      )
  actions = [ (cb) -> mercenaryKeyList(cb); ]
  for i in [0..50]
    actions.push(doFindMercenary)
  async.waterfall(actions, handler)

exports.removeMercenaryMember = (battleForce, member, handler) -> mercenaryDel(battleForce, member, handler)
exports.addMercenaryMember = (battleForce, member, handler) -> mercenaryAdd(battleForce, member, handler)
exports.demoteMercenaryMember = (battleForce, member, handler) -> mercenaryDemote(battleForce, member, handler)

exports.updateMercenaryMember = (preBattleForce, battleForce, member, handler) ->
  mercenaryDel(preBattleForce, member)
  mercenaryAdd(battleForce, member, handler)

makeDBKey = (keys, prefix) ->
  prefix = prefix ? dbPrefix
  return [prefix].concat(keys).join(dbSeparator)

exports.updateLeaderboard = (board, member, score, callback) ->
  dbClient.zadd(makeDBKey([LeaderboardPrefix, board]), score, member, callback)

exports.getPositionOnLeaderboard = (board, member, rev, callback) ->
  key = makeDBKey([LeaderboardPrefix, board])
  if rev
    dbClient.zrevrank(key, member, callback)
  else
    dbClient.zrank(key, member, callback)
