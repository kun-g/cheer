require('./define')

getSpecialRewardByInfiniteLevel = (infiniteLevel, prizeCfg) ->
  ret = []
  for level, prize of prizeCfg
    if infiniteLevel % level is 0
      ret = prize
  return ret

calcInfinitReward = (infiniteLevel, what, optArg) ->
  infiniteLevel += 1
  ret = {}
  for name in what
    switch name
      when 'goldRate','xpRate'
        val = infiniteLevel
      when 'reward'
        val = if infiniteLevel is 0 then [] else getSpecialRewardByInfiniteLevel(infiniteLevel,optArg)
    ret[name] = val
  return ret

exports.getRewardModifier = (type) ->
  modifier = @envReward_modifier[type] ? 0
  return modifier + (@reward_modifier[type] ? 0)

rearrangePrize = (prize) ->
  prize = [prize] unless Array.isArray(prize)
  prize.sort((a, b) ->
    if a.type is b.type and a.type is PRIZETYPE_ITEM
      return a.value > b.value
    else
      return a.type > b.type
  )

  res = []
  lastElem = null
  for k, v of prize
    if lastElem and lastElem.type is v.type
      if v.type isnt PRIZETYPE_ITEM or lastElem.value is v.value
        lastElem.count += v.count
        continue

    res.push(v)
    lastElem = v

  return res

exports.rearrangePrize = rearrangePrize #for debug
exports.generateReward = (config, dropInfo, rand) ->
  rand = Math.random unless rand
  return [] unless config
  res = dropInfo
         .reduce(((r, p) => return r.concat(config[p]); ), [])
         .filter((p) => return p && rand() < p.rate; )
         .map((g) =>
           e = {}
           r = selectElementFromWeightArray(g.prize, rand())
           for k, v of r when k isnt 'weight'
             e[k] = v

           return e
         )
  return rearrangePrize(res)

injectRobReward = (victim, suspect, reward) ->
  reward.map((e) ->
    if e.type is PRIZETYPE_FUNCTION and e.func is 'rob'
      e.victim = victim
    return e
  )
exports.generateDungeonReward = (dungeon) ->
  result = dungeon.result
  cfg = dungeon.config
  if result is DUNGEON_RESULT_DONE or not cfg? then return []

  dropInfo = dungeon.killingInfo.reduce( ((r, e) ->
    if e and e.dropInfo then return r.concat(e.dropInfo)
    return r
  ), [])

  if result is DUNGEON_RESULT_WIN and dungeon.isSweep
    dropInfo = dropInfo.concat(cfg.dropID[dungeon.rankIdx]) if cfg.dropID[dungeon.rankIdx]

  prize = @generateReward(queryTable(TABLE_DROP), dropInfo)
  prize = prize.concat(dungeon.prizeInfo ? [])

  goldRate = (cfg.goldRate ? 1)
  xpRate   = (cfg.xpRate ? 1)
  wxpRate  = (cfg.wxpRate ? 1)

  infiniteLevel = dungeon.infiniteLevel
  if infiniteLevel? and cfg.infinityPrize and result is DUNGEON_RESULT_WIN
    {reward} = calcInfinitReward(infiniteLevel,['reward'], cfg.infinityPrize)
    prize = prize.concat(reward)

    {goldRate, xpRate} = calcInfinitReward(infiniteLevel, ['goldRate','xpRate'])

  gr = if result is DUNGEON_RESULT_WIN then goldRate else 0.5
  xr = if result is DUNGEON_RESULT_WIN then xpRate  else 0.5
  wr = if result is DUNGEON_RESULT_WIN then wxpRate else 0.5


  unless dungeon.isSweep
    prize.push({type:PRIZETYPE_GOLD, count:Math.floor(gr*cfg.prizeGold)}) if cfg.prizeGold
    prize.push({type:PRIZETYPE_EXP, count: Math.floor(xr*cfg.prizeXp)}) if cfg.prizeXp

  prize.push({type:PRIZETYPE_WXP, count: Math.floor(wr*cfg.prizeWxp)}) if cfg.prizeWxp


  #TODO:refactor this
  if dungeon.PVP_Pool? and dungeon.result is DUNGEON_RESULT_WIN
    @updatePkInof(dungeon)
    prize = prize.concat(@getPKReward(dungeon))

  for e in prize
    switch e.type
      when PRIZETYPE_GOLD then e.count *= 1+@getRewardModifier('dungeon_gold')
      when PRIZETYPE_EXP  then e.count *= 1+@getRewardModifier('dungeon_exp')
      when PRIZETYPE_WXP  then e.count *= 1+@getRewardModifier('dungeon_wxp')
      when PRIZETYPE_ITEM then e.count *= 1+@getRewardModifier('dungeon_item_count')

    if e.count then e.count = Math.floor(e.count)
  prize = rearrangePrize(prize)
  if dungeon.getStageConfig.pvp isnt 'arena' and dungeon.PVP_Pool[0].name?
    prize = injectRobReward(dungeon.PVP_Pool[0].name, @,prize)
  return prize

exports.claimDungeonReward = (dungeon, isSweep) ->
  return [] unless dungeon?
  ret = []

  if dungeon.revive > 0
    ret = @inventory.removeById(ItemId_RevivePotion, dungeon.revive, true)
    if not ret or ret.length is 0
      @inventoryVersion++
      return { NTF: Event_DungeonReward, arg : { res : DUNGEON_RESULT_FAIL } }
    ret = this.doAction({id: 'ItemChange', ret: ret, version: @inventoryVersion})

  quests = dungeon.quests
  if quests
    @updateQuest(quests)
    @questVersion++

  prize = @generateDungeonReward(dungeon)

  rewardMessage = { NTF: Event_DungeonReward, arg: { res: dungeon.result } }

  ret = ret.concat([rewardMessage])
  if dungeon.result isnt DUNGEON_RESULT_FAIL then ret = ret.concat(this.completeStage(dungeon.stage, dungeon.infiniteLevel))

  result = 'Lost'
  result = 'Win' if dungeon.result is DUNGEON_RESULT_WIN

  prize = prize.filter( (e) -> return not ( e.count? and e.count is 0 ) )
  if prize.length > 0 then rewardMessage.arg.prize = prize.filter((f) -> f.type isnt PRIZETYPE_FUNCTION)
  ret = ret.concat(this.claimPrize(prize, false))

  if isSweep
  else
    @log('finishDungeon', { stage: dungeon.getInitialData().stage, result: result, reward: prize })
    @releaseDungeon()
  return ret

exports.config = {
  reward_modifier:
    {
      dungeon_gold:0,
      dungeon_exp:0,
      dungeon_wxp:0,
      dungeon_item_count:0
    }
}
