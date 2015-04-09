"use strict"
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

getPlayerArenaPrentices = (name, callback) ->
  if not name?
    callback('getPlayerArenaPrentices: name is null', []) if callback
    return
  playerLib = require('./player')
  async.waterfall([
    (cb) -> dbClient.hget(playerPrefix+name, 'prenticeLst', cb),
    (prenticeLstData, cb) ->
      try
        prenticeLstData = JSON.parse(prenticeLstData)
        prenticeLst = new playerLib.PrenticeLst(prenticeLstData)

        arenaLst = prenticeLst.getArenaLst()
        prentices = []
        for idx in arenaLst
          prentices.push(prenticeLst.getBasicInfo(idx))
      catch e
        err = e
        prentices = []
      finally
        if callback then callback(err, prentices)
        cb()
  ])
exports.getPlayerArenaPrentices = getPlayerArenaPrentices

exports.getMercenaryMember = (name, count, range, delta, names, appendNames, handler) ->
  heros = []
  dbLib.findMercenary(name, count, range, delta, names,
    (err, heroNames) =>
      heroNames = appendNames.concat(heroNames)
      if heroNames.length > 0
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
      else
        handler('find nothing', null)
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

