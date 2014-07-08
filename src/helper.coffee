{conditionCheck} = require('./trigger')
moment = require('moment')

dbLib = require('./db')
# Leaderboard
exports.initLeaderboard = (config) ->
  localConfig = []
  srvCfg = {}

  generateHandler = (dbKey, cfg) ->
    return (name, value) ->
      require('./dbWrapper').updateLeaderboard(dbKey, name, value)

  for key, cfg of config
    localConfig[key] = { func: generateHandler(cfg.name, cfg) }
    localConfig[key][k] = v for k, v of cfg

  dbLib.getServerConfig('Leaderboard', (err, arg) ->
    if arg then srvCfg = JSON.parse(arg)
    
    for key, cfg of config when not srvCfg[cfg.name]
      srvCfg[cfg.name] = currentTime()

    dbLib.setServerConfig('Leaderboard', JSON.stringify(srvCfg))
  )

  exports.assignLeaderboard = (player,leaderboardID) ->
    v = localConfig[leaderboardID]

    return false unless v? and player.type is v.type

    if not v.key?
      val = if typeof v.initialValue is 'number'? then v.initialValue else null
      dbLib.tryAddLeaderboardMember(v.name, player.name, val)
    else
      tmp = v.key.split('.')
      field = tmp.pop()
      obj = player
      if tmp.length
        obj = require('./trigger').doGetProperty(player, tmp.join('.')) ? player
      if v.initialValue? and not (typeof obj[field] isnt 'undefined' and obj[field])
        if typeof v.initialValue is 'number'
          obj[field] = v.initialValue

      v.func(player.name, obj[field])

  tickLeaderboard = (board, cb) ->
    cfg = localConfig[board]
    if cfg.resetTime and matchDate(srvCfg[cfg.name], currentTime(), cfg.resetTime)
      require('./dbWrapper').removeLeaderboard(cfg.name, cb)
      srvCfg[cfg.name] = currentTime()
      dbLib.setServerConfig('Leaderboard', JSON.stringify(srvCfg))

  exports.getPositionOnLeaderboard = (board, name, from, to, cb) ->
    tickLeaderboard(board)
    cfg = localConfig[board]
    reverse = if cfg.reverse then 1 else 0
    console.log('getPositionOnLeaderboard',reverse)
    dbLib.queryLeaderboard(cfg.name, reverse, name, from, to, (err, result) ->
      result.board = result.board.reduce( ( (r, l, i) ->
        if i%2 is 0
          r.name.push(l)
        else
          r.score.push(l)
        return r
      ), {name: [], score: []})
      cb(err, result)
    )

exports.array2map = (keys, value) ->
  size = keys.length
  value.reduce( ( ( r, l , i) ->
    keyIdx = i % size
    r[keys[keyIdx]].push(l)
    return r
  ),{})

exports.warpRivalLst = (lst) ->
  return lst.reduce( ( (r, l, i) ->
    if l.length == 2 then r.name.push(l[0]) and r.rnk.push(+l[1])
    return r
  ), {name: [], rnk: []})

# Time util
currentTime = (needObject) ->
  obj = moment()
  if needObject
    return obj
  else
    return obj.format(time_format)
exports.currentTime = currentTime

diffDate = (date, today, flag = 'day') ->
  return null unless date
  date = moment(date).startOf('day') if date
  today = moment(today).startOf('day')
  duration = moment.duration(today.diff(date))
  switch flag
    when 'second' then return duration.asSeconds()
    when 'minite' then return duration.asMinites()
    when 'hour' then return duration.asHours()
    when 'day' then return duration.asDays()
    when 'month' then return duration.asMonths()
    when 'year' then return duration.asYears()
exports.diffDate = diffDate

matchDate = (date, today, rule) ->
  return false unless date
  date = moment(date)
  today = moment(today)

  if rule.weekday?
    date = date.weekday(rule.weekday)
  else if rule.monthday?
    date = date.date(rule.monthday)

  if rule.month then date = date.month(rule.month)
  if rule.day then date = date.add('day', rule.day)
  date = date.set('hour', rule.hour ? 0)
  date = date.set('minute', rule.minute ? 0)
  date = date.set('second', rule.second ? 0)

  return date <= today
  
