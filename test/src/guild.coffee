shall = require('should')
libGuild = require('../js/guild')
Upgradeable = libGuild.Upgradeable
Modifier = libGuild.Modifier
libPlayer = require('../js/timeUtils')
moment = require('moment')
player = 
  faction: 'hero'
  upgrade: null
  claimCost: (cost) ->
    @upgrade = cost
    if cost == 3
      return null
    {}
describe 'Upgradeable', ->
  it '', (done) ->

    Upgradeable::upgradeCost = (level) ->
      d = [
        1
        2
        3
      ]
      d[level]

    up = new Upgradeable
    console.log up
    up.currentLevel().should.eql 0, 'initialize value'
    up.upgrade player
    up.currentLevel().should.eql 1, 'succ upgrade to 1'
    player.upgrade.should.eql 1, 'should cost 1'
    up.upgrade player
    up.currentLevel().should.eql 2, 'succ upgrade to 2'
    player.upgrade.should.eql 2, 'should cost 2'
    up.upgrade player
    up.currentLevel().should.eql 2, 'failed upgrade'
    player.upgrade.should.eql 3, 'try to cost 3'
    done()
    return
  return
describe 'Modifyer', ->

  Modifier::getConfig = (key) ->
    data = '+gold':
      describe: '土豪是怎么练成的'
      upgradeCost: [
        1
        2
      ]
      active:
        cost: 4
        stayOpen:
          time: 'activeTimeStamp@date'
          duration: week: 1
      target: [ 'hero' ]
      modifyData: [
        {
          desc: '提高金钱掉落'
          type: 'gold'
          value: [
            1.1
            2
          ]
          event: 'claimReward'
        }
        {
          desc: '提高hp'
          type: 'health'
          value: [
            1.2
            1.2
            1.3
          ]
          event: 'createObj'
        }
      ]
    temp = data[@type][key]
    console.log 'get ', temp, '====key', key
    temp

  Modifier::currentTime = ->
    timelst = [
      '2000/01/01'
      '2000/01/21'
    ]
    moment timelst[@debugTimeIdx]
    #return timelst[this.debugTimeIdx];

  it 'active', (done) ->
    modf = new Modifier(type: '+gold')
    modf.debugTimeIdx = 0
    modf._isActive().should.eql false, 'default is disable'
    modf.active player
    console.log modf, '===', player
    modf._isActive().should.eql true, 'should active'
    #        modf.debugTimeIdx = 1;
    #        modf._isActive().should.eql(false, 'should be disable after 20 days') ;
    return
  it 'modify', (done) ->
    player.gold = 10
    player.health = 10
    modf = new Modifier(type: '+gold')
    modf.applyModifier 'claimReward', player
    player.gold.should.equal 10, 'not active'

    Modifier::_isActive = ->
      true

    player = modf.applyModifier('claimReward', player)
    player.gold.should.equal 11, ' +gold'
    player.health.should.equal 10, ' hp do not change'
    player = modf.applyModifier('createObj', player)
    player.health.should.equal 12, ' gold do not change'
    done()
    return
  it 'upgrade', (done) ->
    player.gold = 10
    modf = new Modifier(type: '+gold')

    Modifier::_isActive = ->
      true

    player = modf.applyModifier('claimReward', player)
    player.gold.should.equal 11, ' +gold'
    modf.upgrade player
    player = modf.applyModifier('claimReward', player)
    player.gold.should.equal 22, ' +gold upgrade'
    modf.upgrade player
    player = modf.applyModifier('claimReward', player)
    player.gold.should.equal 44, ' +gold upgrade failed'
    done()
    return
  return
describe 'GuildManager', ->
  it 'active', (done) ->
    done()
    return
  it 'modify', (done) ->
    done()
    return
  it 'upgrade', (done) ->
    done()
    return
  return
