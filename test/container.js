var shall = require('should');
describe('Container', function () {
  before(function (done) {
    initGlobalConfig('../build/', done);
  });
  var container = require('../js/container');
  var itemLib = require('../js/item');
  it('Should be ok', function () {
    var c = container.Bag(3);
    // single
    shall(c.add(new itemLib.Item(1), 1)[0]).have.property('slot').equal(0);
    c.get(0).should.have.property('count').equal(1);
    c.add(new itemLib.Item(1), 99)[0].should.have.property('slot').equal(0);
    c.get(0).should.have.property('count').equal(99);
    c.get(1).should.have.property('count').equal(1);
    c.add(new itemLib.Item(1), 999)[0].should.have.property('left').equal(802);
    c.add(new itemLib.Item(1), 999)[0].should.have.property('left').equal(999);
    c.get(1).should.have.property('count').equal(99);
    c.get(2).should.have.property('count').equal(99);
    c.add(new itemLib.Item(1), 99)[0].should.have.property('left').equal(99);
    c.removeItemAt(0)[0].should.have.property('slot').equal(0);
    c.removeById(1, 1)[0].should.have.property('slot').equal(1);
    c.removeById(1, 100)[0].should.have.property('slot').equal(1);
    shall(c.get(0)).equal(null);
    shall(c.get(1)).equal(null);
    shall(c.get(2)).have.property('count').equal(97);
    c.removeById(1, 100, true).should.equal(false);
    c.removeItemAt(2);
    shall(c.get(2)).equal(null);
    // multiple
    c.add([
            {item: new itemLib.Item(1), count: 10},
            {item: new itemLib.Item(1), count: 10},
            {item: new itemLib.Item(1), count: 10}
          ]);
    shall(c.add([
          {item: new itemLib.Item(1), count: 100},
          {item: new itemLib.Item(1), count: 100},
          {item: new itemLib.Item(1), count: 100}
        ],
        0, true)).equal(false);
    shall(c.get(0)).have.property('count').equal(30);
    shall(c.get(1)).equal(null);
    shall(c.get(2)).equal(null);
    c.remove([{item: 1, count: 1}, {item: 1, count: 1}]);
    shall(c.remove([{item: 1, count: 20}, {item: 1, count: 20}], null, null, true)).equal(false);
    shall(c.get(0)).have.property('count').equal(28);
    shall(c.get(1)).equal(null);
    shall(c.get(2)).equal(null);
    c.add(new itemLib.Item(540), 26)[0].should.have.property('slot').equal(1);
    shall(c.add([
          {item: new itemLib.Item(1), count: 100},
          {item: new itemLib.Item(1), count: 100},
          {item: new itemLib.Item(1), count: 100}
        ],
        0, true)).equal(false);
    shall(c.add([
          {item: new itemLib.Item(1), count: 101},
          {item: new itemLib.Item(1), count: 102},
          {item: new itemLib.Item(1), count: 103}
        ], 0)[0]).have.property('slot').equal(0);
    shall(c.add(new itemLib.Item(1), 1, true)).equal(false);
    shall(c.get(0)).have.property('count').equal(99);
    shall(c.get(1)).have.property('count').equal(25);
    shall(c.get(2)).have.property('count').equal(1);
    shall(c.get(3)).have.property('count').equal(99);
    shall(c.get(4)).have.property('count').equal(99);
    c.add(new itemLib.Item(540), 26)[0].should.have.property('slot').equal(2);
  });
});