exports.matchDate = matchDate

exports.dateInRange = (date, ranges) ->
  return false unless date
  monthOfDate = moment(date).date()
  for range in ranges
    if monthOfDate >= range.from and monthOfDate <= range.to
      return true
  return false

genCampaignUtil = () ->
  return {
    diffDay: (date, today) -> return not date? or diffDate(date, today, 'day') isnt 0,
    currentTime: currentTime,
    today: moment()
  }
exports.genUtil = genCampaignUtil

initCampaign = (me, allCampaign, abIndex) ->
  ret = []
  util = genCampaignUtil()
  for key, e of allCampaign when me.getType() is e.storeType
    if key is 'event_daily'
      ret = ret.concat(initDailyEvent(me, 'event_daily', e))
    else
      if e.canReset?(me, util) then e.reset(me, util)
      if e.id?
        actived = e.actived
        if typeof actived is 'function' then actived = actived(me, util)
        evt = { NTF: Event_BountyUpdate, arg: { bid: e.id, sta: actived} }
        count = me.counters[key] ? 0
        if e.count then evt.arg.cnt = e.count - count
        if key is 'hunting'
          if not moment().isSame(gHuntingInfo.timestamp, 'day') or
             not gHuntingInfo.timestamp?
            gHuntingInfo.timestamp = currentTime()
            gHuntingInfo.stage = e.stages[rand()%e.stages.length]
            dbLib.setServerConfig('huntingInfo', JSON.stringify(gHuntingInfo))
          evt.arg.stg = +gHuntingInfo.stage
        ret.push(evt)
  return ret

# campaign
initDailyEvent = (me, key, e) ->
  ret = []
  if e.prev? and me[e.prev]? and me[e.prev].status isnt 'Done'
    return []
  if e.flag? and not me.flags[e.flag]?
    return []

  if not me[key]?
    me[key] = {}
    me.attrSave(key, true)
  if e.daily
    if not me[key].date or diffDate(me[key].date, currentTime()) isnt 0
      e.quest.forEach( (q) -> delete me.quests[q])
      me[key]['status'] = 'Init'
      me[key]['date'] = currentTime()
      if key is 'event_daily'
        me[key]['rank'] = Math.ceil(me.battleForce*0.04)
        if me[key].rank < 1 then me[key].rank = 1
        me[key]['reward'] = [{type: PRIZETYPE_DIAMOND, count: 50}]

  if e.quest and Array.isArray(e.quest) and me[key].status is 'Init'
    me[key].quest = shuffle(e.quest, Math.random()).slice(0, e.steps)
    me[key].step = 0
    goldCount = Math.ceil(me.battleForce)
    diamondCount = Math.ceil(me[key].rank/10)
    me[key]['stepPrize'] = [
      [{type: PRIZETYPE_ITEM, value: 538, count: 1}],
      [{type: PRIZETYPE_GOLD, count: goldCount}],
      [{type: PRIZETYPE_ITEM, value: 871, count: 3}],
      [{type: PRIZETYPE_DIAMOND, count: 10}]
    ]
  quest = me[key].quest
  if Array.isArray(quest)
    quest = quest[me[key].step]
  switch me[key].status
    when 'Claimed'
      if quest? then delete me.quests[quest]
      me[key].step++
      if me[key].step == e.steps
        me[key].status = 'Complete'
      else if me[key].step > e.steps
        me[key].status = 'Done'
      else
        me[key].status = 'Ready'
        quest = me[key].quest
        if Array.isArray(quest)
          quest = quest[me[key].step]
        if quest? then delete me.quests[quest]
      return ret.concat(initDailyEvent(me, key, e))
    when 'Init'
      me[key].status = 'Ready'
      return ret.concat(initDailyEvent(me, key, e))
    when 'Ready', 'Complete', 'Done'
      if quest?
        if me.isQuestAchieved(quest)
          me[key].status = 'Complete'
        else if not me.quests[quest]
          ret = ret.concat(me.acceptQuest(quest))

      evt = {
        NTF: Event_UpdateDailyQuest,
        arg: { stp: me.event_daily.step, prz: me.event_daily.reward }
      }
      if me.event_daily.quest[me.event_daily.step]?
        evt.arg.qst = me.event_daily.quest[me.event_daily.step]
      if me.event_daily.stepPrize[me.event_daily.step]?
        evt.arg.cpz = me.event_daily.stepPrize[me.event_daily.step]

      ret.push(evt)
  return ret
