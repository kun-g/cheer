"use strict"
require('./define')
require('./shop')
moment = require('moment')
{Serializer, registerConstructor} = require './serializer'
{DBWrapper, getMercenaryMember, updateMercenaryMember, addMercenaryMember, getPlayerHero, getPlayerArenaPrentices} = require './dbWrapper'
{createUnit, Hero} = require './unit'
libItem = require './item'
{CommandStream, Environment, DungeonEnvironment, DungeonCommandStream} = require('./commandStream')
{Dungeon, getCfgByRankIdx} = require './dungeon'
{Bag, CardStack} = require('./container')
{diffDate, currentTime, genUtil} = require ('./helper')
helperLib = require ('./helper')
event_cfg= require ('./event_cfg')
underscore = require('./underscore')
dbLib = require('./db')
async = require('async')
libReward = require('./reward')
libCampaign = require("./campaign")
libTime = require('./timeUtils.js')
libShop = require('./shop')
campaign_LoginStreak = new libCampaign.Campaign(queryTable(TABLE_DP))
{doGetProperty} = require('./trigger')

AllClassIDs =[0,1,2,131,132,164,216,217,218]
#TODO this must be remove
isInRangeTime = (timeLst,checkTime) ->
  ([].concat(timeLst)).reduce((acc, dur) ->
    return true if acc
    return (checkTime.diff(moment(dur.beginTime)) >0 and checkTime.diff(moment(dur.endTime)) < 0)
  ,false)

#campaign_StartupClient = new libCampaign.Campaign(gNewCampainTable.startupPlayer)

#getSlotFreezeInfo = (player, slot) ->
#  getItemSlotUsed = (idx) ->
#    item = player.getItemAt(idx)
#    ret = [item.subcategory]
#    ret = ret.concat(item.extraSlots ? [])
#    return ret
#
#  info = player.equipment.map((idx) ->
#    item = player.getItemAt(idx)
#    ret = getItemSlotUsed(idx)
#    return {cid:item.classId, slots:ret}
#  )
#
#  equippingSlots = getItemSlotUsed(slot)
#  freezeBy = info.reduce((acc, elem) ->
#    return acc unless elem?
#    {cid, slots} = elem
#    if underscore.difference(slots, equippingSlots).length isnt slots.length
#      acc.push(slots[0])
#    return acc
#  ,[])
#
#  return {info:info, freezeBy:freezeBy}
#
#exports.getSlotFreezeInfo  = getSlotFreezeInfo
# ======================== Player

doSetProperty = (obj, key, value) ->
  if typeof key is 'string'
    properties = key.split('.')
  else
    properties = [key]
  poped = properties.pop()
  for k in properties
    if not obj[k]?
      obj[k] ={}
    obj = obj[k]

  obj[poped] = value


PrenticeQulity =
  White: 0
  Blue: 1
  Orange: 2


Object.defineProperty(PrenticeQulity, 'size', {
  enumerable : false,
  configurable : false,
  value:underscore.keys(PrenticeQulity).length
  })

class Prentice extends Serializer
  constructor: (data) ->
    cfg = {
      quality: PrenticeQulity.White,
      name : '',
      class:0,
      gender : 0,
      hairStyle : 0,
      hairColor : 0,
      equipment:[],
    }

    super(data, cfg, {})
  upgradeQuality: () ->
    @quality++
  queryInfo: (type, args) ->
    switch type
      when 'skills'
        data =  @getConfig('unlockSkill')
        unlockSkillIds = underscore.range(@quality)
          .reduce((acc, quality) ->
            return acc.concat(data[quality])
          ,[])

        validateSkill = args[@class]?.skill ? []
        return underscore.pick(validateSkill, unlockSkillIds)
      when 'canUpdateQuality'
        return @quality < PrenticeQulity.Orange
      when 'basicInfo'
        ret = underscore.pick(@, args)
        return ret

  getConfig:(type) ->
    queryTable(TABLE_PRENTICE, @class)?[type]


class PrenticeLst extends Serializer
  constructor: (data) ->
    @battleLst =[]
    @masterSkill ={}
    cfg = {
      prenticeLst: [],
      maxPrentice: 20,
      arenaLst: []
    }
    super(data, cfg, {})

    #@prenticeLst = [] unless Array.isArray(@prenticeLst)


  genName: (idx) ->
    @master.name+'徒孙'+(idx+1)+'号'
  setMaster: (@master) ->
    for classId, data of @master.heroBase when classId isnt 'undefined'
      @masterSkill[classId] = (new Hero(data)).wSpellDB
    @onMasterChange(master)
  add: (data, index) ->
    if index? and not @prenticeLst[index]?
      return {ret: RET_PrenticeNotExist}
    ret = @_canAdd(data.class,not index?)
    return ret unless ret.ret is RET_OK
    idx = index ? @prenticeLst.length
    quality = @prenticeLst[idx]?.quality ? PrenticeQulity.White
    data = underscore.extend(data, {quality:quality})
    data.name = @genName(idx)
    ret.ntf ?= []
    if index?
      rmRet = @_removeEquipment(idx)
      ret.ntf = rmRet.concat(ret.ntf) if rmRet?
    @prenticeLst[idx] = new Prentice(data)
    res = @_aquireInitEquipment(idx, data.class)
    ret.ntf = res.concat(ret.ntf) if ret.res?
    ret.ntf = [@syncPrentice()].concat(ret.ntf)
    return ret

  _removeEquipment: (idx) ->
    @prenticeLst[idx].equipment.reduce((acc, slot) =>
      acc.concat(@master.removeItem(null, 1, slot))
    ,[])
  _aquireInitEquipment: (idx,cid) ->
    equipLst = @getConfig(cid,'initialEquip') ? []
    reward = equipLst.map((itemId) ->
      {type:PRIZETYPE_ITEM, value:itemId,count:1})
    @master.claimPrize(reward,true,idx)

  _canAdd: (classId, isNewPrentice) ->
    return {ret:RET_PrenticeUplimit} if isNewPrentice and @count() >= @maxPrentice
    return {ret:RET_PrenticeClassLock} unless @master.isUnlockClass(classId)
    if isNewPrentice
      cost = @getConfig('globalCfg','unlockCost')[@count()]
    else
      cost = @getConfig('globalCfg','rebornCost')
    return {ret: RET_OK} unless cost?
    ntf = @master.claimCost(cost)
    ret = {ret: RET_OK, ntf:ntf}
    ret.ret = RET_ItemNotExist unless ntf?
    return ret
  _getIdxByName: (name) ->
    ret = -1
    @prenticeLst.every((e,idx) ->
      if e.name is name
        ret = idx
        return false
      return true
    )
    return ret

  getConfig:(key, type) ->
    queryTable(TABLE_PRENTICE, key)?[type]

  getEquip: (idx) ->
    if typeof idx is 'number'
      idxLst = [idx]
    else if idx is 'allBattle'
      idxLst = @battleLst
    else
      idxLst = [0..@count()-1]

    idxLst.reduce((acc,i) =>
      return acc.concat(@prenticeLst[i].equipment)
    ,[])
  delEquip: (prenticeIdx, idx) ->
    if @prenticeLst[prenticeIdx]?.equipment?[idx]?
      delete @prenticeLst[prenticeIdx].equipment[idx]
  addEquip: (prenticeIdx,idx,slot) ->
    @prenticeLst[prenticeIdx].equipment[idx] = slot
  count: () -> @prenticeLst.length
  go4War: (team) ->
    @battleLst = team.reduce((acc, data) =>
      idx = @_getIdxByName(data.name)
      if idx isnt -1
        acc.push(idx)
      return acc
    ,[])
  getArenaLst: () -> return @arenaLst
  setArenaLst: (idxArray) ->
    @arenaLst = idxArray
  upgrade: (idx) ->
    unless @getInfo(idx, 'canUpdateQuality',['class','quality'])
      return {ret: RET_PrenticeUpdateLimit}

    info = @getInfo(idx, 'basicInfo',['class','quality'])
    return {ret:RET_PrenticeInvalidate} unless info?
    cost = @getConfig(info.class,'upgradeCost')[info.quality]
    ret = @master.claimCost(cost)
    if ret?
      @prenticeLst[idx].upgradeQuality()
      return {ret:RET_OK,ntf: [@syncPrentice()].concat(ret)}
  getInfo: (idx,type,keys) ->
    @prenticeLst[idx]?.queryInfo(type,keys)
  getBasicInfo: (idxs) ->
    count = @count()
    if count is 0
      idxs = []
    else if not idxs?
      idxs = [0..count - 1]
    idxs.map((idx) =>
      info = @getInfo(idx,'basicInfo',['name','gender', 'class',
      'hairStyle', 'hairColor', 'quality', 'equipment'])
      info.equipment = info.equipment.map((slot) =>
        item = @master.inventory.get(slot)
        if item?
          return { cid: item.classId, eh: item.enhancement }
        return {}
      )
      info.skill = @prenticeLst[idx].queryInfo('skills', @masterSkill)
      return info
    )
  
  syncPrentice:(idxs) ->
    ret = {
      NTF:Event_UpdatePrentice,
      arg:{
        #lst:@prenticeLst.queryInfo('basicInfo')
        max:@maxPrentice,
        lst:@getBasicInfo(idxs).map(getBasicInfo)
      }
    }
    return ret

    
  onMasterChange: (master) ->
    @masterSkill[@master.class] =  (new Hero(@master.hero)).wSpellDB

