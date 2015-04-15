require '../js/define'
shall = require('should')
describe 'Define', ->
  describe 'Shuffle', ->

    localRand = ->
      0.5

    it 'should work', ->
      data = [
        1
        2
        3
        4
        5
      ]
      newShuffle data, localRand
      data.should.eql [
        3
        4
        2
        5
        1
      ]
      return
    return
  it 'callback exception handling Should be equal', ->
    x =
      a: 1
      b: 2
      sum: ->
        @a + @b
    shall(x.sum()).equal wrapCallback(x, x.sum)()
    return
  testTable = [
    {
      weight: 1
      id: 1
    }
    {
      weight: 2
      id: 2
    }
    {
      weight: 3
      id: 3
    }
    {
      weight: 4
      id: 4
    }
  ]
  it 'select 1', ->
    shall(selectElementFromWeightArray(testTable, 0).id).equal 1
    return
  it 'select 2', ->
    shall(2).equal selectElementFromWeightArray(testTable, 0.12).id
    shall(2).equal selectElementFromWeightArray(testTable, 0.2).id
    shall(2).equal selectElementFromWeightArray(testTable, -0.11).id
    shall(2).equal selectElementFromWeightArray(testTable, 0.283).id
    return
  it 'select 3', ->
    shall(3).equal selectElementFromWeightArray(testTable, 0.35).id
    return
  it 'select 4', ->
    shall(4).equal selectElementFromWeightArray(testTable, 0.99).id
    return
  it 'prepareForABtest', ->
    shall(prepareForABtest([
      1
      2
      3
      4
    ])).eql [ [
      1
      2
      3
      4
    ] ]
    shall(prepareForABtest([
      1
      2
      { abtest: [
        3
        4
      ] }
    ])).eql [
      [
        1
        2
        3
      ]
      [
        1
        2
        4
      ]
    ]
    return
  describe '#isNameValid', ->
    it 'Should reject"?"', ->
      shall(false).equal isNameValid('Yes?No?!')
      shall(false).equal isNameValid('Yes.No!')
      shall(false).equal isNameValid('Yes#No')
      shall(false).equal isNameValid('Yes No')
      shall(false).equal isNameValid('%')
      shall(false).equal isNameValid('[')
      shall(false).equal isNameValid(']')
      shall(false).equal isNameValid('*')
      return
    return
  describe '#getBasicInfo', ->
    h1 = 
      name: 'p1'
      gender: 1
      blueStar: 0
    it 'Should translate existing key', ->
      shall(h1.name).equal getBasicInfo(h1).nam
      shall(h1.gender).equal getBasicInfo(h1).gen
      return
    it 'Should ignore non-existing key', ->
      shall(undefined).equal getBasicInfo(h1).notExist
      return
    return
  return