exports.initCampaign = initCampaign

exports.initCalcDungeonBaseRank = (me) ->
  if me.event_daily? and me.event_daily.step < 4
    modifier = [0.8, 1, 1, 1.2]
    return me.event_daily.rank*modifier[me.event_daily.step]

actCampaign = (me, key, config, handler) ->
  initCampaign(me, config)
  return [false, 'NoData'] unless me[key]?

  switch me[key].status
    when 'Ready'
      quest = me[key].quest
      if Array.isArray(quest)
        quest = quest[me[key].step]
      stage = queryTable(TABLE_QUEST, quest).stage ? 1
      if stage? then return me.startDungeon(stage, true, handler)
    when 'Complete'
      if me[key].step < config[key].steps
        prize = me[key].stepPrize[me[key].step]
      else
        if me[key].reward
          prize = me[key].reward
        else if config[key].reward
          prize = config[key].reward
      ret = me.claimPrize(prize)
      me[key].status = 'Claimed'
      ret = ret.concat(initCampaign(me, config))
    when 'Done' then ret = [].concat(ret)
    else throw Error('WrongCampainStatus'+me[key].status)
  if handler
    handler(null, ret)
  else
    return ret

exports.proceedCampaign = actCampaign

exports.events = {
    "event_daily": {
      "flag": "daily",
      "resetTime": { hour: 8 },
      "storeType": "player",
      "daily": true,
      "reward": [
        { "prize":{ "type":0, "value":33, "count":1 }, "weight":1 },
        { "prize":{ "type":0, "value":34, "count":1 }, "weight":1 },
        { "prize":{ "type":0, "value":35, "count":1 }, "weight":1 },
        { "prize":{ "type":0, "value":36, "count":1 }, "weight":1 },
        { "prize":{ "type":0, "value":37, "count":1 }, "weight":1 }
      ],
      "steps": 4,
      "quest": [
        128, 129, 130, 131, 132, 133, 134, 135,
        136, 137, 138, 139, 140, 141, 142, 143,
        144, 145, 146, 147, 148, 149, 150, 151
      ]
    },
    goblin: {
      storeType: "player",
      id: 0,
      actived: 1,
      count: 3,
      canReset: (obj, util) ->
        return util.diffDay(obj.timestamp.goblin, util.today)
      ,
      reset: (obj, util) ->
        obj.timestamp['goblin'] = util.currentTime()
        obj.counters['goblin'] = 0
    },

    enhance: {
      storeType: "player",
      id: 1,
      actived: 1,
      count: 3,
      canReset: (obj, util) ->
        return ( util.diffDay(obj.timestamp.enhance, util.today)) and (
          util.today.weekday() is 2 or
          util.today.weekday() is 4 or
          util.today.weekday() is 6 or
          util.today.weekday() is 0
        )
      ,
      reset: (obj, util) ->
        obj.timestamp['enhance'] = util.currentTime()
        obj.counters['enhance'] = 0
    },

    weapon: {
      storeType: "player",
      id: 2,
      actived: 1,
      count: 3,
      canReset: (obj, util) ->
        return (util.diffDay(obj.timestamp.weapon, util.today)) and (
          util.today.weekday() is 1 or
          util.today.weekday() is 3 or
          util.today.weekday() is 5 or
          util.today.weekday() is 0
        )
      ,
      reset: (obj, util) ->
        obj.timestamp['weapon'] = util.currentTime()
        obj.counters['weapon'] = 0
    },

    infinite: {
      storeType: "player",
      id: 3,
      actived: (obj, util) ->
       if exports.dateInRange(util.today,[{from:1,to:6},{from:14,to:20},{from:28,to:28}])
         return 1
       else
         return 0
      canReset: (obj, util) ->
        return (util.today.hour() >= 8 && diffDate(obj.timestamp.infinite, util.today) >= 7)
      ,
      reset: (obj, util) ->
        obj.timestamp['infinite'] = util.currentTime()
        obj.stage[120]['level'] = 0
        obj.notify('stageChanged',{stage:120})
    },

    hunting: {
      storeType: "player",
      id: 4,
      actived: (obj, util) ->
        if exports.dateInRange(util.today,[{from:7,to:13},{from:21,to:27}])
          return 1
        else
          return 0
      ,
      stages: [121, 122, 123, 125, 126, 127, 128, 129, 130, 131, 132],
      canReset: (obj, util) ->
        return (diffDate(obj.timestamp.hunting, util.today) >= 7 )
      ,
      reset: (obj, util) ->
        obj.timestamp.hunting = util.currentTime()
        stages = [121, 122, 123, 125, 126, 127, 128, 129, 130, 131, 132]
        for s in stages when obj.stage[s]
          obj.stage[s].level = 0
        obj.modifyCounters('monster',{ value : 0,notify:{name:'countersChanged',arg:{type : 'monster'}}})
    },

    monthCard: {
      storeType: "player",
      id: -1,
      actived: (obj, util) ->
        return 0 unless obj.counters.monthCard
        return 1 unless obj.timestamp.monthCard
        return 0 if moment().isSame(obj.timestamp.monthCard, 'day')
        return 1
    },
    
    pkCounter: {
      storeType: "player",
      id: 6,
      actived: 1,
      canReset: (obj, util) ->
        return (util.diffDay(obj.timestamp.currentPKCount, util.today))
      ,
      reset: (obj, util) ->
        obj.timestamp.currentPKCount = util.currentTime()
        obj.counters.currentPKCount = 0
        obj.flags.rcvAward = false
    },


}

