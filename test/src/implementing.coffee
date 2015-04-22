{implementing} = require('../js/helper')
should = require('should')
assert = require("assert")

class A
  constructor:({name:@name}) ->
    @initA = true

  funcOverride: () ->
    @fo = 'A'

  funcAbstact: () ->
    @fA = 'A'

  test:() ->
    @funcAbstact()
    @funcOverride()

class B
  constructor:(@name,@type) ->
    @initB = true

  funcB: () ->
    @fB = 'B'


Test = implementing(A, B,class Test
  constructor: () ->
    super({
      A:{name:'CA'},
      B:['CB','class']
    })

  funcAbstact:() ->
    @fT = 'T'

  funcOverride:() ->
    @fO = 'T'
    super()

)

test = new Test()
describe('Implementing', ()->
  it('function and property', (done) ->
    test.should.have.property('initA',true)
    test.should.have.property('initB',true)
    ['funcAbstact','funcOverride','test','funcB'].forEach((name) ->
      test[name].should.be.a.Function
    )
    done()
  )
    
  it('function call and override', (done) ->
    test.test()
    test.should.have.property('fo','A')
    test.should.have.property('fO','T')
    done()
  )

  it('function call and overwrite', (done) ->
    test.test()
    assert(not test.fA?)
    test.should.have.property('fO','T')
    done()
  )
)



