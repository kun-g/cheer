var serialLib = require('../js/serializer');
var shall = require('should');

describe('Serializer', function () {
//var test = new serialLib.Serializer();
//test.attrSave('pNumber', 1);
//test.attrSave('pString', 'init');
//test.attrSave('pObject', {foo: 'bar', t: {foo: 'bar'}});
//test.attrSave('pArray', [1,2,3]);
//test.versionControl('version', ['pNumber', 'pString', 'pObject', 'pArray']);
//serialLib.registerConstructor(serialLib.Serializer);

//it('Should restore from dumped data.', function () {
//  test.pNumber = 2;
//  test.pString = 'data';
//  test.pObject.foo = 'bar1';
//  test.pArray.push(4);
//  var tmp = serialLib.objectlize(test.dump());
//  shall(test.dump()).eql(tmp.dump());
//  shall(test.dumpChanged()).eql(test.dump().save);
//  shall(test.dumpChanged()).equal(null);
//  test.pObject.t = {foo: 'barT'};
//  shall(test.dumpChanged()).eql( {pObject: {foo: 'bar1',t: {foo: 'barT'}}, version: 6});
//  test.pArray.push(5);
//  shall(test.dumpChanged()).eql({pArray: [1,2,3,4,5], version: 7});
//});
});
