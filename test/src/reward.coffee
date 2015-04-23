#:map ,t :!echo "make all && mocha test/reward.js" >> test-commands <cr>

deepFreeze = (o) ->
  prop = undefined
  propKey = undefined
  Object.freeze o
  # First freeze the object.
  for propKey of o
    `propKey = propKey`
    prop = o[propKey]
    if !o.hasOwnProperty(propKey) or !(typeof prop == 'object') or Object.isFrozen(prop)
      # If the object is on the prototype, not an object, or is already frozen,
      # skip it. Note that this might leave an unfrozen reference somewhere in the
      # object if there is an already frozen object containing an unfrozen object.
      continue
    deepFreeze prop
    # Recursively call deepFreeze.
  return

Player = ->
  @reward_modifier = libReward.config.reward_modifier
  @envReward_modifier = env
  return

require 'should'
libReward = require('../js/reward')
env = {}
for k of libReward
  if typeof libReward[k] == 'function'
    Player.prototype[k] = libReward[k]
describe 'Reward', ->
  describe 'Generation', ->
    p = new Player
    rewardConfig = [
      [
        {
          'rate': 1
          'prize': [ {
            'weight': 1
            'type': PRIZETYPE_GOLD
            'count': 100
          } ]
        }
        {
          'rate': 0.9
          'prize': [
            {
              'weight': 1
              'type': PRIZETYPE_ITEM
              'value': 853
              'count': 1
            }
            {
              'weight': 3
              'type': PRIZETYPE_GOLD
              'count': 50
            }
            {
              'weight': 1
              'type': PRIZETYPE_ITEM
              'value': 854
              'count': 5
            }
          ]
        }
      ]
      [ {
        'rate': 1
        'prize': [ {
          'weight': 1
          'type': PRIZETYPE_GOLD
          'count': 100
        } ]
      } ]
    ]
    deepFreeze rewardConfig

    queryTable = ->
      rewardConfig

    it 'without modifier', ->
      p.generateReward(rewardConfig, [ 0 ], ->
        0.95
      ).should.eql [ {
        type: PRIZETYPE_GOLD
        count: 100
      } ]
      p.generateReward(rewardConfig, [ 0 ], ->
        0
      ).should.eql [
        {
          type: PRIZETYPE_ITEM
          value: 853
          count: 1
        }
        {
          type: PRIZETYPE_GOLD
          count: 100
        }
      ]
      return
    it 'without duplicate', ->
      env.gold = 0.2
      p.generateReward(rewardConfig, [ 0 ], ->
        0.21
      ).should.eql [ {
        type: PRIZETYPE_GOLD
        count: 150
      } ]
      return
    it 'dungeon reward#0', ->
      dungeon = 
        result: DUNGEON_RESULT_DONE
        config:
          goldRate: 0.6
          prizeGold: 100
        killingInfo: [ { dropInfo: [ 1 ] } ]
        prizeInfo: []
      p.generateDungeonReward(dungeon).should.eql []
      dungeon.result = DUNGEON_RESULT_WIN
      p.generateDungeonReward(dungeon).should.eql [ {
        type: PRIZETYPE_GOLD
        count: 100 * 0.6 + 100
      } ]
      return
    it 'dungeon reward#1', ->
      dungeon = 
        result: DUNGEON_RESULT_DONE
        config:
          goldRate: 0.6
          prizeGold: 100
        killingInfo: [ { dropInfo: [ 1 ] } ]
        prizeInfo: [
          {
            type: PRIZETYPE_GOLD
            count: 1
          }
          {
            type: PRIZETYPE_ITEM
            value: 854
            count: 1
          }
          {
            type: PRIZETYPE_ITEM
            value: 854
            count: 1
          }
          {
            type: PRIZETYPE_ITEM
            value: 854
            count: 1
          }
          {
            type: PRIZETYPE_ITEM
            value: 855
            count: 1
          }
          {
            type: PRIZETYPE_GOLD
            count: 110
          }
        ]
      p.reward_modifier.dungeon_gold = 1
      env.dungeon_gold = 1
      env.dungeon_item_count = 1
      p.generateDungeonReward(dungeon).should.eql []
      dungeon.result = DUNGEON_RESULT_WIN
      p.generateDungeonReward(dungeon).should.eql [
        {
          type: PRIZETYPE_ITEM
          value: 854
          count: 6
        }
        {
          type: PRIZETYPE_ITEM
          value: 855
          count: 2
        }
        {
          type: PRIZETYPE_GOLD
          count: (100 * 0.6 + 100 + 110 + 1) * 3
        }
      ]
      return
    it 'sweep reward', ->
    return
  it 'Claim', ->
  it 'rearrangePrize', ->
    prizeInfo = [
      {
        type: PRIZETYPE_GOLD
        count: 1
      }
      {
        type: PRIZETYPE_ITEM
        value: 854
        count: 1
      }
      {
        type: PRIZETYPE_ITEM
        value: 854
        count: 1
      }
      {
        type: PRIZETYPE_ITEM
        value: 854
        count: 1
      }
      {
        type: PRIZETYPE_ITEM
        value: 855
        count: 1
      }
      {
        type: PRIZETYPE_GOLD
        count: 110
      }
      {
        type: PRIZETYPE_FUNCTION
        func: 'rob'
        count: 1
      }
      {
        type: PRIZETYPE_FUNCTION
        func: 'rob'
        count: 1
      }
    ]
    console.log libReward.rearrangePrize(prizeInfo)
    return
  return