exports.intervalEvent = {
  infinityDungeonPrize: {
    time: { minite: 59 },
    func: (libs) ->
      cfg = [
        {
          from: 0,
          to: 0,
          mail: {
            type: MESSAGE_TYPE_SystemReward,
            src:  MESSAGE_REWARD_TYPE_SYSTEM,
            prize: [{ type: 2, count: 50},
                    { type: 0,value:869, count: 1}],
            tit: "铁人试炼排行奖励",
            txt: "恭喜你成为铁人试炼冠军，点击领取奖励。"
          }
        },
        {
          from: 1,
          to: 4,
          mail: {
            type: MESSAGE_TYPE_SystemReward,
            src:  MESSAGE_REWARD_TYPE_SYSTEM,
            prize: [{ type: 2, count: 20},
                    { type: 0,value:868, count: 1}],
            tit: "铁人试炼排行奖励",
            txt: "恭喜你进入铁人试炼前五，点击领取奖励。"
          }
        },
        {
          from: 5,
          to: 9,
          mail: {
            type: MESSAGE_TYPE_SystemReward,
            src:  MESSAGE_REWARD_TYPE_SYSTEM,
            prize: [{ type: 2, count: 10},
                    { type: 0,value:867, count: 1}],
            tit: "铁人试炼排行奖励",
            txt: "恭喜你进入铁人试炼前十，点击领取奖励。"
          }
        }
      ]
      cfg.forEach( (e) ->
        libs.helper.getPositionOnLeaderboard(1, 'nobody', e.from, e.to, (err, result) ->
          result.board.name.forEach( (name, idx) ->
            e.mail = e.mail + ' from:' + e.from + ' to: '+ e.to + ' rank:' + result.score[idx]
            libs.db.deliverMessage(name, e.mail) )
        )
      )
  },
  killMonsterPrize: {
    time: { minite: 59 },
    func: (libs) ->
      cfg = [
        {
          from: 0,
          to: 0,
          mail: {
            type: MESSAGE_TYPE_SystemReward,
            src:  MESSAGE_REWARD_TYPE_SYSTEM,
            prize: [{ type: 2, count: 50},
                    { type: 0,value:866, count: 1}],
            tit: "狩猎任务排行奖励",
            txt: "恭喜你成为狩猎任务冠军，点击领取奖励。"
          }
        },
        {
          from: 1,
          to: 4,
          mail: {
            type: MESSAGE_TYPE_SystemReward,
            src:  MESSAGE_REWARD_TYPE_SYSTEM,
            prize: [{ type: 2, count: 20},
                    { type: 0,value:865, count: 1}],
            tit: "狩猎任务排行奖励",
            txt: "恭喜你进入狩猎任务前五，点击领取奖励。"
          }
        },
        {
          from: 5,
          to: 9,
          mail: {
            type: MESSAGE_TYPE_SystemReward,
            src:  MESSAGE_REWARD_TYPE_SYSTEM,
            prize: [{ type: 2, count: 10},
                    { type: 0,value:864, count: 1}],
            tit: "狩猎任务排行奖励",
            txt: "恭喜你进入狩猎任务前十，点击领取奖励。"
          }
        }
      ]
      cfg.forEach( (e) ->
        libs.helper.getPositionOnLeaderboard(2, 'nobody', e.from, e.to, (err, result) ->
          result.board.name.forEach( (name, idx) ->
            e.mail = e.mail + ' from:' + e.from + ' to: '+ e.to + ' rank:' + result.score[idx]
            libs.db.deliverMessage(name, e.mail) )
        )
      )
  },
}

