"use strict"
require('./define')
require('./shop')
moment = require('moment')
{Serializer, registerConstructor} = require './serializer'
{DBWrapper, getMercenaryMember, updateMercenaryMember, addMercenaryMember, getPlayerHero} = require './dbWrapper'
{createUnit, Hero} = require './unit'
libItem = require './item'
{CommandStream, Environment, DungeonEnvironment, DungeonCommandStream} = require('./commandStream')
{Dungeon} = require './dungeon'
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
campaign_LoginStreak = new libCampaign.Campaign(queryTable(TABLE_DP))
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
class Player extends DBWrapper
  constructor: (data) ->
    @type = 'player'
    now = new Date()
    cfg = {
      dbKeyName: '',
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
      equipment: {},
      heroBase: {},
      heroIndex: -1,
      #TODO: hero is duplicated
      hero: {},

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

      inventoryVersion: 1,
      heroVersion: 1,
      stageVersion: 1,
      questVersion: 1,
      energyVersion: 1

      abIndex: rand(),
    }
    for k,v of libReward.config
      cfg[k] = v

    @envReward_modifier = gReward_modifier
    versionCfg = {
      inventoryVersion: ['gold', 'diamond', 'inventory', 'equipment'],
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

  isEquiped: (slot) ->
    equipment = (e for i, e of @equipment)
    return equipment.indexOf(+slot) != -1

  migrate: () -> #TODO:deprecated
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
    @lastLogin = currentTime()
    if gGlobalPrize?
      for key, prize of gGlobalPrize when not @globalPrizeFlag[key]
        dbLib.deliverMessage(@name, prize)
        @globalPrizeFlag[key] = true

    if not moment().isSame(@infiniteTimer, 'week')
      @infiniteTimer = currentTime()
      for s in @stage when s and s.level?
        s.level = 0

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

  sweepStage: (stage, multiple) ->
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
      isSweep : true
    }
    count = 1
    count = 5 if multiple
    ret_result = RET_OK
    prize = []
    ret = []
    energyCost = stgCfg.cost*count
    itemCost = {id: 871, num: count}

    if @stage[stage].state != STAGE_STATE_PASSED
      ret_result = RET_StageIsLocked
    else if multiple and @vipLevel() < Sweep_Vip_Level
      ret_result = RET_VipLevelIsLow
    else if @energy < energyCost
      ret_result = RET_NotEnoughEnergy
    else if (not stgCfg.sweepPower?) and stgCfg.sweepPower > @createHero().calculatePower()
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
          r = r.filter((e) => not (e.type >= PRIZETYPE_GOLD and e.type <= PRIZETYPE_WXP and e.count <= 0))
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
    
    helperLib.assignLeaderboard(@,helperLib.LeaderboardIdx.Arena)
    @counters['worldBoss'] ={} unless @counters['worldBoss']?

    if @isNewPlayer then @isNewPlayer = false


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
    productList = queryTable(TABLE_IAP, 'list')
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
      @onCampaign('RMB', rec.productID)
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

  updateStageStatus: () ->
    ret = []
    for s in updateStageStatus(@stage, @, @abIndex)
      ret = ret.concat(@changeStage(s, STAGE_STATE_ACTIVE))
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
      temp = underscore.uniq(@equipment)
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
      @heroBase[@hero.class].equipment = JSON.parse(JSON.stringify(@equipment))

    for k, v of @heroBase[hClass]
      @hero[k] = JSON.parse(JSON.stringify(v))
    @equipment = JSON.parse(JSON.stringify(@heroBase[hClass].equipment))

  addMoney: (type, point) ->
    return this[type] unless point
    return false if point + this[type] < 0
    this[type] = Math.floor(this[type]+point)
    @costedDiamond += point if type is 'diamond'
    return this[type]

  addDiamond: (point) -> @addMoney('diamond', point)

  addGold: (point) -> @addMoney('gold', point)

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

    return true

  saveDB: (handler) -> @save(handler)

  modifyCounters: (propertyName,arg) ->
    @counters[propertyName] = arg.value? 0
    @notify(arg.notify.name,arg.notify.arg) if arg.notify?

  stageIsUnlockable: (stage) ->
    return true if g_DEBUG_FLAG
    return false if getPowerLimit(stage) > @createHero().calculatePower()
    stageConfig = queryTable(TABLE_STAGE, stage, @abIndex)
    if stageConfig.condition then return stageConfig.condition(this, genUtil())
    if stageConfig.event
      return @[stageConfig.event]? and @[stageConfig.event].status is 'Ready'
    return @stage[stage] and @stage[stage].state != STAGE_STATE_INACTIVE

  changeStage: (stage, state) ->
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
          @stage[stage].level += 1
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

  startDungeon: (stage, startInfoOnly, pkr=null, handler) ->
    stageConfig = queryTable(TABLE_STAGE, stage, @abIndex)
    dungeonConfig = queryTable(TABLE_DUNGEON, stageConfig.dungeon, @abIndex)
    unless stageConfig? and dungeonConfig?
      @logError('startDungeon', {reason: 'InvalidStageConfig', stage: stage, stageConfig: stageConfig?, dungeonConfig: dungeonConfig?})
      return handler(null, RET_ServerError)
    async.waterfall([
      (cb) => if @dungeonData.stage? then cb('OK') else cb(),
      (cb) => if @stageIsUnlockable(stage) then cb() else cb(RET_StageIsLocked),
      (cb) => if @costEnergy(stageConfig.cost) then cb() else cb(RET_NotEnoughEnergy),
      (cb) => @requireMercenary((team) => cb(null, team)),
      (mercenary, cb) =>
        teamCount = stageConfig.team ? 3
        if @stage[stage]? and @stage[stage].level?
          level = @stage[stage].level
          if level%10 is 0 then teamCount = 1
          else if level%5 is 0 then teamCount = 2

        team = [@createHero()]
        team[0].needMirror= false

        if stageConfig.teammate? then team = team.concat(stageConfig.teammate.map(
          (hd) ->
            newHero = new Hero(hd)
            newHero.needMirror = false
            return newHero
        ))
        if teamCount > team.length
          if mercenary.length >= teamCount-team.length
            team = team.concat(mercenary.splice(0, teamCount-team.length))
            @mercenary = []
          else
            @costEnergy(-stageConfig.cost)
            return cb(RET_NeedTeammate)
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
          team: team.map(getBasicInfo)
        }

        @dungeonData.randSeed = rand()
        @dungeonData.baseRank = helperLib.initCalcDungeonBaseRank(@) if stageConfig.event is 'event_daily'
        cb()
      ,
      (cb) =>
        if stageConfig.pvp? and pkr? and (@getPkCoolDown() == 0 or @getAddPkCount() > 0)
          if @getAddPkCount() == 0
            @timestamp.pkCoolDown = currentTime()
          getPlayerHero(pkr, wrapCallback(this, (err, heroData) ->
            @dungeonData.PVP_Pool = if heroData? then [getBasicInfo(heroData)]
            dbLib.diffPKRank(@name, pkr,wrapCallback(this, (err, result) ->
              result = [0,0]  unless Array.isArray(result)
              @dungeonData.PVP_Score_diff = result[0]
              @dungeonData.PVP_Score_origin = result[1]
              cb('OK')
            ))))
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
            if stageConfig.initialAction then stageConfig.initialAction(@,  genUtil)
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
    if typeof cost is 'object'
      cfg ={material:[{type:0, value:cost.id, count:1}]}
    else
      cfg = queryTable(TABLE_COSTS, cost)

    return null unless cfg?
    prize = @rearragenPrize(cfg.material)
    haveEnoughtMoney = prize.reduce( (r, l) =>
      if l.type is PRIZETYPE_GOLD and @gold < l.count*count then return false
      if l.type is PRIZETYPE_DIAMOND and @diamond < l.count*count then return false
      return r
    , true)
    return null unless haveEnoughtMoney
    ret = []
    for p in prize when p?
      @inventoryVersion++
      switch p.type
        when PRIZETYPE_ITEM
          retRM = @inventory.remove(p.value, p.count*count, null, true)
          return null unless retRM and retRM.length > 0
          ret = @doAction({id: 'ItemChange', ret: retRM, version: @inventoryVersion})
        when PRIZETYPE_GOLD then ret.push({NTF: Event_InventoryUpdateItem, arg: {syn: @inventoryVersion, god: @addGold(-p.count*count)}})
        when PRIZETYPE_DIAMOND then ret.push({NTF: Event_InventoryUpdateItem, arg: {syn: @inventoryVersion, dim: @addDiamond(-p.count*count)}})

    return ret

  claimPrize: (prize, allOrFail = true) ->
    return [] unless prize?
    prize = [prize] unless Array.isArray(prize)

    ret = []

    for p in prize when p?
      @inventoryVersion++
      switch p.type
        when PRIZETYPE_ITEM
          res = @aquireItem(p.value, p.count, allOrFail)
          if not (res? and res.length >0)
            return [] if allOrFail
          ret = ret.concat(res)

        when PRIZETYPE_GOLD then ret.push({NTF: Event_InventoryUpdateItem, arg: {syn: @inventoryVersion, god: @addGold(p.count)}}) if p.count > 0
        when PRIZETYPE_DIAMOND then ret.push({NTF: Event_InventoryUpdateItem, arg: {syn: @inventoryVersion, dim: @addDiamond(p.count)}}) if p.count > 0
        when PRIZETYPE_EXP then ret.push({NTF: Event_RoleUpdate, arg: {syn: @heroVersion, act: {exp: @addHeroExp(p.count)}}}) if p.count > 0
        when PRIZETYPE_WXP
          continue unless p.count
          equipUpdate = []
          for i, k of @equipment
            e = @getItemAt(k)
            unless e?
              logError({action: 'claimPrize', reason: 'equipmentNotExist', name: @name, equipSlot: k, index: i})
              delete @equipment[k]
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

  getItemAt: (slot) -> @inventory.get(slot)

  useItem: (slot, opn)->#opn 时装系统装备卸下时需要
    item = @getItemAt(slot)
    myClass = @hero.class
    return { ret: RET_ItemNotExist } unless item?
    return { ret: RET_RoleClassNotMatch } unless isClassMatch(myClass, item.classLimit)
    @log('useItem', { slot: slot, id: item.id })

    switch item.category
      when ITEM_USE
        switch item.subcategory
          when ItemUse_ItemPack
            prize = @claimPrize(item.prize)
            return { ret: RET_InventoryFull } unless prize
            ret = @removeItem(null, 1, slot)
            return { ret: RET_OK, ntf: ret.concat(prize) }
          when ItemUse_TreasureChest
            return { ret: RET_NoKey } if item.dropKey? and not @haveItem(item.dropKey)
            prz = @generateReward(queryTable(TABLE_DROP), [item.dropId])
            prize = @claimPrize(prz)
            return { ret: RET_InventoryFull } unless prize
            @log('openTreasureChest', {type: 'TreasureChest', id: item.id, prize: prize, drop: e.drop})
            ret = prize.concat(@removeItem(null, 1, slot))
            ret = ret.concat(this.removeItemById(item.dropKey, 1, true)) if item.dropKey?
            return {prize: prz, res: ret}
          when ItemUse_Function
            ret = @removeItem(null, 1, slot)
            switch item.function
              when 'recoverEnergy'
                this.costEnergy(-item.argument)
                ret = ret.concat(this.syncEnergy())
            return { ret: RET_OK, ntf: ret }
      when ITEM_EQUIPMENT
        ret = @equipItem(slot)
        return { ret: RET_OK, ntf: [ret] }
      when ITEM_RECIPE
        if opn? and opn == 1 #USE_ITEM_OPT_EQUIP = 1;
          ret = @equipItem(slot)
          return { ret: RET_OK, ntf: [ret] }
        else
          if item.recipeTarget?
            recipe = @itemSynthesis(slot)
            return { ret: recipe.ret } unless recipe.res
            @log('itemSynthesis ret', {type: 'recipe', recipe: recipe})
            ripres = recipe.res
            ripres = ripres.concat(@removeItem(null, 1, slot))
            @log('recipe', {type: 'recipe', id: item.id, recipe: recipe.out})
            return {out:recipe.out, ntf:ripres}
          else if item.recipePrize?
            recipe = @itemDecompsite(slot)
            return { ret: RET_ItemNotExist } unless recipe
            @log('deposite ret', {type: 'recipe', recipe: recipe})
            @log('recipe', {type: 'recipe', id: item.id, recipe: recipe.out})
            return {out:recipe.prize, ntf:recipe.res}
        

    logError({action: 'useItem', reason: 'unknow', catogory: item.category, subcategory: item.subcategory, id: item.id})
    return {ret: RET_UseItemFailed}

  doAction: (routine) ->
    cmd = new playerCommandStream(routine, this)
    cmd.process()
    return cmd.translate()

  aquireItem: (item, count, allOrFail) ->
    @doAction({id: 'AquireItem', item: item, count: count, allorfail: allOrFail})

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

  equipItem: (slot) ->
    #info = @getSlotFreezeInfo(slot)

    item = @getItemAt(slot)
    return { ret: RET_RoleLevelNotMatch } if item.rank? and this.createHero().level < item.rank
    ret = {NTF: Event_InventoryUpdateItem, arg: {syn:this.inventoryVersion, itm: []}}

    equip = this.equipment[item.subcategory]
    tmp = {sid: slot, sta: 0}
    if equip is slot
      for k, v of this.equipment
        delete this.equipment[k] if v is slot
    else
      if equip? then ret.arg.itm.push({sid: equip, sta: 0})
      this.equipment[item.subcategory] = slot
      if item.extraSlots?
        for v_slot in item.extraSlots
          this.equipment[v_slot] = slot
      tmp.sta = 1
    ret.arg.itm.push(tmp)
    delete ret.arg.itm if ret.arg.itm.length < 1

    this.onEvent('Equipment')
    return ret

  levelUpItem: (slot) ->
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

    delete @equipment[k] for k, s of @equipment when s is slot

    this.addGold(-cost)
    ret = this.removeItem(null, 1, slot)
    newItem = libItem.createItem(item.upgradeTarget)
    newItem.enhancement = item.enhancement
    ret = ret.concat(this.aquireItem(newItem))
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
    return { out: {cid: newItem.id, sid: @queryItemSlot(newItem), stc: 1, sta: 1, eh: eh}, res: ret }

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
      when 'blueStarCost' then return cfg?.blueStarCost ? 0
      when 'goldAdjust' then return cfg?.goldAdjust ? 0
      when 'expAdjust' then return cfg?.expAdjust ? 0
      when 'wxpAdjust' then return cfg?.wxpAdjust ? 0
      when 'energyLimit' then return (cfg?.energyLimit ? 0) + ENERGY_MAX
      when 'freeEnergyTimes' then return cfg?.freeEnergyTimes ? 2
      when 'energyPrize' then return cfg?.energyPrize ? 1.1

  vipLevel: () -> @vipOperation('vipLevel')
  getBlueStarCost: () -> @vipOperation('blueStarCost')
  goldAdjust: () -> @vipOperation('goldAdjust')
  expAdjust: () -> @vipOperation('expAdjust')
  wxpAdjust: () -> @vipOperation('wxpAdjust')
  energyLimit: () -> @vipOperation('energyLimit')
  getPrivilege: (name) -> @vipOperation(name)
  getTotalPkTimes: () -> return @getPrivilege('pkCount')
  getAddPkCount: () -> 
    @counters.addPKCount = 0 unless @counters.addPKCount?
    return @counters.addPKCount

  getPkCoolDown: () ->
    if @counters.addPKCount? and @counters.addPKCount > 0
      return 0
    @timestamp.pkCoolDown = 0 unless @timestamp.pkCoolDown?
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
          hero = new Hero(heroData)
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
      if cfg.date? and moment(cfg.date).format('YYYYMMDD') - moment().format('YYYYMMDD') < 0 then return { config: null }
      if @getCampaignState(campaignName)? and @getCampaignState(campaignName) is false then return { config: null }
      if @getCampaignState(campaignName)? and cfg.level? and @getCampaignState(campaignName) >= cfg.level.length then return { config: null }
      if campaignName is 'LevelUp' and cfg.timeLimit*1000 <= moment()- @creationDate then return { config: null }
    else
      return { config: null }
    if cfg.level
      return { config: cfg, level: cfg.level[@getCampaignState(campaignName)] }
    else
      return { config: cfg, level: cfg.objective }

  onCampaign: (state, data) ->
    reward = []
    switch state
      when 'Friend'
        { config, level } = @getCampaignConfig('Friend')
        if config? and level? and @contactBook.book.length >= level.count
          reward.push({cfg: config, lv: level})
          @setCampaignState('Friend', 1)
      when 'RMB'
        { config, level } = @getCampaignConfig('Charge')
        if config? and level?
          rmb = data
          state = @getCampaignState('Charge')
          o = level[rmb]
          if not state[rmb] and o?
            reward.push({cfg: config, lv: o})
            state[rmb] = true
            @setCampaignState('Charge', state)

        { config, level } = @getCampaignConfig('DuanwuCharge')
        if config? and level?
          rmb = data
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
        if config? and level?
          rmb = String(data)
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

    for r in reward
      #console.log('reward', JSON.stringify(reward))
      dbLib.deliverMessage(@name, { type: MESSAGE_TYPE_SystemReward, src: MESSAGE_REWARD_TYPE_SYSTEM, prize: r.lv.award, tit: r.cfg.mailTitle, txt: r.cfg.mailBody })

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
            if ret
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

  completeStage: (stage) ->
    thisStage = queryTable(TABLE_STAGE, stage, @abIndex)
    if this.stage[stage] == null || thisStage == null then return []
    ret = this.changeStage(stage,  STAGE_STATE_PASSED)
    @onCampaign('Stage')
    return ret.concat(this.updateStageStatus())

  requireMercenary: (callback) ->
    me = @
    if not callback then return
    if @mercenary.length >= MERCENARYLISTLEN
      callback(@mercenary.map( (h) -> new Hero(h)))
    else
      #// TODO: range  & count to config
      filtedName = [@name]
      filtedName = filtedName.concat(@mercenary.map((m) -> m.name))
      if @contactBook? then filtedName = filtedName.concat(@contactBook.book)
      getMercenaryMember(@name, 2, 30, 1, filtedName,
        (err, heroData) ->
          if heroData
            me.mercenary = me.mercenary.concat(heroData)
            me.requireMercenary(callback)
          else
            callback(null)
      )

  recycleItem: (slot) ->
    recyclableEnhance = queryTable(TABLE_CONFIG, 'Global_Recyclable_Enhancement', @abIndex)
    recycleConfig = queryTable(TABLE_CONFIG, 'Global_Recycle_Config', @abIndex)
    item = @getItemAt(slot)
    for k, equip of @equipment when equip is slot
      delete @equipment[k]
      break
    ret = []
    try
      if item is null then throw RET_ItemNotExist
      xp = helperLib.calculateTotalItemXP(item) * 0.8
      ret = ret.concat(@removeItem(null, null, slot))
      reward = item.enhancement.map((e) ->
        if recyclableEnhance.indexOf(e.id) != -1
          cfg = recycleConfig[e.level]
          return {
            type : PRIZETYPE_ITEM,
            value : queryTable(TABLE_CONFIG, 'Global_Enhancement_GEM_Index', @abIndex)[e.id],
            count : cfg.minimum + rand() % cfg.delta
          }
        else
          return null
      )
      if queryTable(TABLE_CONFIG, 'Global_Material_ID').length > item.quality
        reward.push({
          type: PRIZETYPE_ITEM,
          value: queryTable(TABLE_CONFIG, 'Global_Material_ID')[item.quality],
          count: 2 + rand() % 2
        })
      reward = reward.filter( (e) -> return e? )
      #reward.push({
      #  type: PRIZETYPE_ITEM,
      #  value: queryTable(TABLE_CONFIG, 'Global_WXP_BOOK'),
      #  count: Math.floor(xp/100)
      #})
      rewardEvt = this.claimPrize(reward)
      ret = ret.concat(rewardEvt)
    catch err
      logError(err)

    return {out: reward, res: ret}

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
    getMercenaryMember(myName , 1, 30, 1, filtedName,
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
        ret = {sid: bag.queryItemSlot(e), cid: e.id, stc: e.count}

        if e.xp? then ret.xp = e.xp
        for i, equip of this.equipment when equip is index
          ret.sta = 1

        if e.enhancement
          ret.eh = e.enhancement.map((e) -> {id:e.id, lv:e.level})

        if e.date
          ret.ts = e.date

        return ret
      )).filter((e) -> e!=null)

    ev = {NTF: Event_InventoryUpdateItem, arg: { cap: bag.limit, dim: this.diamond, god: this.gold, syn: this.inventoryVersion, itm: items } }
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
    if forceUpdate then ev.arg.clr = true
    
    return ev

  syncVipData: (forceUpdate) ->
    ev = {
      NTF:Event_RoleUpdate,
      arg:{
        act:{
          vip:@vipLevel(),
          vipOp:{
            freeEnergyTimes:@vipOperation('freeEnergyTimes')
            energyPrize:@vipOperation('energyPrize')
          }
        }
      }
    }
    return ev
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
      questVersion : 'qst'
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
    basicPrize = @getFragPrizeTable(type,'basic_prize')
    advancedPrize = @getFragPrizeTable(type,'advanced_prize')
    dprint('basicPrize=', basicPrize)
    dprint('advancedPrize=', advancedPrize)

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
        prz = prz.concat(generatePrize(basicPrize, [0..basicPrize.length-1]))
        @counters.fragmentTimes[type]++
      else
        prz = prz.concat(generatePrize(advancedPrize, [0..advancedPrize.length-1]))
        @counters.fragmentTimes[type] = 0
      @counters.totalFragTimes[type]++

    prize = @claimPrize(prz)
    console.log('prz=', prz)
    if prize.length <= 0
      @addDiamond(diamondCost)
      return { ret: RET_InventoryFull }
    prize = prize.concat(evt)
    @log('lottery', {type: 'lotteryFragment', prize: prize})
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
      for k, v of h.count_value
        switch h.condition
          when 'less'
            if @counters.totalFragTimes[type] < v
              return h[table]
          when 'equal'
            if @counters.totalFragTimes[type] == v
              return h[table]
          when 'more'
            if @counters.totalFragTimes[type] > v
              return h[table]
          when 'interval'
            if @counters.totalFragTimes[type] % v == 0
              return h[table]
    return cfg[type][table]

  itemSynthesis: (slot) ->
    recipe = @getItemAt(slot)
    return { ret: RET_ItemNotExist } unless recipe?
    ret = @claimCost(recipe.recipeCost)
    if not ret? then return { ret: RET_InsufficientIngredient }
    return { ret: RET_Unknown } unless recipe.recipeTarget?
    newItem = libItem.createItem(recipe.recipeTarget)
    ret = ret.concat(@aquireItem(newItem))
    @log('itemSynthesis', { slot: slot, id: recipe.id })
    return { out: { type: PRIZETYPE_ITEM, value: newItem.id, count: 1}, res: ret }

  itemDecompsite: (slot) ->
    recipe = @getItemAt(slot)
    return { ret: RET_ItemNotExist } unless recipe?
    prz = @claimPrize(recipe.recipePrize)
    if not prz? then return { ret: RET_InsufficientIngredient }
    ret = prz.concat(@removeItem(null, 1, slot))
    @log('itemDecompsite', { slot: slot, id: recipe.id })
    return { prize: prz, res: ret }

  getDiffTime: (from, to, type) ->
    duration = libTime.diff(to, from)
    switch type
      when 'second' then return duration.asSeconds()
      when 'minite' then return duration.asMinutes()
      when 'hour' then return duration.asHours()
      when 'day' then return duration.asDays()

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
      delete @player.equipment[k] for k, s of @player.equipment when s is slot
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
    output: (env) -> return env.player.useItem(env.variable('slot')).ntf
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
          @next({id: 'UseItem', slot: e.slot})
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
exports.playerMessageFilter = playerMessageFilter
exports.getVip = getVip