class Player extends DBWrapper
  constructor: (data) ->
    @type = 'player'
    @memFlags = {}#memory flags 内存中的flag
    @playerLevel = 0
    now = new Date()
    cfg = {
    

    
      name: '',
      questTableVersion: -1,
      stageTableVersion: -1,

      event_daily: {},
      globalPrizeFlag: {},

      timestamp: {},
      counters: {},
      flags: {},

      inventory: Bag(InitialBagSize),
      gold: 0,
      diamond: 0,
      masterCoin: 0,
      arenaCoin: 0,
      challengeCoin: 0,
      equipment: {},
      heroBase: {},
      heroIndex: -1,
      #TODO: hero is duplicated
      hero: {},
      playerXp: 0,

      prenticeLst: new PrenticeLst(),

      inviter: {},
      invitee: {},
      stage: [],
      quests: {},

      energy: ENERGY_MAX,
      energyTime: now.valueOf(),

      mercenary: [],
      dungeonData: {},
      runtimeID: -1,
      rmb: 0,
      spendedDiamond: 0,
      tutorialStage: 0,
      purchasedCount: {},
      lastLogin: currentTime(),
      creationDate: now.valueOf(),
      isNewPlayer: true,
      accountID: -1,
      campaignState: {},
      infiniteTimer: currentTime(),
      shops: {},

      inventoryVersion: 1,
      heroVersion: 1,
      stageVersion: 1,
      questVersion: 1,
      prenticeVersion: 1,
      
      energyVersion: 1,

      abIndex: rand(),
    }
    for k,v of libReward.config
      cfg[k] = v

    @envReward_modifier = gReward_modifier
    versionCfg = {
      inventoryVersion: ['gold', 'diamond', 'inventory', 'equipment', 'challengeCoin'],
      heroVersion: ['heroIndex', 'hero', 'heroBase'],
      stageVersion: 'stage',
      questVersion: 'quests',
      energyVersion: ['energy', 'energyTime']
    }
    super(data, cfg, versionCfg)

  setName: (@name) -> @dbKeyName = playerPrefix+@name
  getServer: () -> return gServerObject

  generateReward: libReward.generateReward
  getRewardModifier: libReward.getRewardModifier
  generateDungeonReward: libReward.generateDungeonReward
  claimDungeonReward: libReward.claimDungeonReward

  logout: (reason) ->
    if @socket and @socket.encoder
      @socket.encoder.writeObject({NTF: Event_ExpiredPID, err: reason})
    @onDisconnect()
    dbLib.unsubscribe(PlayerChannelPrefix+this.name)
    #@destroy()
    @destroied = true

  onReconnect: (socket) ->
    @fetchMessage(wrapCallback(this, (err, newMessage) ->
      socket.encoder.writeObject(newMessage) if socket?),
      true
    )

  logError: (action, msg) -> @log(action, msg, 'error')

  log: (action, msg, type) ->
    if not msg? then msg = {}
    msg.name = @name
    msg.action = action
    if type and type is 'error'
      logError(msg)
    else
      logUser(msg)

  # param prenticeIdxOrAll
  # null for getting master's
  # num for getting the num index of prentice's
  # 'all' for getting all 
  # 'allBattle' for getting master and prentice who go for war
  getEquipRef: (prenticeIdxOrAll) ->
    if not prenticeIdxOrAll?
      return @equipment
    else if typeof  prenticeIdxOrAll is 'number'
      return @prenticeLst.getEquip(prenticeIdxOrAll)
    else
      return @equipment.concat(@prenticeLst.getEquip(prenticeIdxOrAll))

  addEquipRef: (idx,slot,prenticeIdx) ->
    if not prenticeIdx?
      @equipment[idx] = slot
    else
      @prenticeLst.addEquip(prenticeIdx,idx,slot)
  # param prenticeIdx
  # null for deleting master's
  # num for deleting the num index of prentice's
  delEquipRef: (idx, prenticeIdx) ->
    if not  prenticeIdx?
      delete @equipment[idx]
    else if typeof  prenticeIdx is 'number'
      return @prenticeLst.delEquip(prenticeIdx, idx)

  findEquipRef: (slot) ->
    for k, v of @getEquipRef()
      return {where:'master', idx:k} if (+v) is (+slot)
    if @prenticeLst.count() > 0
      for k in [0..@prenticeLst.count()-1]
        for i, v of @getEquipRef(+k)
          return {where:'prentice', prenticeIdx: k, idx:i} if (+v) is (+slot)
    return {}

  isEquiped: (slot) ->
    equipment = (e for i, e of @getEquipRef('all'))
    return equipment.indexOf(+slot) != -1

  migrate: (prenticeIdx) -> #TODO:deprecated
    flag = false
    for slot, item of @inventory.container when item?
      if item.transPrize?
        if @isEquiped(slot)
          # 2. 已装备的装备保留强化等级
          lv = 0
          if item.enhancement and item.enhancement.length > 0
            lv = item.enhancement.reduce( ((r, i) -> return r+i.level), 0 )
          # 3. 已装备的饰品转换成对应的饰品
          cfg = require('./transfer').data
          if cfg[item.id]
            p = cfg[item.id].filter((e) => isClassMatch(@hero.class, e.classLimit))
            item.id = p[0].value
          enhanceID = queryTable(TABLE_ITEM, item.id).enhanceID
          if enhanceID? and lv >= 0 then item.enhancement = [{id: enhanceID, level: lv}]
          continue
        flag = true
        @sellItem(slot)
    prize = queryTable(TABLE_ROLE, @hero.class)?.initialEquipment
    for slot in [0..5] when not @equipment[slot]?
      flag = true
      @claimPrize(prize[slot]) if prize?
    return flag

  onDisconnect: () ->
    @socket = null
    gPlayerDB[@name] = null
    delete @messages

  getType: () -> 'player'

  submitCampaign: (campaign, handler) ->
    event = this[campaign]
    if event?
      helperLib.proceedCampaign(@, campaign, event_cfg.events, handler)
      @log('submitCampaign', {event: campaign, data: event})
    else
      @logError('submitCampaign', {reason: 'NoEventData', event: campaign})

  syncEvent: () -> return helperLib.initCampaign(@, event_cfg.events)

  onLogin: () ->
    @counters.energyRecover ?= 0
    return [] unless @lastLogin
    if diffDate(@lastLogin) > 0
      @purchasedCount = {}
      @counters.energyRecover = 0
      @counters.friendHireTime ={}
    @lastLogin = currentTime()
    if gGlobalPrize?
      for key, prize of gGlobalPrize when not @globalPrizeFlag[key]
        dbLib.deliverMessage(@name, prize)
        @globalPrizeFlag[key] = true

    if not moment().isSame(@infiniteTimer, 'week')
      @infiniteTimer = currentTime()
      for s in @stage when s and s.level?
        s.level = 0

    #for test iap leaderboard
    #@handleReceipt({productID:'com.tringame.pocketdungeon.pay68',paymentType:'test',receipt:'0000008403001423555722Teebik'}, 'test', console.log)
    #end
    @onCampaign('RMB')

    flag = campaign_LoginStreak.isActive(this,  currentTime())
    ret = [{ NTF:Event_CampaignLoginStreak, day: @counters.check_in.counter, claim: flag }]
    @log('onLogin', {streak: @counters.check_in.counter, date: @counters.check_in.time})

    #if campaign_StartupClient.isActive(this, currentTime())
    #  campaign_StartupClient.activate(this, 1, currentTime())

    itemsNeedRemove = @inventory.filter(
      (item) ->
        return false unless item?.expiration?
        return true unless item.date?
        return helperLib.matchDate(item.date, helperLib.currentTime(), item.expiration)
    )
    ret = itemsNeedRemove.reduce( (pValue,e) =>
      return pValue.concat(@removeItem(null, null, @queryItemSlot(e)))
    , ret)

    ret.push(@syncCounters(['energyRecover'],true))
    @createHero()
    @updateMenFlags(PLAYERLEVELID,0,@playerXp)
    @prenticeLst.setMaster(@)
    gMiner?.regist(@name)
    return ret

  claimLoginReward: () ->
    if campaign_LoginStreak.isActive(this)
      @log('claimLoginReward', {streak: @counters.check_in.counter, date: @counters.check_in.time})
      reward = queryTable(TABLE_DP).rewards[@counters.check_in.counter].prize
      ret = @claimPrize(reward.filter((e) => not e.vip or @vipLevel() >= e.vip ))
      campaign_LoginStreak.activate(this, 1)
      return {ret: RET_OK, res: ret}
    else
      return {ret: RET_RewardAlreadyReceived}

  sweepStage: (stage, multiple, rankIdx=0) ->
    stgCfg = queryTable(TABLE_STAGE, stage, @abIndex)
    return { code: RET_DungeonNotExist, ret: [] } unless stgCfg

    cfg = queryTable(TABLE_DUNGEON, stgCfg.dungeon, @abIndex)
    return { code: RET_DungeonNotExist, ret: [] } unless cfg

    dungeon = {
      team: [],
      quests: [],
      revive: 0,
      result: DUNGEON_RESULT_WIN,
      killingInfo: [],
      currentLevel: cfg.levelCount,
      config: cfg,
      isSweep : true,
      rankIdx : rankIdx,
    }
    count = 1
    count = 5 if multiple
    ret_result = RET_OK
    prize = []
    ret = []

    cost = getCfgByRankIdx(stgCfg, null, rankIdx, "sweepCost")
    energyCost = cost * count
    itemCost = {id: 871, num: count}

    if @stage[stage].state != STAGE_STATE_PASSED
      ret_result = RET_StageIsLocked
    else if multiple and @vipLevel() < Sweep_Vip_Level
      ret_result = RET_VipLevelIsLow
    else if @energy < energyCost
      ret_result = RET_NotEnoughEnergy
    else if getCfgByRankIdx(stgCfg, null, rankIdx, "sweepPower") > @createHero().calculatePower()
      ret_result = RET_SweepPowerNotEnough
    else
      itemCostRet = @claimCost({id:itemCost.id}, itemCost.num)
      if not itemCostRet?
        ret_result = RET_NotEnoughItem
      else

        @costEnergy(energyCost)
        ret = ret.concat(itemCostRet)
        for i in [1..count]
          p = @generateDungeonReward(dungeon, true)
          r = []
          for k, v of p
            r = r.concat(v)
          r = r.filter((e) => not ((PRIZETYPE_GOLD <= e.type <= PRIZETYPE_WXP or e.type is PRIZETYPE_CHCOIN) and e.count <= 0))
          prize.push(r)
          ret = ret.concat(@claimPrize(r))
        @log('sweepDungeon', { stage: stage, multiple: multiple, reward: prize })
        ret = ret.concat(@syncEnergy())
        
    return { code: ret_result, prize: prize, ret: ret }

  onMessage: (msg) ->
    switch msg.action
      when 'RemovedFromFriendList'
        @removeFriend(msg.name)
        @updateFriendInfo(wrapCallback(this, (err, ret) ->
          if @socket? then @socket.encoder.writeObject(ret))
        )

  initialize: () ->
    dbLib.subscribe(PlayerChannelPrefix+this.name, wrapCallback(this, (msg) =>
      return false unless @socket?
      if msg is 'New Message'
        @fetchMessage(wrapCallback(this, (err, newMessage) ->
          @socket.encoder.writeObject(newMessage))
        )
      else if msg is 'New Friend'
        @updateFriendInfo(wrapCallback(this, (err, ret) ->
          @socket.encoder.writeObject(ret))
        )
      else
        try
          msg = JSON.parse(msg)
          @onMessage(msg)
        catch err
          logError({type: 'Subscribe', err: err, msg: msg})
    ))

    helperLib.initObserveration(this)
    @installObserver('heroxpChanged')
    @installObserver('battleForceChanged')
    @installObserver('countersChanged')
    @installObserver('stageChanged')
    @installObserver('winningAnPVP')
    @installObserver('onChargeDiamond')
    @installObserver('onBuyTreasures')
    


    helperLib.assignLeaderboard(@,helperLib.LeaderboardIdx.Arena)
    @counters['worldBoss'] ={} unless @counters['worldBoss']?

    if @isNewPlayer then @isNewPlayer = false
    unless @invitation
      helperLib.redeemCode.newInvitation(@name, (err, res) =>
        if not err?
          @invitation = res
          @attrSave('invitation')
          @saveDB()
        else
          dprint('GenerateInvitation Error:', err)
      )

    @inventory.validate()

    if @hero?
      @updateMercenaryInfo()

    if @questTableVersion isnt queryTable(TABLE_VERSION, 'quest')
      @updateQuestStatus()
      @questTableVersion = queryTable(TABLE_VERSION, 'quest')

    if @stageTableVersion isnt queryTable(TABLE_VERSION, 'stage')
      @updateStageStatus()
      @stageTableVersion = queryTable(TABLE_VERSION, 'stage')
    @loadDungeon()


  handleReceipt: (payment, tunnel, cb) ->
    productList = queryTable(TABLE_IAPLIST, 'list')
    myReceipt = payment.receipt
    rec = unwrapReceipt(myReceipt)

    if tunnel is 'AppStore'
      rec.productID = -1
      for idx , product of  productList
        if product.productID is payment.productID
          rec.productID = +idx
      
    return cb('show_me_the_real_money',[]) if rec.productID is -1
    cfg = productList[rec.productID]
    flag = true
    #flag = cfg.rmb is payment.rmb
    #flag = payment.productID is cfg.productID if tunnel is 'AppStore'
    @log('charge', {
      rmb: cfg.price,
      diamond: cfg.gem,
      tunnel: tunnel,
      action: 'charge',
      match: flag,
      receipt : myReceipt
    })
    if flag
      ret = [{ NTF: Event_InventoryUpdateItem, arg: { dim : @addDiamond(cfg.gem) }}]

      if rec.productID is MonthCardID
        @counters['monthCard'] = 30
        ret = ret.concat(@syncEvent())
      @rmb += cfg.price
#      if @inviter
#        for k1,v1 of @inviter
#          dbLib.deliverMessage(
#            k1,
#            {
#              type: MESSAGE_TYPE_SystemReward,
#              src: MESSAGE_REWARD_TYPE_SYSTEM,
#              prize: [{
#                type:PRIZETYPE_DIAMOND,
#                count: Math.floor(cfg.gem * 0.1)
#              }],
#              tit: Localized_Text.InvitationAwardTitle[0],
#              txt: Localized_Text.InvitationAwardContent1[0]+@name+Localized_Text.InvitationAwardContent1[1]
#            })
#
#      for k2,v2 of @invitee
#        dbLib.deliverMessage(k2,
#          {
#            type: MESSAGE_TYPE_SystemReward,
#            src: MESSAGE_REWARD_TYPE_SYSTEM,
#            prize: [{
#              type:PRIZETYPE_DIAMOND,
#              count: Math.floor(cfg.gem * 0.1)
#            }],
#            tit: Localized_Text.InvitationAwardTitle[0],
#            txt: Localized_Text.InvitationAwardContent2[0]+@name+Localized_Text.InvitationAwardContent2[1]
#          })

      @onCampaign('RMB', {idx:rec.productID, rmb:cfg.price, gem:cfg.gem})
      @counters.chargeDiamond ?= 0
      @counters.chargeDiamond += cfg.gem
      @counters['888'] ?= 0
      if (+@counters['888']+1)*888<@counters.chargeDiamond
        @counters['888'] += 1
        ret.push(@claimPrize({type:PRIZETYPE_ITEM, value:1630,count:1}))

      @notify('onChargeDiamond', {gem:cfg.gem})
      ret.push({NTF: Event_PlayerInfo, arg: { rmb: @rmb, mcc: @counters.monthCard}})
      ret.push(@syncVipData())
      postPaymentInfo(@createHero().level, myReceipt, payment.paymentType)
      @saveDB()
      dbLib.updateReceipt(
        myReceipt,
        RECEIPT_STATE_CLAIMED,
        rec.id,
        rec.productID,
        rec.serverID,
        rec.tunnel,

        (err) -> cb(err, ret))
    else
      cb(Error(RET_InvalidPaymentInfo))

  handlePayment: (payment, handle) ->
    @log('handlePayment', {payment: payment})
    postResult = (error, result) =>
      if error
        logError({name: @name, receipt: myReceipt, type: 'handlePayment', error: error, result: result})
        if error is 'show_me_the_real_money'
          handle(Error(RET_InvalidPaymentInfo), [])
        else
          handle(null, [])
      else
        handle(null, result)
    switch payment.paymentType
      when 'AppStore' then @handleReceipt(payment, 'AppStore', postResult)
      when 'PP25', 'ND91', 'KY', 'Teebik'
        myReceipt = payment.receipt
        async.waterfall([
          (cb) ->
            dbWrapper.getReceipt(myReceipt, (err, receipt) ->
              if receipt? and receipt.state isnt  RECEIPT_STATE_DELIVERED then cb(Error(RET_Issue37)) else cb(null, myReceipt, payment.paymentType)
            )
          ,
          (receipt, tunnel, cb) => @handleReceipt(payment, tunnel, cb)
        ], postResult)

  updateStageStatus: (level) ->
    ret = []
    for s in updateStageStatus(@stage, @, @abIndex)
      ret = ret.concat(@changeStage(s, STAGE_STATE_ACTIVE, level))
    return ret

  updateQuestStatus: () ->
    ( @acceptQuest(q) for q in updateQuestStatus(@quests, @, @abIndex) )

  loadDungeon: () ->
    if @dungeonData.stage?
      @dungeon = new Dungeon(@dungeonData)
      @dungeon.initialize()

  releaseDungeon: () ->
    delete @dungeon
    @dungeonData = {}

  getPurchasedCount: (id) -> return @purchasedCount[id] ? 0

  addPurchasedCount: (id, count) ->
    @purchasedCount[id] = 0 unless @purchasedCount[id]?
    @purchasedCount[id] += count

  createPlayer: (arg, account, cb) ->
