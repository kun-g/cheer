triggerLib = require('../js/trigger')
require '../js/define'
shall = require('should')
describe '', ->
  it 'direction', ->
    calcDirection = triggerLib.calcDirection
    translatePos = triggerLib.translatePos
    data = [
      {
        psrc: 12
        ptar: [
          0
          6
        ]
        res: 7
      }
      {
        psrc: 12
        ptar: [
          7
          2
        ]
        res: 8
      }
      {
        psrc: 12
        ptar: [
          8
          4
        ]
        res: 9
      }
      {
        psrc: 12
        ptar: [
          13
          14
        ]
        res: 6
      }
      {
        psrc: 12
        ptar: [
          18
          24
        ]
        res: 3
      }
      {
        psrc: 12
        ptar: [
          17
          22
        ]
        res: 2
      }
      {
        psrc: 12
        ptar: [
          16
          20
        ]
        res: 1
      }
      {
        psrc: 12
        ptar: [ 12 ]
        res: 5
      }
      {
        psrc: 1
        ptar: [
          22
          21
          20
        ]
        res: 2
      }
      {
        psrc: 20
        ptar: [
          0
          1
        ]
        res: 8
      }
      {
        psrc: 12
        ptar: [
          10
          11
        ]
        res: 4
      }
    ]
    for i of data
      cfg = data[i]
      cfg.ptar.forEach (ptar) ->
        res = calcDirection(translatePos(cfg.psrc), translatePos(ptar))
        res.should.equal cfg.res
        return
    return
  describe 'Filter object', ->
    objects = [
      {
        name: 'o1'
        roleID: 1
        health: 10
        faction: 0
        isAlive: alive
        pos: 0
      }
      {
        name: 'o2'
        roleID: 2
        health: 11
        faction: 1
        isAlive: alive
        pos: 1
      }
      {
        name: 'o3'
        roleID: 3
        health: 12
        faction: 2
        isAlive: alive
        pos: 2
      }
      {
        name: 'o4'
        roleID: 4
        health: 13
        faction: 3
        isAlive: alive
        pos: 3
      }
    ]
    factionDB = 0:
      1: attackable: true
      3: attackable: true
    fo = triggerLib.filterObject
    areaShape = triggerLib.areaShape
    direction = triggerLib.direction
    blocks = undefined
    variable = {}
    env = 
      getFactionConfig: (src, tar, flag) ->
        if factionDB[src] == null or factionDB[src][tar] == null
          return false
        factionDB[src][tar]
      getBlock: (index) ->
        blocks[index]
      variable: ->
        variable

    testThis = (filters, names) ->
      fo({}, objects, filters, env).map((e) ->
        e.name
      ).should.eql names
      return

    alive = ->
      @health > 0

    describe 'Role', ->
      it 'same-faction', ->
        testThis {
          type: 'same-faction'
          faction: 0
        }, [ 'o1' ]
        return
      it 'different-faction', ->
        testThis {
          type: 'different-faction'
          faction: 0
        }, [
          'o2'
          'o3'
          'o4'
        ]
        return
      it 'target-faction-with-flag', ->
        testThis {
          type: 'target-faction-with-flag'
          faction: 0
          flag: 'attackable'
        }, [
          'o2'
          'o4'
        ]
        return
      it 'target-faction-without-flag', ->
        testThis {
          type: 'target-faction-without-flag'
          faction: 0
          flag: 'attackable'
        }, [
          'o1'
          'o3'
        ]
        return
      it 'source-faction-with-flag', ->
        testThis {
          type: 'source-faction-with-flag'
          faction: 3
          flag: 'attackable'
        }, [ 'o1' ]
        return
      it 'source-faction-without-flag', ->
        testThis {
          type: 'source-faction-without-flag'
          faction: 3
          flag: 'attackable'
        }, [
          'o2'
          'o3'
          'o4'
        ]
        return
      it 'role-id', ->
        testThis {
          type: 'role-id'
          roleID: 1
        }, [ 'o1' ]
        return
      it 'alive', ->
        testThis { type: 'alive' }, [
          'o1'
          'o2'
          'o3'
          'o4'
        ]
        return
      it 'sort', ->
        testThis {
          type: 'sort'
          by: 'health'
          reverse: true
        }, [
          'o4'
          'o3'
          'o2'
          'o1'
        ]
        return
      it 'count', ->
        testThis {
          type: 'count'
          count: 3
        }, [
          'o1'
          'o2'
          'o3'
        ]
        return
      it 'anchor', ->
        opt = 
          type: 'anchor'
          anchorPos: [ 17 ]
          shape: areaShape.Line
          startDistance: 1
          length: 3
        opt.direction = direction.North
        testThis opt, [ 'o3' ]
        return
      return
    describe 'anchor', ->

      resetPlayground = ->
        `var testThis`
        blocks = []
        i = 0
        while i < Dungeon_Height
          j = 0
          while j < Dungeon_Width
            blocks[i * Dungeon_Width + j] =
              name: 'x:' + j + ', y:' + i
              pos: i * Dungeon_Width + j
              isBlock: true
            j++
          i++
        return

      resetPlayground()

      testThis = (filters, names) ->
        fo({}, blocks, filters, env).map((e) ->
          e.name
        ).should.eql names
        return

      it 'Line', ->
        opt = 
          type: 'anchor'
          anchorPos: [ 17 ]
          shape: areaShape.Line
          startDistance: 1
          length: 3
        testThis opt, [
          'x:3, y:3'
          'x:4, y:3'
        ]
        opt.direction = direction.NorthEast
        testThis opt, [
          'x:4, y:1'
          'x:3, y:2'
        ]
        opt.direction = direction.South
        testThis opt, [
          'x:2, y:4'
          'x:2, y:5'
        ]
        opt.direction = direction.NorthWest
        testThis opt, [
          'x:0, y:1'
          'x:1, y:2'
        ]
        return
      it 'Cross1', ->
        opt = 
          type: 'anchor'
          anchorPos: [ 17 ]
          shape: areaShape.Cross
          startDistance: 0
          length: 2
        testThis opt, [
          'x:2, y:1'
          'x:2, y:2'
          'x:0, y:3'
          'x:1, y:3'
          'x:2, y:3'
          'x:3, y:3'
          'x:4, y:3'
          'x:2, y:4'
          'x:2, y:5'
        ]
        return
      it 'Cross', ->
        opt = 
          type: 'anchor'
          anchorPos: [ 17 ]
          shape: areaShape.Cross
          startDistance: 1
          length: 1
        testThis opt, [
          'x:2, y:1'
          'x:2, y:2'
          'x:0, y:3'
          'x:1, y:3'
          'x:3, y:3'
          'x:4, y:3'
          'x:2, y:4'
          'x:2, y:5'
        ]
        return
      it 'Cross', ->
        opt = 
          type: 'anchor'
          anchorPos: [ 17 ]
          shape: areaShape.Cross
          startDistance: 1
          length: 0
        testThis opt, [
          'x:2, y:2'
          'x:1, y:3'
          'x:3, y:3'
          'x:2, y:4'
        ]
        return
      it 'Square', ->
        opt = 
          type: 'anchor'
          anchorPos: [ 17 ]
          shape: areaShape.Square
          startDistance: 0
          length: 3
        testThis opt, [
          'x:0, y:0'
          'x:1, y:0'
          'x:2, y:0'
          'x:3, y:0'
          'x:4, y:0'
          'x:0, y:1'
          'x:1, y:1'
          'x:2, y:1'
          'x:3, y:1'
          'x:4, y:1'
          'x:0, y:2'
          'x:1, y:2'
          'x:2, y:2'
          'x:3, y:2'
          'x:4, y:2'
          'x:0, y:3'
          'x:1, y:3'
          'x:2, y:3'
          'x:3, y:3'
          'x:4, y:3'
          'x:0, y:4'
          'x:1, y:4'
          'x:2, y:4'
          'x:3, y:4'
          'x:4, y:4'
          'x:0, y:5'
          'x:1, y:5'
          'x:2, y:5'
          'x:3, y:5'
          'x:4, y:5'
        ]
        return
      it 'Square', ->
        opt = 
          type: 'anchor'
          anchorPos: [ 17 ]
          shape: areaShape.Square
          startDistance: 0
          length: 2
          direction: 7
        testThis opt, [
          'x:2, y:1'
          'x:1, y:2'
          'x:2, y:2'
          'x:3, y:2'
          'x:0, y:3'
          'x:1, y:3'
          'x:2, y:3'
          'x:3, y:3'
          'x:4, y:3'
          'x:1, y:4'
          'x:2, y:4'
          'x:3, y:4'
          'x:2, y:5'
        ]
        return
      it 'Triangle', ->
        opt = 
          type: 'anchor'
          anchorPos: [ 10 ]
          shape: areaShape.Triangle
          startDistance: 0
          length: 3
        testThis opt, [
          'x:2, y:0'
          'x:1, y:1'
          'x:2, y:1'
          'x:0, y:2'
          'x:1, y:2'
          'x:2, y:2'
          'x:1, y:3'
          'x:2, y:3'
          'x:2, y:4'
        ]
        return
      it 'Triangle', ->
        opt = 
          type: 'anchor'
          anchorPos: [ 19 ]
          direction: 7
          shape: areaShape.Triangle
          startDistance: 0
          length: 3
        testThis opt, [
          'x:4, y:1'
          'x:3, y:2'
          'x:4, y:2'
          'x:2, y:3'
          'x:3, y:3'
          'x:4, y:3'
        ]
        return
      return
    return
  obj = 
    name: 'Ken'
    birth:
      year: 1234
      month: 3
      day: 2
    proglan: [
      {
        name: 'C'
        years: 11
      }
      {
        name: 'C++'
        years: 10
      }
      {
        name: 'ASM'
        years: 12
      }
      {
        name: 'JS'
        years: 2
      }
      {
        name: 'Lisp'
        years: 2
      }
    ]
  describe 'Conditions', ->
    conditionCheck = triggerLib.parse
    it 'Should deal with and or not > >= < <= == !=', ->
      trues = [
        { '==': [
          1
          1
        ] }
        { '!=': [
          0
          1
        ] }
        { '>': [
          5
          1
        ] }
        { '>=': [
          5
          1
        ] }
        { '>=': [
          5
          5
        ] }
        { '<=': [
          5
          5
        ] }
        { '<=': [
          5
          5.5
        ] }
        { '<': [
          5
          5.5
        ] }
        true
      ]
      falses = [
        { '==': [
          0
          1
        ] }
        { '!=': [
          1
          1
        ] }
        { '>': [
          1
          5
        ] }
        { '>=': [
          1
          8
        ] }
        { '<=': [
          5.5
          5
        ] }
        { '<': [
          5.6
          5.5
        ] }
        false
      ]
      k = undefined
      for k of trues
        `k = k`
        conditionCheck(trues[k]).should.equal true
        conditionCheck('not': trues[k]).should.equal false
      for k of falses
        `k = k`
        conditionCheck(falses[k]).should.equal false
        conditionCheck('not': falses[k]).should.equal true
      conditionCheck('and': trues).should.equal true
      conditionCheck('or': trues).should.equal true
      conditionCheck('and': trues.concat(falses)).should.equal false
      conditionCheck('or': trues.concat(falses)).should.equal true
      return
    it 'Should work with variable', (done) ->
      formulars = [
        { '==': [
          'v_var1'
          'v_var2'
        ] }
        { '>=': [
          'v_var1'
          'v_var2'
        ] }
        { '<=': [
          'v_var1'
          'v_var2'
        ] }
        { '<=': [
          'v_var1'
          1
        ] }
      ]
      variables = 
        'v_var1': 1
        'v_var2': 1
      for k of formulars
        conditionCheck(formulars[k], variables).should.equal true
      formular = 'and': [
        'v_var1'
        'v_var2'
        'v_var3'
      ]
      variables =
        'v_var1': true
        'v_var2': true
        'v_var3': true
      conditionCheck(formular, variables).should.equal true
      formular = 'and': 'v_var1'
      variables = 'v_var1': [
        true
        true
        true
        true
      ]
      conditionCheck(formular, variables).should.equal true
      done()
      return
    it 'should pass doGetProperty', ->
      tests = [
        {
          key: 'name'
          result: 'Ken'
        }
        {
          key: 'birth.year'
          result: 1234
        }
        {
          key: 'proglan.2.name'
          result: 'ASM'
        }
        {
          key: 'proglan.2.years'
          result: 12
        }
        {
          key: 'proglan.9.years'
          result: undefined
        }
      ]
      tests.forEach (t) ->
        shall(triggerLib.doGetProperty(obj, t.key)).equal t.result
        return
      return
    it 'should pass', ->
      cond1 = 'and': [ { '==': [
        {
          'type': 'getProperty'
          'key': 'stage.0.state'
        }
        2
      ] } ]
      cond2 = 'and': [ { '==': [
        {
          'type': 'getProperty'
          'key': 'name'
        }
        'Ken'
      ] } ]
      tests = [
        {
          cond: cond1
          result: false
        }
        {
          cond: cond2
          result: true
        }
      ]
      tests.forEach (t) ->
        shall(triggerLib.parse(t.cond, obj)).equal t.result
        return
      return
    return
  describe 'Variable', ->
    bind = triggerLib.parse
    it 'Should work', (done) ->
      bind(
        v_var1: 1
        v_var2: 2
        v_var3: 'and': [
          true
          false
        ]).should.eql
        v_var1: 1
        v_var2: 2
        v_var3: false
      done()
      return
    return
  describe 'Calculation', ->
    calculate = triggerLib.parse
    it 'Should work', (done) ->
      calculate('+': [
        { '-': [
          { '*': [
            5
            2
          ] }
          { '/': [
            8
            2
          ] }
        ] }
        3
      ]).should.equal 9
      calculate('&': [
        { '|': [
          { '~': 3 }
          2
        ] }
        2
      ]).should.equal 2
      done()
      return
    return
  describe 'Action', ->
    doAction = triggerLib.parse
    it 'Should work with variables', (done) ->
      v = v_test: 123
      doAction [ {
        type: 'deleteVariable'
        name: 'v_test'
      } ], v
      v.should.eql {}
      doAction [ {
        type: 'newVariable'
        name: 'v_test'
        value: 123
      } ], v
      v.should.eql v_test: 123
      doAction [ {
        type: 'modifyVariable'
        name: 'v_test'
        value: 321
      } ], v
      v.should.eql v_test: 321
      done()
      return
    return
  describe 'Control flow', ->
    parse = triggerLib.parse
    it 'Branch', (done) ->
      v = v_i: 1
      parse {
        if:
          type: 'newVariable'
          name: 'v_test'
          value: 1
        condition: '>': [
          1
          2
        ]
        else: [
          {
            while:
              type: 'modifyVariable'
              name: 'v_i'
              value: '+': [
                1
                'v_i'
              ]
            condition: '<': [
              'v_i'
              3
            ]
          }
          {
            if:
              type: 'newVariable'
              name: 'v_test'
              value: 2
            condition: '==': [
              'v_i'
              3
            ]
          }
        ]
      }, v
      v.should.eql
        v_i: 3
        v_test: 2
      done()
      return
    return
  describe 'TriggerManager', ->
    parse = triggerLib.parse
    tm = triggerLib.TriggerManager
    triggersConf = 
      'test':
        'description': '测试'
        'triggerEvent': [ 'onTestEvent' ]
        'action': [ {
          'type': 'newVariable'
          'name': 'v_flag'
          'value': true
        } ]
      'test1':
        'description': '测试'
        'variable': 'v_flag': false
        'triggerEvent': [ 'onTestEvent' ]
        'condition': 'and': [ 'v_flag' ]
        'action': [ {
          'type': 'newVariable'
          'name': 'v_done'
          'value': true
        } ]
      'test2': 'action': [ {
        'type': 'modifyVariable'
        'name': 'v_flag'
        'value': true
        'trigger': 'test1'
      } ]
      'test3':
        'variable': 'v_count': 0
        'triggerEvent': [ 'onTestEvent' ]
        'action': [ {
          'type': 'modifyVariable'
          'name': 'v_count'
          'value': '+': [
            'v_count'
            1
          ]
        } ]
    tm = new tm(triggersConf)
    tmCmd = getEnvironment: ->
      tm
    it 'Install and Remove', (done) ->
      parse {
        type: 'installTrigger'
        name: 'test'
      }, {}, tmCmd
      tm.triggers.should.have.property 'test'
      parse {
        type: 'removeTrigger'
        name: 'test'
      }, {}, tmCmd
      tm.triggers.should.not.have.property 'test'
      done()
      return
    it 'on event', (done) ->
      parse {
        type: 'installTrigger'
        name: 'test3'
      }, {}, tmCmd
      tm.getTrigger('test3').variables.v_count.should.equal 0
      tm.onEvent 'onTestEvent', tmCmd
      tm.getTrigger('test3').variables.v_count.should.equal 1
      done()
      return
    it 'Enable, disable and invoke', (done) ->
      parse {
        type: 'installTrigger'
        name: 'test3'
      }, {}, tmCmd
      tm.getTrigger('test3').variables.v_count.should.equal 0
      tm.invokeTrigger 'test3'
      tm.getTrigger('test3').variables.v_count.should.equal 1
      tm.disableTrigger 'test3'
      tm.invokeTrigger 'test3'
      tm.getTrigger('test3').variables.v_count.should.equal 1
      tm.enableTrigger 'test3'
      tm.invokeTrigger 'test3'
      tm.getTrigger('test3').variables.v_count.should.equal 2
      done()
      return
    it 'Invoke, condition and modify variable', (done) ->
      parse {
        type: 'installTrigger'
        name: 'test1'
      }, {}, tmCmd
      parse {
        type: 'installTrigger'
        name: 'test2'
      }, {}, tmCmd
      tm.getTrigger('test1').variables.should.not.have.property 'v_done'
      tm.invokeTrigger 'test1', {}, tmCmd
      tm.getTrigger('test1').variables.should.not.have.property 'v_done'
      tm.invokeTrigger 'test2', {}, tmCmd
      tm.invokeTrigger 'test1', {}, tmCmd
      tm.getTrigger('test1').variables.should.have.property 'v_done'
      done()
      return
    return
  return
