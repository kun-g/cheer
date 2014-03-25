var Benchmark = require('benchmark');
var suite = new Benchmark.Suite;

//var translateTable = {
//  name : 'nam',
//  gender : 'gen',
//  class : 'cid',
//  hairStyle : 'hst',
//  hairColor : 'hcl',
//  xp : 'exp',
//  blueStar : 'bst',
//  isFriend: 'ifn',
//  vipLevel: 'vip'
//};
//
//grabAndTranslate = function (data, translateTable) {
//  if (data == null || translateTable == null) return {};
//  var ret = {};
//
//  for (var k in translateTable) {
//    if (data[k] != null) ret[translateTable[k]] = data[k];
//  }
//
//  return ret;
//};

// add tests
suite.add('RegExp#test', function() {
  /o/.test('Hello World!');
})
.add('String#indexOf', function() {
  'Hello World!'.indexOf('o') > -1;
})
// add listeners
.on('cycle', function(event) {
  console.log(String(event.target));
})
.on('complete', function() {
  console.log('Fastest is ' + this.filter('fastest').pluck('name'));
})
// run async
.run({ 'async': true });