#add check for switchhero
    cb({message:'big brother is watching ya'}) if not (0<= arg.cid <= 2)

    @setName(arg.nam)
    @accountID = account
    @initialize()
    @createHero({
      name: arg.nam
      class: arg.cid
      gender: arg.gen
      hairStyle: arg.hst
      hairColor: arg.hcl
      skill:{}
      })
    prize = queryTable(TABLE_ROLE, arg.cid)?.initialEquipment
    @claimPrize(prize)
    logUser({
      name: arg.nam
      action: 'register'
      class: arg.cid
      gender: arg.gen
      hairStyle: arg.hst
      hairColor: arg.hcl
      })
    @saveDB(cb)

  isUnlockClass: (classId) ->
    classId is @hero.class or @heroBase[classId]?

  putOnEquipmentAfterSwitched: (heroClass)->
    return unless underscore.isEmpty(@heroBase[heroClass].equipment)
    prize = queryTable(TABLE_ROLE, heroClass)?.initialEquipment
    for p in prize
      ret = @claimPrize(p)

  createHero: (heroData, isSwitch) ->
    if heroData?
      return null if @heroBase[heroData.class]? and heroData.class is @hero.class
      if isSwitch
        heroData.xp = @hero.xp
        heroData.equipment = @heroBase[heroData.class]?.equipment or {}
        heroData.skill = @heroBase[heroData.class]?.skill or {}
        @heroBase[heroData.class] = heroData
        @switchHero(heroData.class)
        @putOnEquipmentAfterSwitched(heroData.class)
      else
        heroData.xp = 0
        heroData.equipment = []
        @heroBase[heroData.class] = heroData

        @switchHero(heroData.class)
      return @createHero()
    else if @hero
      bag = @inventory
      equip = []
      temp = underscore.uniq(@getEquipRef())
      equip.push({
        cid: bag.get(e).classId
        eh: bag.get(e).enhancement }) for i, e of temp when bag.get(e)?
      @hero['equipment'] = equip

      hero = new Hero(@hero)
      bf = hero.calculatePower()
      if bf isnt @battleForce
        @battleForce = bf
        @notify('battleForceChanged')
      @save()
      return hero
    else
      throw 'NoHero'

  switchHeroType: (classId) ->
    # in this situation, the classid of new roles (aka:vertical change ) are more than 200
    if  Math.abs(classId - @hero.class) > 100
      return 'verticalChange'
    else
      return 'horizonChange'

  switchHero: (hClass) ->
    return false unless @heroBase[hClass]?

    if @hero?
      @heroBase[@hero.class] = {}
      for k, v of @hero
        @heroBase[@hero.class][k] = JSON.parse(JSON.stringify(v)) if k isnt 'equipment'
      @heroBase[@hero.class].equipment = JSON.parse(JSON.stringify(@getEquipRef()))

    for k, v of @heroBase[hClass]
      @hero[k] = JSON.parse(JSON.stringify(v))
    @equipment = JSON.parse(JSON.stringify(@heroBase[hClass].equipment))

  addMoney: (type, point, max) ->
    return this[type] unless point
    return false if point + this[type] < 0
    this[type] = Math.floor(this[type]+point)
    this[type] = max if max? and this[type] > max
    @costedDiamond += point if type is 'diamond'
    return this[type]

  addMoneyAndSync:(type,point) ->
    switch type
      when PRIZETYPE_GOLD
        func = @addGold
        stype = 'god'
      when PRIZETYPE_DIAMOND
        func = @addDiamond
        stype = 'dim'
      when PRIZETYPE_CHCOIN
        func = @addChallengeCoin
        stype = 'chc'
      else
        throw 'Invalidate_Money_Type'
    ret = {NTF: Event_InventoryUpdateItem, arg: {syn: @inventoryVersion}}
    ret.arg[stype] =  func(point)
    return ret
  addDiamond: (point) -> @addMoney('diamond', point)

  addGold: (point) -> @addMoney('gold', point)

  addChallengeCoin: (point) ->
    @addMoney('challengeCoin', point, @getMaxChallengeCoin())
  getMaxChallengeCoin: () ->
    challengeCoinCaculatePoion = 15
    vipCoin = @vipOperation('challengeCoin')
    leftPrenticeCoin = challengeCoinCaculatePoion - vipCoin
    prenticeCount = @prenticeLst.count()
    if leftPrenticeCoin >= prenticeCount
      return vipCoin +  prenticeCount
    else
      return challengeCoinCaculatePoion + Math.floor((prenticeCount - leftPrenticeCoin)/2)

  addHeroExp: (point) ->
    if point
      prevLevel = @createHero().level
      @hero.xp = Math.floor(@hero.xp+point)
      currentLevel = @createHero().level
      @notify('heroxpChanged', {
        xp: @hero.xp,
        delta: point,
        prevLevel: prevLevel,
        currentLevel: currentLevel
      })
      @log('levelChange', {prevLevel: prevLevel, newLevel: currentLevel})

    return @hero.xp

  costEnergy: (point) ->
    now = new Date()

    if @energyTime? and @energy < @energyLimit()
      incTime = now - @energyTime
      incPoint = incTime / ENERGY_RATE
      @energy += incPoint
      @energy = @energyLimit() if @energy > @energyLimit()

    @energyTime = now.valueOf()

    if point
      if @energy < point then return false
      @energy -= point
      @playerXp += point if point > 0 #玩家经验，对应玩家等级
      @updateMenFlags(PLAYERLEVELID,@playerLevel,@playerXp)

    return true

  updateMenFlags: (levelId, curLevel, exp) ->
    levelConfig = getLevelUpConfig(levelId,curLevel,exp)#更新flag
    @playerLevel = levelConfig['curLevel']
    dprint("levelConfig",levelConfig," curLevel",curLevel)
    if levelConfig.flag
      for k in levelConfig.flag
        @memFlags[k] = true
      dprint("memFlags",@memFlags)
    return true

  saveDB: (handler) -> @save(handler)

  modifyCounters: (propertyName,arg) ->
    @counters[propertyName] = arg.value? 0
    @notify(arg.notify.name,arg.notify.arg) if arg.notify?

  stageIsUnlockable: (stage, rankIdx) ->
    return true if g_DEBUG_FLAG
    return false if getPowerLimit(stage) > @createHero().calculatePower()
    stageConfig = queryTable(TABLE_STAGE, stage, @abIndex)
    if stageConfig.condition then return stageConfig.condition(this, genUtil())
    if stageConfig.event
      return @[stageConfig.event]? and @[stageConfig.event].status is 'Ready'
    return @stage[stage] and (@stage[stage].state != STAGE_STATE_INACTIVE or (@stage[stage] is STAGE_STATE_PASSED and rankIdx > 0))

  changeStage: (stage, state, level = 0) ->
    stg = queryTable(TABLE_STAGE, stage)
    @stageVersion++
    if stg
      chapter = stg.chapter

      @stage[stage]= {} unless @stage[stage]?

      flag = false
      arg = {chp: chapter, stg:stage, sta:state}

      if stg.isInfinite
        @stage[stage]['level'] = 0 unless @stage[stage].level?
        if state is STAGE_STATE_PASSED
          @stage[stage].level = level
          @notify('stageChanged',{stage:stage})
          if @stage[stage].level%5 is 0
            dbLib.broadcastEvent(BROADCAST_INFINITE_LEVEL, {who: @name, where: stage, many: @stage[stage].level})

        arg.lvl = @stage[stage].level
        flag = true

      operation = 'unlock'
      operation = 'complete' if state is STAGE_STATE_PASSED

      ret = []
      if @stage[stage].state isnt state
        if stg.tutorial? and state is STAGE_STATE_PASSED
          @tutorialStage = stg.tutorial
          ret.push({NTF: Event_TutorialInfo, arg: { tut: @tutorialStage }})
        @stage[stage].state = state
        flag = true

      if flag then ret.push({NTF: Event_UpdateStageInfo, arg: {syn: @stageVersion, stg:[arg]}})

      @log('stage', { operation: operation, stage: stage })
      return ret

  dungeonAction: (action) ->
    return [{NTF: Event_Fail, arg: 'Dungeon not exist.'}] unless @dungeon?
    ret = [].concat(@dungeon.doAction(action))
    ret = ret.concat(@claimDungeonReward(@dungeon)) if @dungeon.result?
    return ret

  updateFriendHiredInfo: (nameLst) ->
   @counters.friendHireTime ?={}
   for hero in nameLst
     name = hero.name
     if @contactBook?
       if @contactBook.book.indexOf(name) isnt -1
         @counters.friendHireTime[name] ?= 0
         @counters.friendHireTime[name] += 1

   

  startDungeon: (stage, startInfoOnly, selectedTeam, pkr=null,rankIdx =0, handler) ->
    stageConfig = queryTable(TABLE_STAGE, stage, @abIndex)
    dungeonConfig = queryTable(TABLE_DUNGEON, stageConfig.dungeon, @abIndex)
    unless stageConfig? and dungeonConfig?
      @logError('startDungeon', {reason: 'InvalidStageConfig', stage: stage, stageConfig: stageConfig?, dungeonConfig: dungeonConfig?})
      return handler(null, RET_ServerError)
    cost = getCfgByRankIdx(stageConfig, dungeonConfig, rankIdx, "energyCost")
    async.waterfall([
      (cb) => if @dungeonData.stage? then cb('OK') else cb(),
      (cb) => if @stageIsUnlockable(stage, rankIdx) then cb() else cb(RET_StageIsLocked),
      (cb) => if @costEnergy(cost) then cb() else cb(RET_NotEnoughEnergy),
      (cb) => @requireMercenary(
        (team) =>
          cb(null, team)
        ,stageConfig.teamType),
      (mercenary, cb) =>
        teamCount = stageConfig.team ? 3
        if @stage[stage]? and @stage[stage].level?
          level = @stage[stage].level
          if level%10 is 0 then teamCount = 1
          else if level%5 is 0 then teamCount = 2

        team = [@createHero()]
        team[0].notMirror= true

        if stageConfig.teammate? then team = team.concat(stageConfig.teammate.map(
          (hd) ->
            newHero = new Hero(hd)
            newHero.notMirror = true
            return newHero
        ))
        if teamCount > team.length
          leftTeamCount = teamCount-team.length
          if Array.isArray(selectedTeam) and selectedTeam.length >=leftTeamCount
            temp = []
            temp.push(mercenary[idx]) for idx in selectedTeam when mercenary[idx]?
            @updateFriendHiredInfo(temp)
            team = team.concat(temp)
            @mercenary = []
          else if mercenary.length >= leftTeamCount
            team = team.concat(mercenary.splice(0, teamCount-team.length))
            @mercenary = []
          else
            @costEnergy(-cost)
            return cb(RET_NeedTeammate)

          @prenticeLst.go4War(team)
        cb(null, team, level)
      ,
      (team, level, cb) =>
        blueStar = team.reduce(wrapCallback(this, (r, l) ->
          if not l.leftBlueStar? then return r
          if l.leftBlueStar >= 0
            return @getBlueStarCost()+r
          else
            dbLib.incrBluestarBy(l.name, -l.leftBlueStar, () -> {})
            return @getBlueStarCost()+r+l.leftBlueStar
        ), 0)
        cb(null, team, level, blueStar)
      ,
      (team, level, blueStar, cb) =>
        quest = {}
        for qid, qst of @quests when not qst.complete
          quest[qid] = qst
        cb(null, team, level, blueStar, quest)
      ,
      (team, level, blueStar, quest, cb) =>
        @dungeonData = {
          stage: stage,
          initialQuests: quest,
          infiniteLevel: level,
          blueStar: blueStar,
          abIndex: @abIndex,
          team: team.map(getBasicInfo),
          reviveLimit: @getReviveLimit(dungeonConfig.reviveLimit),
          rankIdx:rankIdx
        }

        @dungeonData.randSeed = rand()
        @dungeonData.baseRank = helperLib.initCalcDungeonBaseRank(@) if stageConfig.event is 'event_daily'
        cb()
      ,
      (cb) =>
        if stageConfig.pvp? and pkr?
          @dungeonData.PVP_Pool = []
          getPlayerHero(pkr, wrapCallback(this, (err, heroData) ->
            if heroData?
              pvpPool = [getBasicInfo(heroData)]
            @dungeonData.PVP_Pool = pvpPool ? []
            heroData = heroData ? {}
            isArena = stageConfig.pvp is 'arena'
            getPlayerArenaPrentices(heroData.name, isArena, (err, prentices) =>
              if err then console.log('ERROR:', err)
              @dungeonData.PVP_Pool.concat(prentices)
              dbLib.diffPKRank(@name, pkr,wrapCallback(this, (err, result) ->
                result = [0,0]  unless Array.isArray(result)
                @dungeonData.PVP_Score_diff = result[0]
                @dungeonData.PVP_Score_origin = result[1]
                cb('OK')
              ))
            )
          ))
        else
          cb('OK')
      ], (err) =>
        msg = []
        if err isnt 'OK'
          ret = err
          err = new Error(err)
        else
          @loadDungeon()
          if @dungeon?
            if stageConfig.initialAction then stageConfig.initialAction(@,  genUtil())
            if stageConfig.eventName then msg = @syncEvent()
            @log('startDungeon', {dungeonData: @dungeonData, err: err})
            ret = if startInfoOnly then @dungeon.getInitialData() else @dungeonAction({CMD:RPC_GameStartDungeon})
          else
            @logError('startDungeon', { reason: 'NoDungeon', err: err, data: @dungeonData, dungeon: @dungeon })
            @releaseDungeon()
            err = new Error(RET_DungeonNotExist)
            ret = RET_DungeonNotExist
        handler(err, ret, msg) if handler?
      )

  acceptQuest: (qid) ->
    return [] if @quests[qid]
    quest = queryTable(TABLE_QUEST, qid, @abIndex)
    @quests[qid] = {counters: (0 for i in quest.objects)}
    # TODO: implement updateQuestStatus instead
    @onEvent('gold')
    @onEvent('diamond')
    @onEvent('item')
    @questVersion++

    return packQuestEvent(@quests, qid, @questVersion)

  rearragenPrize: (prize) ->
    prize = [prize] unless Array.isArray(prize)
    itemPrize = []
    otherPrize = []
    for p in prize when p?
      if p.type is PRIZETYPE_ITEM
        if p.count > 0 then itemPrize.push(p)
      else
        otherPrize.push(p)
    if itemPrize.length > 1
      itemPrize = [{
        type: PRIZETYPE_ITEM,
        value: itemPrize.map((e) -> return {item: e.value, count: e.count}),
        count: 0
      }]

    return itemPrize.concat(otherPrize)

  claimCost: (cost, count = 1) ->
    ret = @claimCost_witherr(cost, count)
    dprint("claimCost ret:",ret)
    return null unless Array.isArray(ret)
    return ret

  claimCost_witherr: (cost, count = 1) ->
    if Array.isArray(cost)
      cfg = {material:cost}
    else if typeof cost is 'object'
      cfg ={material:[{type:0, value:cost.id, count:1}]}
    else
      cfg = queryTable(TABLE_COSTS, cost)

    return {type:'noconfig'} unless cfg?
    dprint("claimCost_witherr cfg:",cfg)
    prize = @rearragenPrize(cfg.material)
    dprint("claimCost_witherr rearragen prize:",prize)
    haveEnoughtMoney = prize.reduce( (r, l) =>
      if l.type is PRIZETYPE_GOLD and @gold < l.count*count then return false
      if l.type is PRIZETYPE_DIAMOND and @diamond < l.count*count then return false
      if l.type is PRIZETYPE_CHCOIN and @challengeCoin < l.count*count then return false
      return r
    , true)
    return {type:'noenoughmoney'} unless haveEnoughtMoney
    ret = []
    for p in prize when p?
      @inventoryVersion++
      switch p.type
        when PRIZETYPE_ITEM
          retRM = @inventory.remove(p.value, p.count*count, null, true)
          return {type:'noenoughitem', value:p.value, count:p.count*count} unless retRM and retRM.length > 0
          ret = @doAction({id: 'ItemChange', ret: retRM, version: @inventoryVersion})
        when PRIZETYPE_GOLD,PRIZETYPE_DIAMOND ,PRIZETYPE_CHCOIN
          ret.push(@addMoneyAndSync(-p.count*count))


    return ret

  claimPrize: (prize, allOrFail = true,prenticeIdx) ->
    return [] unless prize?
    prize = [prize] unless Array.isArray(prize)

    ret = []

    for p in prize when p?
      @inventoryVersion++
      switch p.type
        when PRIZETYPE_ITEM
          res = @aquireItem(p.value, p.count, allOrFail,prenticeIdx)
          if not (res? and res.length >0)
            return [] if allOrFail
          gServerObject.notify('playerClaimItem',{player:@name,item:p.value})
          ret = ret.concat(res)

        when PRIZETYPE_GOLD, PRIZETYPE_DIAMOND ,PRIZETYPE_CHCOIN
          ret.push(@addMoneyAndSync(-p.count*count)) if p.count > 0
        when PRIZETYPE_EXP then ret.push({NTF: Event_RoleUpdate, arg: {syn: @heroVersion, act: {exp: @addHeroExp(p.count)}}}) if p.count > 0
        when PRIZETYPE_WXP
          continue unless p.count
          equipUpdate = []
          for i, k of @getEquipRef('allBattle')
            e = @getItemAt(k)
            unless e?
              logError({action: 'claimPrize', reason: 'equipmentNotExist', name: @name, equipSlot: k, index: i})
              @unequipItem(k)
              continue
            e.xp = e.xp+p.count
            equipUpdate.push({sid: k, xp: e.xp})
          if equipUpdate.length > 0
            ret.push({NTF: Event_InventoryUpdateItem, arg: {syn: @inventoryVersion, itm: equipUpdate}})
        when PRIZETYPE_FUNCTION
          switch p.func
            when "setFlag"
              @flags[p.flag] = p.value
              ret = ret.concat(@syncFlags(true)).concat(@syncEvent())
            when "countUp"
              if p.target is 'server'
                gServerObject.counters[p.counter] = 0 unless gServerObject.counters[p.counter]?
                gServerObject.counters[p.counter]++
                gServerObject.notify('countersChanged',{type : p.counter, delta: 1})
              else
                @counters[p.counter]++
                @notify('countersChanged',{type : p.counter})
                ret = ret.concat(@syncCounters([], true)).concat(@syncEvent())
            when "updateLeaderboard"
              @counters['worldBoss'][p.counter] = 0 unless @counters['worldBoss'][p.counter]?
              @counters['worldBoss'][p.counter] += p.delta
              helperLib.assignLeaderboard(@, p.boardId)
            when "setValue"
              target = if p.target is 'player' then @ else gServerObject
              doSetProperty(target, p.key, p.value)
            when "rob"
              if p.victim?
                ret = ret.concat(gMiner.rob(p.victim, @, p.value))
    return ret

  isQuestAchieved: (qid) ->
    return false unless @quests[qid]?
    quest = queryTable(TABLE_QUEST, qid, @abIndex)
    for i, c of @quests[qid].counters
      return false if quest.objects[i].count > c
    return true

  claimQuest: (qid) ->
    quest = queryTable(TABLE_QUEST, qid, @abIndex)
    ret = []
    return RET_QuestNotExists unless quest?
    return RET_QuestNotAccepted unless @quests[qid]?
    return RET_QuestCompleted if @quests[qid].complete
    @checkQuestStatues(qid)
    return RET_QuestNotCompleted unless @isQuestAchieved(qid)

    prize = @claimPrize(quest.prize.filter((e) => isClassMatch(@hero.class, e.classLimit)))
    if not prize or prize.length is 0 then return RET_InventoryFull
    ret = ret.concat(prize)

    @questVersion++
    for obj in quest.objects when obj.consume
      switch obj.type
        when QUEST_TYPE_GOLD then ret = ret.concat({NTF: Event_InventoryUpdateItem, arg: {syn:@inventoryVersion, god: @addGold(-obj.count)}})
        when QUEST_TYPE_DIAMOND then ret = ret.concat({NTF: Event_InventoryUpdateItem, arg: {syn:@inventoryVersion, dim: @addDiamond(-obj.count)}})
        when QUEST_TYPE_ITEM then ret = ret.concat(this.removeItem(obj.value, obj.count))

    @log('claimQuest', { id: qid })
    @quests[qid] = {complete: true}
    return ret.concat(@updateQuestStatus())

  checkQuestStatues: (qid) ->
    quest = queryTable(TABLE_QUEST, qid, @abIndex)
    return false unless @quests[qid]? and quest

    for i, objective of quest.objects
      switch objective.type
        when QUEST_TYPE_GOLD then @quests[qid].counters[i] = @gold
        when QUEST_TYPE_DIAMOND then @quests[qid].counters[i] = @diamond
        when QUEST_TYPE_ITEM then @quests[qid].counters[i] = @inventory.filter((e) -> e.id is objective.collect).reduce( ((r,l) -> r+l.count), 0 )
        when QUEST_TYPE_LEVEL then @quests[qid].counters[i] = @createHero().level
        when QUEST_TYPE_POWER then @quests[qid].counters[i] = @createHero().calculatePower()
      if @quests[qid].counters[i] > objective.count then @quests[qid].counters[i] = objective.count

  onEvent: (eventID) ->
    switch eventID
      when 'Equipment' then @createHero()

  queryItemSlot: (item) -> @inventory.queryItemSlot(item)

  getItemAt: (slot) ->
    return @inventory.get(slot)

  getUpgradeSkillInfo: (skillId, type, arg) ->
    switch type
      when 'class'
        return AllClassIDs.reduce((acc, classId) ->
          skillLst = queryTable(TABLE_ROLE, classId)?["availableSkillList"]
          if Array.isArray(skillLst) and skillLst.indexOf(skillId) isnt -1
            acc.push(classId)
          return acc
        ,[])
      when 'cost'
        data = queryTable(TABLE_SKILL,skillId)
        return data.level_upgrage_cost?[arg]
      when 'currentSkillState'
        classIds = @getUpgradeSkillInfo(skillId, 'class')
        return {} unless classIds.length > 0
        if classIds.indexOf(@hero.class) isnt -1
          store = @hero
        else
          store = @heroBase[classIds[0]]
          return {} unless store?
        return {curLevel : store.skill?[skillId]?.level ? 0, store:store}
      
    return {}
          

  upgradeSkill: (skillId) ->
    {curLevel,store} = @getUpgradeSkillInfo(skillId, 'currentSkillState')
    return {ret: RET_ClassNotUnlock} unless curLevel?
    
    costId = @getUpgradeSkillInfo(skillId, 'cost', curLevel)

    return { ret: RET_NothingTodo } unless costId?
    ret = []
    if costId isnt -1
      ret = @claimCost(costId)
      return { ret: RET_NotEnough } unless ret?

    store.skill ?= {}
    store.skill[skillId] ?= {level:0}
    store.skill[skillId].level = curLevel + 1
    @saveDB()
    ret = [@syncHero(true)].concat(ret)
    return {ret:RET_OK,ntf:ret}

  useItem: (slot, opn, prenticeIdx = null)->#opn 时装系统装备卸下时需要
    item = @getItemAt(slot)
    myClass = @hero.class
    return { ret: RET_ItemNotExist } unless item?
    return { ret: RET_RoleClassNotMatch } unless isClassMatch(myClass, item.classLimit)
    @log('useItem', { slot: slot, id: item.id ,pIdx: prenticeIdx})

    switch item.category
      when ITEM_USE
        switch item.subcategory
          when ItemUse_ItemPack
            prize = @claimPrize(item.prize)
            return { ret: RET_InventoryFull } unless prize.length > 0
            ret = @removeItem(null, 1, slot)
            return { ret: RET_OK, ntf: ret.concat(prize) }
          when ItemUse_TreasureChest
            return { ret: RET_NoKey } if item.dropKey? and not @haveItem(item.dropKey)
            prz = @generateReward(queryTable(TABLE_DROP), [item.dropId])
            prize = @claimPrize(prz)
            return { ret: RET_InventoryFull } unless prize.length > 0
            @log('openTreasureChest', {type: 'TreasureChest', id: item.id, prize: prize, drop: e.drop})
            ret = prize.concat(@removeItem(null, 1, slot))
            ret = ret.concat(this.removeItemById(item.dropKey, 1, true)) if item.dropKey?
            return {ret: RET_OK, prize: prz, ntf: ret}
          when ItemUse_Function
            ret = @removeItem(null, 1, slot)
            switch item.function
              when 'recoverEnergy'
                this.costEnergy(-item.argument)
                ret = ret.concat(this.syncEnergy())
            return { ret: RET_OK, ntf: ret }
      when ITEM_EQUIPMENT
        ret = @equipItem(slot,prenticeIdx)
        return { ret: RET_OK, ntf: [ret] }
      when ITEM_RECIPE
        if item.recipeTarget?
          recipe = @itemSynthesis(slot)
          return { ret: recipe.ret } unless recipe.res
          @log('itemSynthesis ret', {type: 'recipe', recipe: recipe})
          ripres = recipe.res
          ripres = ripres.concat(@removeItem(null, 1, slot))
          @log('recipe', {type: 'recipe', id: item.id, recipe: recipe.out})
          return {out:recipe.out, ntf:ripres}
       #if opn? and opn == 1 #USE_ITEM_OPT_EQUIP = 1;
       #  ret = @equipItem(slot)
       #  return { ret: RET_OK, ntf: [ret] }
       #else
       #  if item.recipeTarget?
       #    recipe = @itemSynthesis(slot)
       #    return { ret: recipe.ret } unless recipe.res
       #    @log('itemSynthesis ret', {type: 'recipe', recipe: recipe})
       #    ripres = recipe.res
       #    ripres = ripres.concat(@removeItem(null, 1, slot))
       #    @log('recipe', {type: 'recipe', id: item.id, recipe: recipe.out})
       #    return {out:recipe.out, ntf:ripres}
       #  else if item.recipePrize?
       #    recipe = @itemDecompsite(slot)
       #    return { ret: recipe.ret } unless recipe.ret == RET_OK
       #    @log('deposite ret', {type: 'recipe', recipe: recipe})
       #    @log('recipe', {type: 'recipe', id: item.id, recipe: recipe.out})
       #    return {out:recipe.prize, ntf:recipe.res}
        

    logError({action: 'useItem', reason: 'unknow', catogory: item.category, subcategory: item.subcategory, id: item.id, pIdx: prenticeIdx})
    return {ret: RET_UseItemFailed}

  doAction: (routine) ->
    cmd = new playerCommandStream(routine, this)
    cmd.process()
    return cmd.translate()

  aquireItem: (item,  count, allOrFail,prenticeIdx) ->
    @doAction({id: 'AquireItem', item: item, count: count, allorfail: allOrFail,pIdx:prenticeIdx})

  removeItemById: (id, count, allorfail) ->
    @doAction({id: 'RemoveItem', item: id, count: count, allorfail: allorfail})
  removeItem: (item, count, slot) ->
    @doAction({id: 'RemoveItem', item: item, count: count, slot: slot})

  extendInventory: (delta) -> @inventory.size(delta)

  transformGem: (tarID, count) ->
    cfg = queryTable(TABLE_ITEM, tarID)
    return { ret: RET_TargetNotExists } unless cfg?

    ret = @claimCost(cfg.synthesizeID, count)
    if not ret? then return { ret: RET_InsufficientIngredient }
    ret = ret.concat(@aquireItem(tarID, count))

    return { res: ret }


  #getSlotFreezeInfo: (slot) -> getSlotFreezeInfo(@,slot)

  unequipItem: (slot) ->
    {where, prenticeIdx, idx}= @findEquipRef(slot)
    if where?
      @delEquipRef(idx, prenticeIdx)
    return

  equipItem: (slot, prenticeIdx = null) ->
    #info = @getSlotFreezeInfo(slot)

    item = @getItemAt(slot)
    return { ret: RET_RoleLevelNotMatch } if item.rank? and @createHero().level < item.rank
    ret = {NTF: Event_InventoryUpdateItem, arg: {syn:@inventoryVersion, itm: []}}

    equipment = @getEquipRef(prenticeIdx)
    equip = equipment[item.subcategory]
    tmp = {sid: slot, sta: 0}
    tmp.pIdx = prenticeIdx if prenticeIdx?

    if equip is slot
      @unequipItem(slot)
    else
      if equip?
        @unequipItem(equip)
        ret.arg.itm.push({sid: equip, sta: 0, pIdx : prenticeIdx})
      @addEquipRef(item.subcategory, slot, prenticeIdx)
      if item.extraSlots?
        for v_slot in item.extraSlots
          if equipment[v_slot]?
            ret.arg.itm.push({sid: equipment[v_slot], sta: 0, pIdx: prenticeIdx})
            @unequipItem(equipment[v_slot])
          @addEquipRef(v_slot, slot, prenticeIdx)
      tmp.sta = 1
    ret.arg.itm.push(tmp)
    delete ret.arg.itm if ret.arg.itm.length < 1

    @onEvent('Equipment')
    return ret

  levelUpItem: (slot, prenticeIdx) ->
    item = @getItemAt(slot)
    return { ret: RET_ItemNotExist } unless item?
    return { ret: RET_EquipCantUpgrade } unless item.upgradeTarget? and @createHero().level > item.rank
    if item.getConfig().upgradeId?
      upConfig = queryTable(TABLE_UPGRADE, item.getConfig().upgradeId, @abIndex)
    else
      upConfig = queryTable(TABLE_UPGRADE, item.rank, @abIndex)
    return { ret: RET_EquipCantUpgrade } unless upConfig
    exp = upConfig.xp
    cost = upConfig.cost
    return { ret: RET_EquipCantUpgrade } unless exp? and cost?
    return { ret: RET_InsufficientEquipXp } if item.xp < exp
    return { ret: RET_NotEnoughGold } if this.gold < cost

    @unequipItem(slot)

    @addGold(-cost)
    ret = this.removeItem(null, 1, slot)
    newItem = libItem.createItem(item.upgradeTarget)
    newItem.enhancement = item.enhancement
    ret = ret.concat(this.aquireItem(newItem, 1,null, prenticeIdx))
    eh = newItem.enhancement.map((e) -> {id:e.id, lv:e.level})
    ret = ret.concat({
      NTF: Event_InventoryUpdateItem,
      arg:{
        syn:this.inventoryVersion,
        god:this.gold,
        itm:[{sid: this.queryItemSlot(newItem), stc: 1, eh:eh, xp: newItem.xp}]}})
  
    @log('levelUpItem', { slot: slot, id: item.id, level: item.rank })
  
    if newItem.rank >= 8
      dbLib.broadcastEvent(BROADCAST_ITEM_LEVEL, {who: @name, what: item.id, many: newItem.rank})

    @onEvent('Equipment')
    return { out: {cid: newItem.id, sid: @queryItemSlot(newItem), stc: 1, sta: 1, eh: eh, pIdx:prenticeIdx}, res: ret }

  upgradeItemQuality: (slot) ->
    item = @getItemAt(slot)
    enhance = item.enhancement
    ret = @craftItem(slot)
    newItem = ret.newItem
    if newItem
      newItem.enhancement = enhance
      newItem.xp = item.xp
      newItem.slot = item.slot
      eh = newItem.enhancement.map((e) -> {id:e.id, lv:e.level})
      @inventory.container[slot] = newItem
      ret.res.push({NTF: Event_InventoryUpdateItem, arg: {
        syn:this.inventoryVersion,
        itm:[{sid: @queryItemSlot(newItem), cid: newItem.id, eh:eh, xp: newItem.xp}]
      }})
    return ret

  craftItem: (slot) ->
    recipe = @getItemAt(slot)
    return { ret: RET_NeedReceipt } unless recipe?
    ret = @claimCost(recipe.forgeID)
    if not ret? then return { ret: RET_InsufficientIngredient }
    return { ret: RET_TargetNotExists } unless recipe.forgeTarget?
    newItem = libItem.createItem(recipe.forgeTarget)
    ret = ret.concat({NTF: Event_InventoryUpdateItem, arg:{
      syn: @inventoryVersion,
      god: @gold
    }})
    @log('craftItem', { slot: slot, id: recipe.id })

    if newItem.rank >= 8 then dbLib.broadcastEvent(BROADCAST_CRAFT, {who: @name, what: newItem.id})
    return { out: { type: PRIZETYPE_ITEM, value: newItem.id, count: 1}, res: ret, newItem: newItem }

  enhanceItem: (itemSlot) ->
    equip = @getItemAt(itemSlot)
    return { ret: RET_ItemNotExist } unless equip
    equip.enhancement[0] = { id: equip.enhanceID, level: -1 } unless equip.enhancement[0]?
    level = equip.enhancement[0].level + 1
    return { ret: RET_EquipCantUpgrade } unless level < 40 and equip.enhanceID?
    return { ret: RET_EquipCantUpgrade } unless equip.quality? and level < 8*(equip.quality+1)
    enhance = queryTable(TABLE_ENHANCE, equip.enhanceID)
    ret = @claimCost(enhance.costList[level])
    if not ret? then return { ret: RET_ClaimCostFailed }

    equip.enhancement[0].level = level

    @log('enhanceItem', { itemId: equip.id, level: level, itemSlot: itemSlot })
  
    @onEvent('Equipment')

    if level >= 32
      dbLib.broadcastEvent(BROADCAST_ENHANCE, {who: @name, what: equip.id, many: level+1})
  
    eh = equip.enhancement.map((e) -> {id:e.id, lv:e.level})
    ret = ret.concat({NTF: Event_InventoryUpdateItem, arg: {syn:this.inventoryVersion, itm:[{sid: itemSlot, eh:eh}]}})
    return { out: {cid: equip.id, sid: itemSlot, stc: 1, eh: eh, xp: equip.xp}, res: ret }

  sellItem: (slot) ->
    if @isEquiped(slot) then return { ret: RET_EquipedItemCannotBeSold }

    item = @getItemAt(slot)
    return { ret: RET_ItemNotExist } unless item?
    count = item.count
    if item?.transPrize or item?.sellprice
      ret = @removeItem(null, null, slot)

      if item?.transPrize
        ret = ret.concat(@claimPrize(item.transPrize))
      else if item?.sellprice
        @addGold(item.sellprice*count)
    
      @log('sellItem', { itemId: item.id, price: item.sellprice, count: count, slot: slot })
      return { ret: RET_OK, ntf: [{ NTF: Event_InventoryUpdateItem, arg: {syn:this.inventoryVersion, 'god': this.gold} }].concat(ret)}
    else
      return { ret: RET_ItemSoldFailed }

  haveItem: (itemID) ->
    itemConfig = queryTable(TABLE_ITEM, itemID, @abIndex)
    return false unless itemConfig?

    matchedItems = this.inventory.filter((item) -> item? and item.id is itemID)
    if matchedItems.length > 0
      return true
    else if itemConfig.upgradeTarget
      return this.haveItem(itemConfig.upgradeTarget)
    else
      return false

  updateQuest: (quests) ->
    for qid, qst of quests
      continue unless qst?.counters? and @quests[qid]
      quest = queryTable(TABLE_QUEST, qid, @abIndex)
      for k, objective of quest.objects when objective.type is QUEST_TYPE_NPC and qst.counters[k]? and @quests[qid].counters?
        @quests[qid].counters[k] = qst.counters[k]


  getPKReward: (dungeon) ->
    return getPKRewardByDiff(dungeon.PVP_Score_diff, dungeon.PVP_Score_origin)

  updatePkInof: (dungeon) ->
    if dungeon.PVP_Pool?
      myName = @name
      rivalName = dungeon.PVP_Pool[0].nam
      if dungeon.result is DUNGEON_RESULT_WIN
        dbLib.saveSocre(myName, rivalName, (err, result) ->
        )
  whisper: (name, message, callback) ->
    myName = this.name
    dbLib.deliverMessage(
      name,
      { type: Event_ChatInfo, src: myName, mType: MESSAGETYPE_WHISPER, text: message, timeStamp: (new Date()).valueOf(), vip: @vipLevel(), class: @hero.class, power: @battleForce },
      (err, result) =>
        @log('whisper', { to : name, err : err, text : message })

        if callback then callback(err, result)
      )

  inviteFriend: (name, id, callback) ->
    msg = {type:  MESSAGE_TYPE_FriendApplication, name: this.name}
    async.series([
      (cb) ->
        if id?
          dbLib.getPlayerNameByID(id, gServerName, (err, theName) ->
            if theName then name = theName
            cb(err)
          )
        else
          cb(null)
      (cb) => if name is @name then cb(new Error(RET_CantInvite)) else cb (null),
      (cb) => if @contactBook? and @contactBook.book.indexOf(name) isnt -1 then cb(new Error(RET_OK)) else cb (null),
      (cb) -> dbLib.playerExistenceCheck(name, cb),
      (cb) -> dbLib.deliverMessage(name, msg, cb, null, true),
    ], (err, result) ->
      err = new Error(RET_OK) unless err?
      if callback then callback(err)
    )

  removeFriend: (name) ->
    @log('removeFriend', {tar : name})

    dbLib.removeFriend(this.name, name)
    return RET_OK

  vipOperation: (op) ->
    {level, cfg} = getVip(@rmb)

    switch op
      when 'vipLevel' then return level
      when 'chest_vip' then return cfg?.privilege?.chest_vip ? 0
      when 'ContinuousRaids' then return cfg?.privilege?.ContinuousRaids ? false
      when 'pkCount' then return cfg?.privilege?.pkCount ? 5
      when 'tuHaoCount' then return cfg?.privilege?.tuHaoCount ? 3
      when 'EquipmentRobbers' then return cfg?.privilege?.EquipmentRobbers ? 3
      when 'EvilChieftains' then return cfg?.privilege?.EvilChieftains ? 3
      when 'blueStarCost' then return cfg?.privilege?.blueStarCost ? 0
      when 'goldAdjust' then return cfg?.privilege?.goldAdjust ? 0
      when 'expAdjust' then return cfg?.privilege?.expAdjust ? 0
      when 'wxpAdjust' then return cfg?.privilege?.wxpAdjust ? 0
      when 'energyLimit' then return (cfg?.privilege?.energyLimit ? 0) + ENERGY_MAX
      when 'freeEnergyTimes' then return cfg?.privilege?.freeEnergyTimes ? 0
      when 'dayEnergyBuyTimes' then return cfg?.privilege?.dayEnergyBuyTimes ? 4
      when 'energyPrize' then return cfg?.privilege?.energyPrize ? 1
      when 'appendRevive' then return cfg?.privilege?.appendRevive ? 0
      when 'reviveBasePrice' then return cfg?.privilege?.reviveBasePrice ? 60
      when 'challengeCoin' then return cfg?.privilege?.challengeCoin ? 4

  vipLevel: () -> @vipOperation('vipLevel')
  getBlueStarCost: () -> @vipOperation('blueStarCost')
  goldAdjust: () -> @vipOperation('goldAdjust')
  expAdjust: () -> @vipOperation('expAdjust')
  wxpAdjust: () -> @vipOperation('wxpAdjust')
  energyLimit: () -> @vipOperation('energyLimit')
  getPrivilege: (name) -> @vipOperation(name)
  getTotalPkTimes: () -> return @getPrivilege('pkCount')
  getAddPkCount: () ->
    @counters.addPKCount ?= 0
    return @counters.addPKCount

  getReviveLimit: (reviveLimit) ->
      return -1 unless reviveLimit? and  reviveLimit isnt -1
      return reviveLimit + @vipOperation('appendRevive')
  getPkCoolDown: () ->
    if @counters.addPKCount? and @counters.addPKCount > 0
      return 0
    @timestamp.pkCoolDown ?= 0
    timePass = libTime.diff(currentTime(), @timestamp.pkCoolDown).asSeconds()
    if timePass >= PK_COOLDOWN
      return 0
    else
      return (PK_COOLDOWN - timePass)

  clearCDTime: () ->
    @timestamp.pkCoolDown = 0

  addPkCount: (count) ->
    @counters.addPKCount = 0 unless @counters.addPKCount?
    @counters.addPKCount++

  claimPkPrice: (callback) ->
    me = @
    helperLib.getPositionOnLeaderboard(helperLib.LeaderboardIdx.Arena, @name, 0, 0, (err, result) ->
      prize = arenaPirze(result.position + 1 )
      ret = me.claimPrize(prize)
      callback(ret)
    )

  hireFriend: (name, handler) ->
    return false unless handler?
    return handler(RET_FriendNotExists) if this.contactBook.book.indexOf(name) is -1

    myIndex = @mercenary.reduce((r, e, index) ->
      return index if e.name is name
      return r
    , -1)

    @log('hireFriend', { tar : name })

    if myIndex != -1
      dbLib.incrBluestarBy(name, @getBlueStarCost(), wrapCallback(this,(err, left) ->
        @mercenary.splice(myIndex, 1)
        this.requireMercenary(handler)
      ))
    else
      dbLib.incrBluestarBy(name, -@getBlueStarCost(), wrapCallback(this,(err, left) ->
        getPlayerHero(name, wrapCallback(this, (err, heroData) ->
          #hero = new Hero(heroData)
          hero = heroData
          hero.isFriend = true
          hero.leftBlueStar = left
          @mercenary.splice(0, 0, hero)
          this.requireMercenary(handler)
        ))
      ))

  getCampaignState: (campaignName) ->
    return null unless @campaignState
    if not @campaignState[campaignName]?
      if campaignName is 'Charge' or campaignName is 'DuanwuCharge'
        @campaignState[campaignName] = {}
      else
        @campaignState[campaignName] = 0
    return @campaignState[campaignName]

  setCampaignState: (campaignName, val) ->
    return @campaignState[campaignName] = val

  getCampaignConfig: (campaignName) ->
    cfg = queryTable(TABLE_CAMPAIGN, campaignName, @abIndex)
    if cfg?
      #check validate
      if cfg.date? and moment(cfg.date).format('YYYYMMDD') - moment().format('YYYYMMDD') < 0 then return { config: null }
      if cfg.duration?
        duration = cfg.duration
        nowTime = moment()
        return {config:null} unless isInRangeTime(duration, nowTime)
      if @getCampaignState(campaignName)? and @getCampaignState(campaignName) is false then return { config: null }
      if @getCampaignState(campaignName)? and cfg.level? and @getCampaignState(campaignName) >= cfg.level.length then return { config: null }
      if cfg.generation? and @getCampaignState(campaignName) >= cfg.generation.value then return {config: null}
      if campaignName is 'LevelUp' and cfg.timeLimit*1000 <= moment()- @creationDate then return { config: null }
    else
      return { config: null }

    #gen award info
    if cfg.level?
      return { config: cfg, level: cfg.level[@getCampaignState(campaignName)] }
    else if cfg.objective?
      return { config: cfg, level: cfg.objective }
    else if cfg.generation?
      return {config: cfg, level: cfg.generation.awards}
    else
      return {config: cfg}

  onCampaign: (state, data) ->
    reward = [] #deliver by message
    prize =[] # claim prize
    switch state
      when 'Friend'
        { config, level } = @getCampaignConfig('Friend')
        if config? and level? and @contactBook.book.length >= level.count
          reward.push({cfg: config, lv: level})
          @setCampaignState('Friend', 1)
      when 'RMB'
        { config, level } = @getCampaignConfig('Charge')
        if config? and level? and data?.rmb?
          rmb = data.rmb
          state = @getCampaignState('Charge')
          o = level[rmb]
          if not state[rmb] and o?
            reward.push({cfg: config, lv: o})
            state[rmb] = true
            @setCampaignState('Charge', state)

        { config, level } = @getCampaignConfig('DuanwuCharge')
        if config? and level? and data?.rmb?
          rmb = data.rmb
          state = @getCampaignState('DuanwuCharge')
          o = level[rmb]
          if not state[rmb] and o?
            reward.push({cfg: config, lv: o})
            state[rmb] = true
            @setCampaignState('DuanwuCharge', state)

        { config, level } = @getCampaignConfig('TotalCharge')
        if config? and level? and @rmb >= level.count
          if @getCampaignState('TotalCharge')?
            @setCampaignState('TotalCharge', @getCampaignState('TotalCharge')+1)
          else
            @setCampaignState('TotalCharge', 0)
          reward.push({cfg: config, lv: level})

        { config, level } = @getCampaignConfig('FirstCharge')
        if config? and level? and data?.idx?
          rmb = data.idx
          if level[rmb]?
            reward.push({cfg: config, lv: level[rmb]})
            @setCampaignState('FirstCharge', false)
      when 'Level'
        { config, level } = @getCampaignConfig('LevelUp')
        if config? and level? and @createHero().level >= level.count
          if @getCampaignState('LevelUp')?
            @setCampaignState('LevelUp', @getCampaignState('LevelUp')+1)
          else
            @setCampaignState('LevelUp', 1)
          reward.push({cfg: config, lv: level})
      when 'Stage'
        { config, level } = @getCampaignConfig('Stage')
        if config? and level? and data is level.count
          @setCampaignState('Stage', @getCampaignState('Stage')+1)
          reward.push({cfg: config, lv: level})
      when 'BattleForce'
        { config, level } = @getCampaignConfig('BattleForce')
        if config? and level? and @createHero().calculatePower() >= level.count
          @setCampaignState('BattleForce', @getCampaignState('BattleForce')+1)
          reward.push({cfg: config, lv: level})
      when 'timeLimitAward'
        { config,level} = @getCampaignConfig('timeLimitAward')
        if(config?)
          generation = config.generation.value
          @setCampaignState('timeLimitAward',generation)
          prize = level

    for r in reward
      #console.log('reward', JSON.stringify(reward))
      dbLib.deliverMessage(@name, { type: MESSAGE_TYPE_SystemReward, src: MESSAGE_REWARD_TYPE_SYSTEM, prize: r.lv.award, tit: r.cfg.mailTitle, txt: r.cfg.mailBody })
    {prize:prize, sync:@claimPrize(prize)}

  updateFriendInfo: (handler) ->
    dbLib.getFriendList(@name, wrapCallback(this, (err, book) ->
      @contactBook = book
      @onCampaign('Friend')
      async.map(@contactBook.book,
        (contactor, cb) -> getPlayerHero(contactor, cb),
        (err, result) ->
          ret = {
            NTF: Event_FriendInfo,
            arg: {
              fri: result.map(getBasicInfo),
              cap: book.limit,
              clr: true
            }
          }
          handler(err, ret)
        )
    ))

  operateMessage: (type, id, operation, callback) ->
    me = this
    async.series([
      (cb) =>
        if @messages? and @messages.length > 0
          cb(null)
        else
          @fetchMessage(cb)
      ,
      (cb) =>
        message = me.messages
        @messages = []
        if id?
          message = message.filter((m) -> return m? and m.messageID is id )
          @messages = message.filter((m) -> return m.messageID isnt id )
        if type?
          message = message.filter((m) -> return m? and m.type is type )
          @messages = message.filter((m) -> return m.type isnt type )

        err = null
        cb(err, message)
    ], (err, results) =>
      friendFlag = false
      async.map(results[1], (message, cb) =>
        switch message.type
          when MESSAGE_TYPE_FriendApplication
            if operation is NTFOP_ACCEPT
              dbLib.makeFriends(me.name, message.name, (err) -> cb(err, []))
            else
              cb(null, [])
            friendFlag = true
            @log('operateMessage', { type : 'friend', op : operation })
            dbLib.removeMessage(@name, message.messageID)
          when MESSAGE_TYPE_SystemReward
            ret = @claimPrize(message.prize)
            @log('operateMessage', { type : 'reward', src : message.src, prize : message.prize, ret: ret })
            if ret? and ret.length > 0
              cb(null, ret)
              dbLib.removeMessage(@name, message.messageID)
            else
              cb(RET_InventoryFull, ret)
      , (err, result) =>
        if friendFlag then return @updateFriendInfo(callback)
        if callback then callback(err, result.reduce( ((r, l) -> if l then return r.concat(l) else return r), [] ))
      )
    )

  fetchMessage: (callback, allMessage = false) ->
    myName = this.name
    me = this
    dbLib.fetchMessage(myName, wrapCallback(this, (err, messages) ->
      @messages = [] unless @messages?
      if allMessage
        newMessage = messages
      else
        newMessage = playerMessageFilter(this.messages, messages, myName)
      this.messages = this.messages.concat(newMessage)
      newMessage = newMessage.filter( (m) -> m? )
      async.map(newMessage,
        (msg, cb) ->
          if msg.type == MESSAGE_TYPE_SystemReward
            ret = {
              NTF : Event_SystemReward,
              arg : {
                sid : msg.messageID,
                typ : msg.src,
                prz : msg.prize
              }
            }
            if msg.tit then ret.arg.tit = msg.tit
            if msg.txt then ret.arg.txt = msg.txt
            cb(null, ret)
          else if msg.type == Event_ChatInfo
            dbLib.removeMessage(myName, msg.messageID)
            cb(null, {
              NTF : Event_ChatInfo,
              arg : {
                typ: msg.mType,
                src: msg.src,
                txt: msg.text,
                tms: Math.floor(msg.timeStamp/1000),
                vip: msg.vip,
                cla: msg.class,
                pow: msg.power
              }
            })
          else if msg.type is MESSAGE_TYPE_FriendApplication
            getPlayerHero(msg.name, wrapCallback((err, hero) ->
              cb(err, {
                NTF: Event_FriendApplication,
                arg: {
                  sid: msg.messageID,
                  act: getBasicInfo(hero)
                }
              })
            ))
          else if msg.type is MESSAGE_TYPE_ChargeDiamond
            dbLib.removeMessage(me.name, msg.messageID)
            me.handlePayment(msg, cb)
          else if msg.type is MESSAGE_TYPE_InvitationAccept
            me.invitee[msg.name] = {tot: 0, cur: 0}
            dbLib.removeMessage(me.name, msg.messageID)
            me.saveDB()
            cb(null, [])
          else if msg.type is MESSAGE_TYPE_InvitationAwardUpdate
            _err = (me.updateInvitationAward({name:msg.name, type:'add', gem:msg.gem})).err
            dbLib.removeMessage(me.name, msg.messageID)
            cb( _err, [])
          else
            cb(err, msg)
        , (err, msg) ->
          ret = []
          for m in msg
            if Array.isArray(m)
              ret = ret.concat(m)
            else
              ret.push(m)
          callback(err, ret) if callback?
      )
    ))

  completeStage: (stage, level) ->
    thisStage = queryTable(TABLE_STAGE, stage, @abIndex)
    if this.stage[stage] == null || thisStage == null then return []
    ret = this.changeStage(stage,  STAGE_STATE_PASSED, level)
    @onCampaign('Stage')
    return ret.concat(this.updateStageStatus(level))

  # teamType :[withoutPrentice| withPrentice| onlyPrentice]
  requireMercenary: (callback, teamType = 'withoutPrentice') ->
    me = @
    getBlackWhiteListDepandOnContacBook = () =>
      validateFriend = []
      @counters.friendHireTime ?={}
      filtedName = [@name].concat(@mercenary.map((m) -> m.name))
      if @contactBook?
        filtedName = filtedName.concat(@contactBook.book)
        validateFriend = underscore.sample(@contactBook.book.filter((name) =>
          times = @counters.friendHireTime[name]
          res = not times? or times < 1
          return res
        ),5)
      return {filtedName: filtedName, validateFriend: validateFriend }


    if not callback then return

    if teamType is 'onlyPrentice'
      @mercenary = me.prenticeLst.getBasicInfo()
      callback(@mercenary.map( (h) -> new Hero(h)))
      return


    if @mercenary.length >= MERCENARYLISTLEN
      callback(@mercenary.map( (h) -> new Hero(h)))
    else
      #// TODO: range  & count to config

      {filtedName,validateFriend} = getBlackWhiteListDepandOnContacBook()
      getMercenaryMember(@name, 5, 30, 1, filtedName,validateFriend
        (err, heroData) ->
          if teamType is 'withPrentice'
            heroData = me.prenticeLst.getBasicInfo().concat(heroData)
          if heroData
            me.mercenary = me.mercenary.concat(heroData.filter((e) -> e?))
            me.mercenary = underscore.uniq(me.mercenary,false, (obj) -> obj.name)
            me.requireMercenary(callback, teamType)
          else
            callback(null)
      )

  recycleItem: (slot) ->
    item = @getItemAt(slot)
    return { ret: RET_ItemNotExist } unless item?
    if item.recipePrize?
      recipe = @itemDecompsite(slot)
      return { ret: recipe.ret } unless recipe.ret == RET_OK
      @log('deposite ret', {type: 'recipe', recipe: recipe})
      @log('recipe', {type: 'recipe', id: item.id, recipe: recipe.out})
      return {out:recipe.prize, ntf:recipe.res}
  # recyclableEnhance = queryTable(TABLE_CONFIG, 'Global_Recyclable_Enhancement', @abIndex)
  # recycleConfig = queryTable(TABLE_CONFIG, 'Global_Recycle_Config', @abIndex)
  # item = @getItemAt(slot)
  # for k, equip of @equipment when equip is slot
  #   delete @equipment[k]
  #   break
  # ret = []
  # try
  #   if item is null then throw RET_ItemNotExist
  #   xp = helperLib.calculateTotalItemXP(item) * 0.8
  #   ret = ret.concat(@removeItem(null, null, slot))
  #   reward = item.enhancement.map((e) ->
  #     if recyclableEnhance.indexOf(e.id) != -1
  #       cfg = recycleConfig[e.level]
  #       return {
  #         type : PRIZETYPE_ITEM,
  #         value : queryTable(TABLE_CONFIG, 'Global_Enhancement_GEM_Index', @abIndex)[e.id],
  #         count : cfg.minimum + rand() % cfg.delta
  #       }
  #     else
  #       return null
  #   )
  #   if queryTable(TABLE_CONFIG, 'Global_Material_ID').length > item.quality
  #     reward.push({
  #       type: PRIZETYPE_ITEM,
  #       value: queryTable(TABLE_CONFIG, 'Global_Material_ID')[item.quality],
  #       count: 2 + rand() % 2
  #     })
  #   reward = reward.filter( (e) -> return e? )
  #   #reward.push({
  #   #  type: PRIZETYPE_ITEM,
  #   #  value: queryTable(TABLE_CONFIG, 'Global_WXP_BOOK'),
  #   #  count: Math.floor(xp/100)
  #   #})
  #   rewardEvt = this.claimPrize(reward)
  #   ret = ret.concat(rewardEvt)
  # catch err
  #   logError(err)

  # return {out: reward, res: ret}

  combineItem: (slot, gemSlot) ->
    equip = @getItemAt(slot)
    gem = @getItemAt(gemSlot)
    return { ret: RET_ItemNotExist } unless gem and equip
    retRM = @inventory.removeItemAt(gemSlot, 1, true)
    if retRM
      equip.installEnhancement(gem)
      return { res: [] }
    else
      return { ret: RET_NoEnhanceStone }

  injectWXP: (slot, bookSlot) ->
    equip = @getItemAt(slot)
    book = @getItemAt(bookSlot)
    return { ret: RET_ItemNotExist } unless equip and book
    retRM = @inventory.removeItemAt(bookSlot, 1, true)
    if retRM
      equip.xp += book.wxp
      ret = @doAction({id: 'ItemChange', ret: retRM, version: this.inventoryVersion})
      ev = {NTF: Event_InventoryUpdateItem, arg: { itm: [{ cid: equip.id, sid: @queryItemSlot(equip), stc: 1, xp: equip.xp }] } }
      ret.push(ev)
      return { res: ret }
    else
      return { ret: RET_NoEnhanceStone }

  replaceMercenary: (id, handler) ->
    me = this
    myName = @name
    # TODO: range  & count to config
    filtedName = [@name]
    filtedName = filtedName.concat(@mercenary.map((m) -> m.name))
    filtedName = filtedName.concat(@contactBook.book) if @contactBook?.book?
    getMercenaryMember(myName , 1, 30, 1, filtedName,[]
      (err, heroData) ->
        if heroData
          me.mercenary.splice(id, 1, heroData[0])
        else
          heroData = me.mercenary[id]
        handler(heroData[0])
      )

  updateMercenaryInfo: (isLogin) ->
    newBattleForce = @createHero().calculatePower()

    if newBattleForce != @battleForce
      updateMercenaryMember(@battleForce, newBattleForce, this.name)
      @battleForce = newBattleForce

    if isLogin
      addMercenaryMember(@battleForce, this.name)

  #//////////////////////////// Version Control
  syncFriend: (forceUpdate) ->
    #TODO

  syncBag: (forceUpdate) ->
    bag = this.inventory
    items = bag.container
      .map(wrapCallback(this, (e, index) =>
        return null unless e? and bag.queryItemSlot(e)?
        slot = bag.queryItemSlot(e)
        ret = {sid: slot, cid: e.id, stc: e.count}

        if e.xp? then ret.xp = e.xp

        {where, prenticeIdx, idx}= @findEquipRef(slot)
        if where?
          ret.sta = 1
          ret.pIdx = prenticeIdx if prenticeIdx?

        if e.enhancement
          ret.eh = e.enhancement.map((e) -> {id:e.id, lv:e.level})

        if e.date
          ret.ts = e.date

        return ret
      )).filter((e) -> e!=null)

    ev = {NTF: Event_InventoryUpdateItem, arg: { cap: bag.limit, dim: this.diamond, god: this.gold, mst:this.masterCoin, syn: this.inventoryVersion, itm: items } }
    if forceUpdate then ev.arg.clr = true
    return ev

  syncStage: (forceUpdate) ->
    stg = []
    for k, v of this.stage
      if this.stage[k]
        cfg = queryTable(TABLE_STAGE, k, @abIndex)
        if not cfg?
          delete @stage[k]
          continue
        chapter = cfg.chapter
        if this.stage[k].level?
          stg.push({stg:k, sta:this.stage[k].state, chp:chapter, lvl:this.stage[k].level})
        else
          stg.push({stg:k, sta:this.stage[k].state, chp:chapter})

    ev = {NTF : Event_UpdateStageInfo, arg: {syn:this.stageVersion, stg:stg}}
    if forceUpdate then ev.arg.clr = true
    return ev

  syncEnergy: (forceUpdate) ->
    this.costEnergy()
    return {
      NTF:Event_UpdateEnergy,
      arg : {
        eng: @energy,
        pxp: @playerXp,
        tim: Math.floor(@energyTime.valueOf() / 1000)
      }
    }

  syncHero: (forceUpdate) ->
    ev = {
      NTF:Event_RoleUpdate,
      arg:{
        syn:this.heroVersion,
        act:getBasicInfo(@createHero())
      }
    }
    ev.arg.act.notMirror = true
    if forceUpdate then ev.arg.clr = true
    
    return ev

  syncPrentice: (forceUpdate) ->
    @prenticeLst.syncPrentice()

  syncVipData: (forceUpdate) ->
    vipOp = [
      "freeEnergyTimes", "dayEnergyBuyTimes", "energyPrize",
      "reviveBasePrice", "appendRevive"
    ].reduce((acc, opName) =>
      acc[opName] = @vipOperation(opName)
      return acc
    ,{})

    return {
      NTF:Event_RoleUpdate,
      arg:{
        act:{
          vip:@vipLevel(),
          vipOp:vipOp
        }
      }
    }
  syncDungeon: (forceUpdate) ->
    dungeon = this.dungeon
    if dungeon == null then return []
    ev = {
      NTF:Event_UpdateDungeon,
      arg:{
        pat:this.team,
        stg:dungeon.stage
      }
    }
    if forceUpdate then ev.arg.clr = true

    return ev

  syncCampaign: (forceUpdate) ->
    all = queryTable(TABLE_CAMPAIGN)
    ret = { NTF: Event_CampaignUpdate, arg: {act: [], syn: 0}}
    for campaign, cfg of all when cfg.show
      { config, level } = @getCampaignConfig(campaign)
      if not config? then continue
      r = {
        title: config.title,
        desc: config.description,
        banner: config.banner
      }
      r.date = config.dateDescription if config.dateDescription?
      r.duration = config.durationDesc if config.durationDesc?
      r.poster = config.poster if config.poster?
      r.type = config.type if config.type?
      r.prz = level.award if level?.award
      ret.arg.act.push(r)
    return [ret]

  syncFlags: (forceUpdate) ->
    arg = {
      clr: true
    }
    for key, val of @flags
      arg[key] = val
    return {
      NTF: Event_UpdateFlags,
      arg: arg
    }

  syncCounters: (keys, forceUpdate) ->
    ret =[]
    if keys?
      ret = underscore.pick(@counters, keys)
    else
      ret = @counters

    return  {
      NTF: Event_UpdateCounters,
      arg:ret
    }

  syncQuest: (forceUpdate) ->
    ret = packQuestEvent(@quests, null, this.questVersion)
    if forceUpdate then ret.arg.clr = true
    return ret

  notifyVersions: () ->
    translateTable = {
      inventoryVersion : 'inv',
      heroVersion : 'act',
      #//dungeonVersion : 'dgn',
      stageVersion : 'stg',
      questVersion : 'qst',
      prenticeVersion : 'pre',
    }

    versions = grabAndTranslate(this, translateTable)
    return {
      NTF : Event_SyncVersions,
      arg :versions
    }

  getFragment: (type,count) ->
    @counters.fragmentTimes ?= []
    @timestamp.fragmentTime ?= []
    @counters.totalFragTimes = [] unless @counters.totalFragTimes
    @counters.totalFragTimes[type] = 1 unless @counters.totalFragTimes[type]
    @counters.fragmentTimes[type] ?= 0
    @timestamp.fragmentTime[type] ?= "2014-10-01"
    fragInterval = [{"value":5,"unit":"minite"},{"value":24,"unit":"hour"}]
    hiGradeTimesFrag = [10,10]
    fragCost = {"1":30,"10":290}

    cfg = queryTable(TABLE_FRAGMENT)
    fragInterval[type] = cfg[type].interval
    hiGradeTimesFrag[type] = cfg[type].basic_times

    fragCost = cfg[type].diamond
    dis = @getDiffTime(@timestamp.fragmentTime[type],currentTime(),fragInterval[type].unit)
    if fragCost[+count]? then diamondCost = fragCost[+count]
    else diamondCost = fragCost["1"] * count
    console.log('diamondCost=', diamondCost)
    switch type
      when 0
        if dis >= fragInterval[type].value
          @timestamp.fragmentTime[type] = currentTime()

    evt = []
    prz = []
    if diamondCost > 0
      if @addDiamond(-diamondCost)
        evt.push({NTF: Event_InventoryUpdateItem, arg: {syn: @inventoryVersion, dim: @diamond}})
      else
        return {ret: RET_NotEnoughDiamond}

    for i in [0..count-1]
      if @counters.fragmentTimes[type] < hiGradeTimesFrag[type]
        basicPrize = @getFragPrizeTable(type,'basic_prize')
        dprint('basicPrize=', basicPrize)
        prz = prz.concat(generatePrize(basicPrize, [0..basicPrize.length-1]))
        @counters.fragmentTimes[type]++
      else
        advancedPrize = @getFragPrizeTable(type,'advanced_prize')
        dprint('advancedPrize=', advancedPrize)
        prz = prz.concat(generatePrize(advancedPrize, [0..advancedPrize.length-1]))
        @counters.fragmentTimes[type] = 0
      @counters.totalFragTimes[type]++

    prize = @claimPrize(prz)
    dprint('claimPrize prize:', prize)
    console.log('prz=', prz)
    if prize.length <= 0
      @addDiamond(diamondCost)
      return { ret: RET_InventoryFull }
    prize = prize.concat(evt)
    @log('lottery', {type: 'lotteryFragment', prize: prize})

    @counters.buyTreasureTimes ?= 0
    @counters.buyTreasureTimes += count
    @notify('onBuyTreasures')
    return {prize: prz, res: prize, ret: RET_OK}

  getFragTimeCD: (type) ->
    @counters.fragmentTimes = [] unless @counters.fragmentTimes
    @timestamp.fragmentTime = [] unless @timestamp.fragmentTime
    @counters.fragmentTimes[type] = 0 unless @counters.fragmentTimes[type]
    @timestamp.fragmentTime[type] = "2014-10-01" unless @timestamp.fragmentTime[type]
    fragInterval = [{"value":5,"unit":"minite"},{"value":24,"unit":"hour"}]
    fragInterval[type] = queryTable(TABLE_FRAGMENT)[type].interval
    freeFragCD = 0
    switch fragInterval[type].unit
      when 'second' then freeFragCD = fragInterval[type].value
      when 'minite' then freeFragCD = fragInterval[type].value*60
      when 'hour' then freeFragCD = fragInterval[type].value*3600
      when 'day' then freeFragCD = fragInterval[type].value*24*3600
    dis = @getDiffTime(@timestamp.fragmentTime[type],currentTime(),'second')
    if freeFragCD <= 0 or freeFragCD - dis <= 0
      return 0
    else
      return freeFragCD - dis

  getFragPrizeTable: (type, table) ->#table="basic_prize" or "advanced_prize"
    cfg = queryTable(TABLE_FRAGMENT)
    return cfg[type][table] unless cfg[type].advanced_option?
    @log('@counters.totalFragTimes', {type: type, totalFragTimes: @counters.totalFragTimes[type]})
    for e, h of cfg[type].advanced_option
      #return cfg[type][table] unless h[table]?
      continue unless h[table]?
      if @match_dateinterval(h.dateInterval,libTime.moment()) and @match_countvalue(h,type)
        return h[table]
      # for k, v of h.count_value
      #   switch h.condition
      #     when 'less'
      #       if @counters.totalFragTimes[type] < v
      #         return h[table]
      #     when 'equal'
      #       if @counters.totalFragTimes[type] == v
      #         return h[table]
      #     when 'more'
      #       if @counters.totalFragTimes[type] > v
      #         return h[table]
      #     when 'interval'
      #       if @counters.totalFragTimes[type] % v == 0
      #         return h[table]
    return cfg[type][table]

  match_dateinterval: (scheme, date) ->
    return true unless scheme? and scheme.startDate? and scheme.interval?
    for k of scheme.startDate
      for x of scheme.startDate[k].date
        sttime = libTime.moment([scheme.startDate[k].year, scheme.startDate[k].month,scheme.startDate[k].date[x],0,0,0,0])
        console.log('match_dateinterval sttime=', sttime._d)
        console.log('match_dateinterval date=', date._d)
        days = Math.abs(diffDate(sttime, date))#date sttime为moment
        #days = subtime.asDays()
        console.log('match_dateinterval days=', days)
        console.log('match_dateinterval interval=', scheme.interval)
        if scheme.interval > 0 and days % scheme.interval == 0
          return true
        else if scheme.interval == 0 and days == 0
          return true
    return false
    #return true

  match_countvalue: (scheme, type) ->
    return true unless scheme.condition? and scheme.count_value?
    for k, v of scheme.count_value
      switch scheme.condition
        when 'less'
          if @counters.totalFragTimes[type] < v
            return true
        when 'equal'
          if @counters.totalFragTimes[type] == v
            return true
        when 'more'
          if @counters.totalFragTimes[type] > v
            return true
        when 'interval'
          if v > 0 and @counters.totalFragTimes[type] % v == 0
            return true
    return false

  itemSynthesis: (slot) ->
    recipe = @getItemAt(slot)
    return { ret: RET_ItemNotExist } unless recipe?
    ret = @claimCostWithInsead(recipe.recipeCost)#@claimCost
    if not ret? then return { ret: RET_InsufficientIngredient }
    return { ret: RET_Unknown } unless recipe.recipeTarget?
    newItem = libItem.createItem(recipe.recipeTarget)
    ret = ret.concat(@aquireItem(newItem))
    @log('itemSynthesis', { slot: slot, id: recipe.id })
    return { out: { type: PRIZETYPE_ITEM, value: newItem.id, count: 1}, res: ret }

  itemDecompsite: (slot) ->
    recipe = @getItemAt(slot)
    return { ret: RET_ItemNotExist } unless recipe?
    #prz = @claimPrize(recipe.recipePrize)
    @log('itemDecompsite', { recipeId: recipe.recipePrize })
    #if Array.isArray(recipe.recipePrize)
    #  recipePrize = recipe.recipePrize
    #else
    #  recipePrize = queryTable(TABLE_DROP)[recipe.recipePrize]
    recipePrize = queryTable(TABLE_DROP)[recipe.recipePrize]
    dprint('itemDecompsite recipePrize', recipePrize)
    prz = generatePrize(recipePrize, [0..recipePrize.length-1])
    prize = @claimPrize(prz)
    dprint('itemDecompsite prz=', prz)
    dprint('itemDecompsite prize=', prize)
    if prize.length <= 0
      return { ret: RET_InventoryFull }

    ret = prize.concat(@removeItem(null, 1, slot))
    @log('itemDecompsite', { slot: slot, id: recipe.id })
    return { prize: prz, res: ret, ret: RET_OK }

  getDiffTime: (from, to, type) ->
    duration = libTime.diff(to, from)
    switch type
      when 'second' then return duration.asSeconds()
      when 'minite' then return duration.asMinutes()
      when 'hour' then return duration.asHours()
      when 'day' then return duration.asDays()

  claimCostWithInsead: (costId) ->
    recipeCost = queryTable(TABLE_COSTS)[costId].material
    dprint('claimCostWithInsead recipeCost', recipeCost)
    material = []
    for e, h of recipeCost
      itemCost = @analysis(h)
      dprint('claimCostWithInsead itemCost', itemCost)
      material = material.concat(itemCost)
    dprint('claimCostWithInsead material', material)
    return @claimCost(material)

  #传人参数：{"type":0,"value":1475,"count":5,
  #详情参见       "instead": {
  #cost表的         "type":0,
  #material         "value":5
  #字段           }
  #         }注意：传入的是对象
  #返回参数，若"value":1475次数足够，返回[{"type":0,"value":1475,"count":5}]
  #否则返回[{"type":0,"value":1475,"count":a},{"type":0,"value":5,"count":b}]
  #注意a+b==5
  analysis: (material) ->
    console.log('analysis material=', JSON.stringify(material))
    switch material.type
      when PRIZETYPE_ITEM
        itemCount = @inventory.getCountById(material.value)
        console.log('analysis itemCount=', itemCount)
        if itemCount >= material.count
          return [{"type":material.type,"value":material.value,"count":material.count}]
        else if material.instead?
          return [{"type":material.type,"value":material.value,"count":itemCount},
                  {"type":material.instead.type,"value":material.instead.value,
                  "count":material.count - itemCount}]
    return [{"type":material.type,"value":material.value,"count":material.count}]

  getFlags: (key) ->
    return @flags[key] if @flags[key]?
    return @memFlags[key] if @memFlags[key]?
    return null

  updateInvitationAward: (config, cb) ->
    return {err:'updateInvitationAward: config is null'} unless config?
    return {err:'updateInvitationAward: config.name is null'} unless config.name?
    return {err:'updateInvitationAward: config.type is null'} unless config.type?
    awdInfo = @inviter[config.name] ? @invitee[config.name]
    return {err:'updateInvitationAward: source player is not my invitee/r'} unless awdInfo?
    ret = {}
    switch config.type
      when 'add'
        config.gem = 0 unless config.gem?
        awdInfo.tot += Number(config.gem)
        awdInfo.cur += Number(config.gem)
      when 'receive'
        ret.prize = [{type:PRIZETYPE_DIAMOND, count: Math.floor(awdInfo.cur)}]
        ret.res = @claimPrize(ret.prize)
        awdInfo.cur = 0
    @saveDB(cb)
    return ret

  getShop: (shopName, refresh) ->
    return {err:'generateShop: shopName null'} unless shopName?
    shopConfig = queryTable(shopName)
    return {err:'generateShop: shopConfig null'} unless shopConfig?
    
    if not refresh
      if @shops[shopName] and shopConfig.resetTime
        creTime = moment(@shops[shopName].createTime || 0)
        curTime = moment()
        if curTime.diff(creTime, 'day', true) < 1
          @shops[shopName].__proto__ = libShop.Shop.prototype
          return @shops[shopName]

    try
      @shops[shopName] = libShop.createShop(shopConfig, @shops[shopName], refresh)
      if refresh is true
        @addMoney(@shops[shopName].refreshCurrentCost.type, -@shops[shopName].refreshCurrentCost.price) if @shops[shopName].refreshCurrentCost?
      @saveDB()
      @shops[shopName].__proto__ = libShop.Shop.prototype
      return @shops[shopName]
    catch err
      logError({type: 'getShop', err: err, cfg: shopConfig})
      return {err: err}