exports.splicePrize = (prize) ->
  goldPrize = { type: PRIZETYPE_GOLD, count: 0 }
  xpPrize = { type: PRIZETYPE_EXP, count: 0 }
  wxPrize = { type: PRIZETYPE_WXP, count: 0 }
  itemFlag = {}
  otherPrize = []
  prize.forEach( (p) ->
    return [] unless p?
    switch p.type
      when PRIZETYPE_WXP then wxPrize.count += p.count
      when PRIZETYPE_EXP then xpPrize.count += p.count
      when PRIZETYPE_GOLD then goldPrize.count += p.count
      when PRIZETYPE_ITEM
        if not itemFlag[p.value] then itemFlag[p.value] = 0
        itemFlag[p.value] += p.count
      else otherPrize.push(p)
  )
  for id, count of itemFlag
    otherPrize.push({ type: PRIZETYPE_ITEM, value: +id, count: + count})
  return {
    goldPrize: goldPrize,
    xpPrize: xpPrize,
    wxPrize: wxPrize,
    otherPrize: otherPrize
  }

exports.generatePrize = (cfg, dropInfo) ->
  return [] unless cfg?
  reward = dropInfo
    .reduce( ((r, p) -> return r.concat(cfg[p]) ), [])
    .filter((p) -> p and Math.random() < p.rate )
    .map((g) ->
      e = selectElementFromWeightArray(g.prize, Math.random())
      return e
    )

updateLockStatus = (curStatus, target, config) ->
  return [] unless curStatus
  ret = []
  for id, cfg of config
    unlockable = true
    if cfg.cond? then unlockable = unlockable and conditionCheck(cfg.cond, target)
    if unlockable and not curStatus[id]? then ret.push(+id)
  return ret
exports.updateLockStatus = updateLockStatus

exports.calculateTotalItemXP = (item) ->
  return 0 unless item.xp?
  levelTable = [0, 1, 2, 3, 4]
  upgrade = queryTable(TABLE_UPGRADE)
  xp = item.xp
  for i, cfg of upgrade when levelTable[item.quality] <= i < item.rank
    xp += cfg.xp
  return xp

# Observer
exports.LeaderboardIdx = {
  BattleForce : 0
  InfinityDungeon : 1
  KillingMonster : 2
  Arena : 3
}
exports.observers = {
  heroxpChanged: (obj, arg) ->
    obj.onCampaign('Level')
    if arg.prevLevel isnt arg.currentLevel
      if arg.currentLevel is 10
        dbLib.broadcastEvent(BROADCAST_PLAYER_LEVEL, {
          who: obj.name,
          what: obj.hero.class
        })
  battleForceChanged: (obj, arg) ->
    exports.assignLeaderboard(obj, exports.LeaderboardIdx.BattleForce)
    obj.updateMercenaryInfo()
  countersChanged: (obj, arg) ->
    exports.assignLeaderboard(obj, exports.LeaderboardIdx.KillingMonster) if arg.type is 'monster'
  stageChanged: (obj, arg) ->
    exports.assignLeaderboard(obj, exports.LeaderboardIdx.InfinityDungeon) if arg.stage is 120
  winningAnPVP: (obj, arg) ->
    #TODO:
    exports.assignLeaderboard(obj, exports.LeaderboardIdx.Arena)
}

