shall = require('should')
Command = require('../js/commandStream').Command
installCommandExtention = require('../js/commandStream').installCommandExtention
makeCommand = require('../js/commandStream').makeCommand
describe 'Command', ->
  it 'Install extendtion', ->

    test = ->

    test::getCommandConfig = ->

    installCommandExtention test
    obj = new test
    obj.should.have.property 'executeCommand'
    obj.should.have.property 'makeCommand'
    return
  describe 'Basic', ->
    tests = 
      modify_property: ->
        obj = {}
        property = 
          a: 1
          b: 2
          c: 3
        c = makeCommand('modify_property')
        c.execute
          obj: obj
          property: property
        obj.should.eql property
        c.undo()
        obj.should.eql {}
        return
      incress_property: ->
        property = 
          a: 1
          b: 2
          c: 3
        obj = 
          a: 1
          d: 1
        c = makeCommand('incress_property')
        c.execute
          obj: obj
          property: property
        obj.should.eql
          a: 2
          b: 2
          c: 3
          d: 1
        c.undo()
        obj.should.eql
          a: 1
          d: 1
        return
    for k of tests
      t = tests[k]
      if typeof t == 'function'
        it k, t
      else
        console.log 'NotImplemented', typeof t
    return
  return
