shall = require('should')
require '../js/define'
Prentice = null
describe 'prentice test', ->
  before (done) ->
    cfg = null
    initGlobalConfig '../../build/', ->
      playerLib = require('../js/player')
      Prentice = playerLib.Prentice
      console.log '======?', Prentice
      cfg =
        'globalCfg':
          maxPrentice: 2
          unlockPrenticeCond: ->
        '0':
          upgradeCost: []
          unlockSkill: [
            [
              0
              1
              2
            ]
            [
              10
              11
              21
            ]
          ]

      Prentice::getConfig = (type, isGlobal) ->
        key = @class
        if isGlobal == true
          key = 'global'
        cfg[key][type]

      done()
      return
    return
  it 'query skill', (done) ->
    testData = [
      {
        init: {}
        check: 'skills': []
      }
      {
        act: [ { 'upgradeSkill': 1 } ]
        check:
          quality: 1
          skill: []
      }
      {
        act: [ { 'upgradeSkill': 1 } ]
        check:
          quality: 1
          skill: []
      }
    ]
    testData.reduce ((acc, data) ->
      if data.init != null
        acc = new Prentice(data.init.data, data.init.master)
      for key of data.check
        `key = key`
        val = data.check[key]
        acc[key].should.eql val
      acc
    ), null
    return
  return