playerMessageFilter = (oldMessage, newMessage, name) ->
  message = newMessage
  messageIDMap = {}
  friendMap = {}
  if oldMessage
    oldMessage.forEach((msg, index) ->
      return false unless msg?
      messageIDMap[msg.messageID] = true
      if msg.type is MESSAGE_TYPE_FriendApplication then friendMap[msg.name] = msg
    )
    message = message.filter((msg) ->
      return false unless msg?
      if messageIDMap[msg.messageID] then return false
      if msg.type == MESSAGE_TYPE_FriendApplication
        if friendMap[msg.name]
          if name then dbLib.removeMessage(name, msg.messageID)
          return false
 
        friendMap[msg.name] = msg
      return true
    )

  return message

#///////////////////////////////// item
createItem = (item) ->
  if Array.isArray(item)
    return ({item: createItem(e.item), count: e.count} for e in item)
  else if typeof item is 'number'
    return libItem.createItem(item)
  else
    return item

itemLib = require('./item')
class PlayerEnvironment extends Environment
  constructor: (@player) ->

  removeItem: (item, count, slot, allorfail) ->
    result = {ret: @player?.inventory.remove(item, count, slot, allorfail), version: @player.inventoryVersion}
    if result.ret isnt []
      @player.unequipItem(slot)
    return result
  translateAction: (cmd) ->
    return [] unless cmd?
    ret = []
    out = cmd.output()
    ret = out if out

    for i, routine of cmd.cmdRoutine
      out = routine?.output()
      ret = ret.concat(out) if out?

    return ret.concat(@translateAction(cmd.nextCMD))

  translate: (cmd) -> @translateAction(cmd)