exports.initObserveration = (obj) ->
  obj.observers = {}
  obj.installObserver = (event) -> obj.observers[event] = exports.observers[event]
  obj.removeObserver = (event) -> obj.observers[event] = null
  obj.notify = (event, arg) ->
    ob = obj.observers[event]
    if ob then ob(obj, arg)

exports.dbScripts = {
  searchRival: """
    local board, name = ARGV[1], ARGV[2];
    local key = 'Leaderboard.'..board;
    local config = {
        {base=0.95, delta=0.02, rand= ARGV[3]},
        {base=0.85, delta=0.03, rand= ARGV[4]},
        {base=0.50, delta=0.05, rand= ARGV[5]},
      };
    local count = 3;
    local rank = redis.call('ZRANK', key, name);

    local rivalLst = {};
    if rank <= count then
      for index = 0, rank-1 do 
        table.insert(rivalLst,redis.call('zrange', key, index, index, 'withscores'));
      end
      for index = rank+1, count do 
        table.insert(rivalLst,redis.call('zrange', key, index, index, 'withscores'));
      end
   else
      rank = rank - 1;
      for i, c in ipairs(config) do
        local from = math.ceil(rank * (c.base-c.delta));
        local to = math.ceil(rank * (c.base+c.delta));
        local index = from
        if  to ~=  from then 
          index = index + c.rand%(to - from);
        end
        index = math.ceil(index);
        rivalLst[count - i + 1] = redis.call('zrange', key, index, index, 'withscores');
        rank = index - 1;
      end
    end

    return rivalLst;
  """
  getMercenary: """
    local battleforce, count, range = ARGV[1], ARGV[2], ARGV[3];
    local delta, rand, names, retrys = ARGV[4], ARGV[5], ARGV[6], ARGV[7];
    local key = 'Leaderboard.battleforce';
    local from = battleforce - range;
    local to = battleforce + range;
    local nameMask = {}

    while string.len(names) > 0 do
      local index = string.find(names, ',');
      if index == nil then
        nameMask[names] = 1;
        break;
      end
      local v = string.sub(names, 1, index-1)
      nameMask[v] = 1;
      names = string.sub(names, index+1, -1);
    end

    local ret = {};
    while true do
      local list = redis.call('zrevrangebyscore', key, to, from);
      local mercenarys = {};
      for i, name in ipairs(list) do
        if nameMask[name] ~= 1 then table.insert(mercenarys, name); end
      end

      local length = table.getn(mercenarys);
      if length > 0 then
        local name = mercenarys[rand%length + 1];
        table.insert(ret, name);
        nameMask[name] = 1;
      end

      if table.getn(ret) >= tonumber(count) then break; end

      from = from - delta;
      if from < 0 then from = 0; end
      to = to + delta;
      retrys = retrys - 1;
      if retrys == 0 then return {err='Fail'}; end
    end

    return ret;
  """

  exchangePKRank: """
    local board, champion, second = ARGV[1], ARGV[2], ARGV[3]; 
    local key = 'Leaderboard.'..board; 
    local championRank = redis.call('ZRANK', key, champion); 
    local secondRank = redis.call('ZRANK', key, second); 
    if championRank > secondRank then 
      redis.call('ZADD', key, championRank, second); 
      redis.call('ZADD', key, secondRank, champion); 
      championRank = secondRank;
    end 
    return championRank;
  """

  tryAddLeaderboardMember: """
    local board, name, value = ARGV[1], ARGV[2], ARGV[3];
    local key = 'Leaderboard.'..board;
    local score = redis.call('ZSCORE', key, name)
    if score == false then
      score = value;
      if value == 'null' then
        score = redis.call('ZCARD', key)
      end
      redis.call('ZADD', key, score, name);
    end
    return score
  """

}
