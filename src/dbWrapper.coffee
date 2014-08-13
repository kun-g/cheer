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

exports.getReceipt = (receipt, handler) ->
  dbKey = makeDBKey([receipt], ReceiptPrefix)
  accountDBClient.hgetall(dbKey, handler)

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

exports.getMercenaryMember = (name, count, range, delta, names, handler) ->
  heros = []
  dbLib.findMercenary(name, count, range, delta, names,
    (err, heroNames) =>
      if heroNames
        async.eachSeries(
          heroNames,
          (e, cb) ->
            getPlayerHero(e,
              wrapCallback(this, (err, heroData) ->
                heros = heros.concat(heroData)
                cb()
              )
            )
          ,
          () -> handler(err, heros)
        )
  )

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
  dbClient.zadd(makeDBKey([board], LeaderboardPrefix), score, member, callback)
exports.removeLeaderboard = (board, callback) ->
  dbClient.del(makeDBKey([board], LeaderboardPrefix), callback)

exports.getPositionOnLeaderboard = (board, member, rev, callback) ->
  key = makeDBKey([board], LeaderboardPrefix)
  if rev
    dbClient.zrevrank(key, member, callback)
  else
    dbClient.zrank(key, member, callback)

