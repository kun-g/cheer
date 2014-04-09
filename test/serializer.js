var serialLib = require('../js/serializer');
var shall = require('should');

describe('Serializer', function () {
  function Test () {
    Test.super_.call(this);
    this.attrSave('pNumber', 1);
    this.attrSave('pString', 'init');
    this.attrSave('pObject', {foo: 'bar', t: {foo: 'bar'}});
    this.attrSave('pArray', [1,2,3]);
    this.versionControl('version', ['pNumber', 'pString', 'pObject', 'pArray']);
  }
  require('util').inherits(Test, serialLib.Serializer);
  test = new Test();
  serialLib.registerConstructor(Test);

  it('Should restore from dumped data.', function () {
    test.pNumber = 2;
    test.pString = 'data';
    test.pObject.foo = 'bar1';
    test.pArray.push(4);
    var tmp = serialLib.objectlize(test.dump());
    shall(test.dump()).eql(tmp.dump());
    shall(test.dumpChanged()).eql(test.dump().save);
    shall(test.dumpChanged()).equal(null);
    test.pObject.t = {foo: 'barT'};
    shall(test.dumpChanged()).eql({pObject: {foo: 'bar1',t: {foo: 'barT'}}, version: 6});
    test.pArray.push(5);
    shall(test.dumpChanged()).eql({pArray: [1,2,3,4,5], version: 7});
  });
});
