describe 'React', ->
  testObject = 
    xp: 0
    property: health: 1
    item: []
  nestedObject = 
    object: testObject
    objVersion: 5
    item: []
  version_config = 
    test:
      basicVersion: [
        'xp'
        'property'
      ]
      itemVersion: [ 'item' ]
    item: [
      'count'
      'property'
    ]
    nest:
      objVersion: [ 'object@test' ]
      dummyVersion: [ 'vipItem' ]
  basicVersion = 0
  itemVersion = 0
  objVersion = 5

  Item = ->
    setupVersionControl this, 'item'
    return

  checkVersion = ->
    testObject.should.have.property('basicVersion').equal basicVersion
    testObject.should.have.property('itemVersion').equal itemVersion
    nestedObject.should.have.property('objVersion').equal objVersion
    return

  it 'set up', ->
    setupVersionControl testObject, 'test'
    setupVersionControl nestedObject, 'nest'
    checkVersion()
    return
  it 'basic change', ->
    testObject.xp = 1
    basicVersion += 1
    objVersion += 1
    checkVersion()
    testObject.property.health += 3
    basicVersion += 1
    objVersion += 1
    checkVersion()
    return
  it 'new property', ->
    testObject.property.speed = 5
    basicVersion += 1
    objVersion += 1
    checkVersion()
    testObject.power = 1024
    checkVersion()
    nestedObject.power = 1024
    checkVersion()
    nestedObject.vipItem = new Item
    objVersion += 1
    checkVersion()
    nestedObject.vipItem.property = {}
    objVersion += 1
    checkVersion()
    return
  it 'array', ->
    nestedObject.item.push testObject.vipItem
    checkVersion()
    testObject.item.push testObject.vipItem
    itemVersion += 1
    objVersion += 1
    checkVersion()
    testObject.item.push new Item
    itemVersion += 1
    objVersion += 1
    checkVersion()
    testObject.item[5] = new Item
    itemVersion += 4
    objVersion += 4
    checkVersion()
    testObject.item.pop()
    itemVersion += 1
    objVersion += 1
    checkVersion()
    return
  it 'dont change', ->
    testObject.xp = 1
    checkVersion()
    testObject.xp = '1'
    basicVersion += 1
    objVersion += 1
    checkVersion()
    testObject.xp = '1'
    checkVersion()
    return
  it 'new object property', ->
    testObject.property.appearance = hair: 1
    basicVersion += 1
    objVersion += 1
    checkVersion()
    testObject.property.appearance = hair: 1
    basicVersion += 1
    objVersion += 1
    checkVersion()
    testObject.property.appearance.hair += 1
    basicVersion += 1
    objVersion += 1
    checkVersion()
    return
  it 'combo', ->
    nestedObject.vipItem.property.count = 5
    itemVersion += 1
    basicVersion += 1
    objVersion += 2
    checkVersion()
    return
  it 'observe', ->
    xpVersion = 0
    testObject.observe 'xp', ->
      xpVersion += 1
      return
    testObject.xp += 1
    basicVersion += 1
    objVersion += 1
    checkVersion()
    xpVersion.should.equal 1
    return
  it 'this observer should fail', ->
    try
      testObject.observe 'xp', function_that_not_exist
      throw 'Why don\'t you fail'
    catch e
      e.message.should.not.equal 'Why don\'t you fail'
    try
      testObject.observe 'key_that_not_exist', console.log
      throw 'Why don\'t you fail'
    catch e
      e.message.should.not.equal 'Why don\'t you fail'
    return
  it 'tell me what has changed', ->
    testObject.getChangedInfo()
    testObject.xp = 5
    testObject.getChangedInfo().should.equal xp: 5
    testObject.getChangedInfo().should.equal {}
    testObject.item[0].property.count = 10
    testObject.xp = 6
    testObject.getChangedInfo().should.equal
      xp: 5
      item: 0: property: count: 10
    nestedObject.getChangedInfo().should.equal vipItem: property: count: 10
    return
  return
