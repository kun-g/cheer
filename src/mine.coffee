"use strict"
{Serializer, registerConstructor} = require('./serializer')
{DBWrapper, getPlayerHero, getPlayerArenaPrentices} = require('./dbWrapper')
helperLib = require ('./helper')
underscore = require('./underscore')
{verify,diff,currentTime} = require('./timeUtils')
getPlayerAndPrentice = (name, callback) ->
  async.waterfall([
    (cb) ->  getPlayerHero(name,cb),
    (hero, cb) ->
      heroData = getBasicInfo(hero)
      getPlayerArenaPrentices(name,false,(err, prentices) ->
        unless err?
          heroData.pre = prentices.map(getBasicInfo)
        cb(err, heroData))
  ],callback)


class ResourceRecod extends Serializer
  constructor: (data) ->
    cfg = {
      revengeLst:[]
      coinSource:{count:20,grabTimestamp:0}
      beRobbed:true
    }
    @type = 'mine'
    super(data, cfg, {})
  subCoin: (count, min) ->
    return 0 if not @canBeRobbed()
    diff = count
    temp = @coinSource.count - count
    if temp <= min
      @beRobbed = false
      diff = @coinSource.count - min
      temp = min
    @coinSource.count = temp
    return diff
  hateYou: (name) ->
    if @revengeLst.indexOf(name) is -1
      @revengeLst.push(name)
  getRevengeLst: (from, to, handler) ->
    revengeLst = @revengeLst.slice(from,to)
    async.map(revengeLst, getPlayerAndPrentice ,handler)

  reset: (coin) ->
    @revengeLst = []
    @coinSource = {count: coin, grabTimestamp:currentTime()}
    @beRobbed = true

  checkGrab: () ->
    duration = 1
    timeExp = {
      or:[ {
        duration: { hour: duration },
        time: { time: "time@Arguments", startOf: 'day', offset: { hour: 12 } }
      },
      {
        duration: { hour: duration },
        time: { time: "time@Arguments", startOf: 'day', offset: { hour: 20 } }
    } ]}
 
    now = currentTime()
    return verify(now, timeExp,{}) and Math.abs(diff(@coinSource.grabTimestamp, now).asHours()) > duration

  getRestCoinCount: (player) ->
    challengeCoinCaculatePoion = 15
    defaultCoin = 5

    leftPrenticeCoin = challengeCoinCaculatePoion - defaultCoin
    prenticeCount = player.prenticeLst.count?() ? 0
    if leftPrenticeCoin >= prenticeCount
      return  defaultCoin +  prenticeCount
    else
      return challengeCoinCaculatePoion + Math.floor((prenticeCount - leftPrenticeCoin)/2)


  grab: (me) ->
    return {ret:RET_Cant_Grab} unless @checkGrab()
    count = @coinSource.count
    ntf = me.addMoneyAndSync(PRIZETYPE_CHCOIN,@coinSource.count)
    resetCoin = @getRestCoinCount(me)
    @reset(resetCoin)
    return {ntf:ntf,cnt:count,ret:RET_OK}
  
  canBeRobbed: () ->
    @beRobbed

  isValidate: () ->
    return @name? and @name isnt 'undefined'

  setName: (@name) ->
  

class Mine extends DBWrapper
  constructor: (data) ->
    cfg = {
      miner:{}
    }
    @maxCoin = 20
    @minCoin = Math.floor(0.3 * @maxCoin)
    super(data, cfg, {})
    @setDBKeyName(challengePrefix)
 
  rob: (from, byWho, count) ->
    victim = @miner[from]
    suspect = @miner[byWho.name]
    return new Error(RET_NOT_IN_MINE) unless victim? and suspect?
    actualCount = victim.subCoin(count, @minCoin)
    victim.hateYou(byWho.name)
    byWho.addChallengeCoin(actualCount)

    @_updateRobLst(victim)
    #return { ret:RET_OK, ntf : @_syncPlayerCc(byWho)}
    @_syncPlayerCc(byWho)

    
  _updateRobLst: (victim)->
    if victim.canBeRobbed() and victim.isValidate()
      helperLib.assignLeaderboard(victim, helperLib.LeaderboardIdx.ChallengeCoin)
    else
      helperLib.remveMemberFromLeaderboard(helperLib.LeaderboardIdx.ChallengeCoin,victim.name)

    @save()


  grab: (player) ->
    me = @miner[player?.name]
    return {ret:RET_PlayerNotExists} unless me?
    ret = me.grab(player, @maxCoin)
    @_updateRobLst(me)
    return ret

  getRevengeLst: (name, from, to, handler) ->
    if @miner[name]?
      @miner[name].getRevengeLst(from, to, handler)

  regist: (name) ->
    return if @miner[name]?
    @miner[name] = new ResourceRecod()
    @miner[name].setName(name)
    @save()

  _syncPlayerCc: (player) ->
    return {
      NTF: Event_InventoryUpdateItem,
      arg:{
        syn:player.inventoryVersion,
        cc:player.challengeCoin}}
  load: () ->
    super((err, thiz) ->
      ret = {}
      for k, v of thiz.miner
        ret[k] = new  ResourceRecod(v)
        ret[k].setName(k)
      thiz.miner = ret
    )

  print:() ->
    dprint(@)

  getPositionOnLeaderboard: (typ, name, from, to ,cb) ->
    switch typ
      when helperLib.LeaderboardIdx.Revange
        @getRevengeLst(name,from, to, cb)
      when helperLib.LeaderboardIdx.ChallengeCoin
        helperLib.getPositionOnLeaderboard(typ, name, from, to,
          (err, result) ->
            boardName= result?.board?.name ? []
            boardName= underscore.difference(boardName, [name])
            async.map(boardName, getPlayerAndPrentice, cb)
        )
 



registerConstructor(Mine)
registerConstructor(ResourceRecod)

exports.Mine = Mine
