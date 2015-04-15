serialLib = require('../js/serializer')
shall = require('should')
describe 'Serializer', ->

  TestObj = (data) ->
    cfg = 
      name: 'K'
      arr: []
    TestObj.super_.call this, data, cfg
    return

  Test = (data) ->
    cfg = 
      pNumber: 1
      pString: 'init'
      pObject:
        foo: 'bar'
        t: foo: 'bar'
      pObj: new TestObj
      pArray: [
        1
        2
        3
      ]
      version: 1
    versionControl = 'version': [
      'pNumber'
      'pString'
      'pObject'
      'pArray'
      'pObj'
    ]
    Test.super_.call this, data, cfg, versionControl
    return

  require('util').inherits Test, serialLib.Serializer
  require('util').inherits TestObj, serialLib.Serializer
  test = new Test
  serialLib.registerConstructor Test
  serialLib.registerConstructor TestObj

  ###
    it('Should restore from dumped data.', function () {
      test.pNumber = 2;
      test.pString = 'data';
      test.pObject.foo = 'bar1';
      test.pArray.push(4);
      var tmp = new Test(test.dumpChanged());
      shall(test.dump()).eql(tmp.dump());
      shall(test.dumpChanged()).equal(null);
      test.pObject.t = {foo: 'barT'};
      shall(test.dumpChanged()).eql({pObject: {foo: 'bar1',t: {foo: 'barT'}}, version: 6});
      test.pArray.push({name: 'K'});
      shall(test.dumpChanged()).eql({pArray: [1,2,3,4,{name: 'K'}], version: 7});
      test.pArray[4].name = 'T';
      shall(test.dumpChanged()).eql({pArray: [1,2,3,4,{name: 'T'}], version: 8});
      test.pObj.name = 'X';
      shall(test.dumpChanged()).eql({pObj: { _constructor_: 'TestObj', save: { name: 'X', arr: [] } }, version: 9});
      test.pObj.arr.push('X');
      shall(test.dumpChanged()).eql({pObj: { _constructor_: 'TestObj', save: { name: 'X', arr: ['X'] } }, version: 10});

      tmp.pObject.t = {foo: 'barT'};
      shall(tmp.dumpChanged()).eql({pObject: {foo: 'bar1',t: {foo: 'barT'}}, version: 6});
      tmp.pArray.push({name: 'K'});
      shall(tmp.dumpChanged()).eql({pArray: [1,2,3,4,{name: 'K'}], version: 7});
      tmp.pArray[4].name = 'T';
      shall(tmp.dumpChanged()).eql({pArray: [1,2,3,4,{name: 'T'}], version: 8});
      tmp.pObj.name = 'X';
      shall(tmp.dumpChanged()).eql({pObj: { _constructor_: 'TestObj', save: { name: 'X', arr: [] } }, version: 9});
      tmp.pObj.arr.push('X');
      shall(tmp.dumpChanged()).eql({pObj: { _constructor_: 'TestObj', save: { name: 'X', arr: ['X'] } }, version: 10});
    });
  ###

  return