playerCommandStream = (cmd, player=null) ->
  env = new PlayerEnvironment(player)
  cmdStream = new CommandStream(cmd, null, playerCSConfig, env)
  return cmdStream

playerCSConfig = {
  ItemChange: {
    output: (env) ->
      ret = env.variable('ret')
      return [] unless ret and ret.length > 0
      items = ret.map( (e) ->
        item = env.player.getItemAt(e.slot)
        evt = {sid: Number(e.slot), cid: e.id, stc: e.count}
        if item?.date then evt.ts = item.date
        return evt
      )
      arg = { syn:env.variable('version') }
      arg.itm = items
      return [{NTF: Event_InventoryUpdateItem, arg: arg}]
  },
  UseItem: {
    output: (env) -> return env.player.useItem(env.variable('slot'),null,env.variable('pIdx')).ntf
  },
  AquireItem: {
    callback: (env) ->
      count = env.variable('count') ? 1
      item = createItem(env.variable('item'))
      return showMeTheStack() unless item?
      if item.expiration
        item.date = helperLib.currentTime(true).valueOf()
        item.attrSave('date')
      #TODO
      #env.variable('allorfail')
      ret = env.player.inventory.add(item, count, true)
      @routine({id: 'ItemChange', ret: ret, version: env.player.inventoryVersion})
      if ret
        for e in ret when env.player.getItemAt(e.slot).autoUse
          @next({id: 'UseItem', slot: e.slot, pIdx:env.variable('pIdx')})
  },
  RemoveItem: {
    callback: (env) ->
      {ret, version} = env.removeItem(env.variable('item'), env.variable('count'), env.variable('slot'), true)
      @routine({id: 'ItemChange', ret: ret, version: version})
  },
}

getVip = (rmb) ->
  tbl = queryTable(TABLE_VIP, "VIP")
  return {level: 0, cfg: {}} unless tbl?
  level = -1
  for i, lv of tbl.requirement when lv.rmb <= rmb
    level = i

  levelCfg = JSON.parse(JSON.stringify(tbl.levels[level]))
  levelCfg.privilege = tbl.requirement[level].privilege
  
  return {level: level, cfg: levelCfg}


registerConstructor(Player)
exports.Player = Player
registerConstructor(Prentice)
exports.Prentice = Prentice
registerConstructor(PrenticeLst)
exports.PrenticeLst =PrenticeLst
exports.playerMessageFilter = playerMessageFilter
exports.getVip = getVip
