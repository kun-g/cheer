libTrigger = require('../js/trigger')
Condition = libTrigger.Condition
Action = libTrigger.Action
Query = libTrigger.Query
executeSequal = libTrigger.executeSequal
require 'should'
obj = 
  name: 'Before'
  health: 0
  isAlive: ->
    @health > 0
describe 'Sequal', ->
  describe 'Mechanism', ->
    it 'SimpleQuery', ->
      `var obj`
      obj = count: 5
      key = [ 'count' ]
      variables = 
        obj: obj
        key: key
      executeSequal(
        query: 'get_property'
        object: obj
        key: 'count').should.equal 5
      executeSequal({
        query: 'get_property'
        object: '$obj'
        key: 'count'
      }, variables).should.equal 5
      executeSequal({
        query: 'get_property'
        object: obj
        key: '$key.0'
      }, variables).should.equal 5
      executeSequal({
        query: 'get_property'
        object: obj
        key:
          query: 'get_property'
          object: '$key'
          key: '0'
      }, variables).should.equal 5
      return
    return
  describe 'Queries', ->
    it 'get_property', ->
      obj.property =
        attack: 1
        defence: 2
      query = new Query('get_property')
      query.evaluate(obj, 'health').should.equal 0
      query.evaluate(obj, 'property.attack').should.equal 1
      keys = [
        'attack'
        'defence'
      ]
      query.evaluate(query.evaluate(obj, 'property'), query.evaluate(keys, 0)).should.equal 1
      query.evaluate(query.evaluate(obj, 'property'), query.evaluate(keys, 1)).should.equal 2
      return
    return
  return
describe 'Condition', ->
  it 'Alive', ->
    condition = new Condition(predicate: 'alive')
    obj.health = 1
    condition.evaluate(object: obj).should.equal true
    obj.health = 0
    condition.evaluate(object: obj).should.equal false
    return
  it 'Mathmatical Compare', ->
    biggerThanOne = new Condition(
      predicate: '>'
      value2: 1)
    biggerThanOne.evaluate(value1: 0).should.equal false
    biggerThanOne.evaluate(value1: 2).should.equal true
    biggerThanOne.evaluate(
      value1: 2
      value2: 0).should.equal true
    return
  it 'Logic operation', ->
    cTrue = 
      predicate: '>'
      value1: 1
      value2: 0
    cFalse = 
      predicate: '='
      value1: 2
      value2: 1
    trueANDfalse1 = [
      cTrue
      cFalse
    ]
    trueANDfalse2 = and: [
      cTrue
      cFalse
    ]
    trueORfalse = or: [
      cTrue
      cFalse
    ]
    NOTtrueORfalse = not: trueORfalse
    new Condition(cTrue).evaluate().should.equal true
    new Condition(cFalse).evaluate().should.equal false
    new Condition(trueANDfalse1).evaluate().should.equal false
    new Condition(trueANDfalse2).evaluate().should.equal false
    new Condition(trueORfalse).evaluate().should.equal true
    new Condition(NOTtrueORfalse).evaluate().should.equal false
    return
  it 'Composed', ->
    config = 
      predicate: '='
      value1:
        query: 'get_property'
        object: '$Sender'
        key: 'health'
      value2: 1
    condition = new Condition(config)
    condition.addVariable('Sender', health: 1).evaluate().should.equal true
    condition.addVariable('Sender', health: 0).evaluate().should.equal false
    return
  return
describe 'Action', ->
  it 'modify_property', ->
    action = new Action(
      action: 'modify_property'
      key: 'name'
      value: 'Object')
    action.execute object: obj
    obj.name.should.equal 'Object'
    return
  it 'Curring', ->
    action = new Action(
      action: 'modify_property'
      key: 'name')
    action.execute
      value: 'Dummy'
      object: obj
    obj.name.should.equal 'Dummy'
    changeName = new Action(
      action: 'modify_property'
      object: obj
      key: 'name')
    changeName.execute value: 'Before'
    obj.name.should.equal 'Before'
    return
  return
describe 'Trigger', ->
  triggers = 
    modNameWhenAlive:
      condition: [ { predicate: 'alive' } ]
      action:
        action: 'modify_property'
        key: 'name'
        value: 'After'
    resurrect:
      condition: not: predicate: 'alive'
      action:
        action: 'modify_property'
        key: 'health'
        value: 20
  it 'Basic', ->
    preName = obj.name
    modNameWhenAlive = new (libTrigger.Trigger)(triggers.modNameWhenAlive)
    modNameWhenAlive.execute object: obj
    obj.name.should.equal preName
    resurrect = new (libTrigger.Trigger)(triggers.resurrect)
    resurrect.execute object: obj
    modNameWhenAlive.execute object: obj
    obj.name.should.equal 'After'
    return
  return
