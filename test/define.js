require('../js/define');
var shall = require("should");

describe('Define', function () {
  it('callback exception handling Should be equal', function() {
    x = {
      a:1,
      b:2,
      sum : function () {
        return this.a + this.b;
      }
    };

    shall(x.sum()).equal(wrapCallback(x, x.sum)());
  });

  var testTable = [{weight:1, id:1}, {weight:2, id:2}, {weight:3, id:3}, {weight:4, id:4}];
  it('select 1', function () {
    shall(selectElementFromWeightArray(testTable, 0).id).equal(1);
  });
  it('select 2', function () {
    shall(2).equal(selectElementFromWeightArray(testTable, 0.12).id);
    shall(2).equal(selectElementFromWeightArray(testTable, 0.2).id);
    shall(2).equal(selectElementFromWeightArray(testTable, -0.11).id);
    shall(2).equal(selectElementFromWeightArray(testTable, 0.283).id);
  });
  it('select 3', function () {
    shall(3).equal(selectElementFromWeightArray(testTable, 0.35).id);
  });
  it('select 4', function () {
    shall(4).equal(selectElementFromWeightArray(testTable, 0.99).id);
  });

  it('prepareForABtest', function () {
    shall( prepareForABtest([1,2,3,4]) ).eql([[1,2,3,4]]);
    shall( prepareForABtest([1,2,{abtest:[3,4]}]) ).eql([[1,2,3], [1,2,4]]);
  });

  describe('#isNameValid', function () {
    it('Should reject"?"', function () {
      shall(false).equal(isNameValid('Yes?No?!'));
      shall(false).equal(isNameValid('Yes.No!'));
      shall(false).equal(isNameValid('Yes#No'));
      shall(false).equal(isNameValid('Yes No'));
      shall(false).equal(isNameValid('%'));
      shall(false).equal(isNameValid('['));
      shall(false).equal(isNameValid(']'));
      shall(false).equal(isNameValid('*'));
    });
  });

  describe('#getBasicInfo', function () {
    var h1 = {name:'p1', gender:1, blueStar:0};
    it('Should translate existing key', function () {
      shall(h1.name).equal(getBasicInfo(h1).nam);
      shall(h1.gender).equal(getBasicInfo(h1).gen);
      shall(h1.blueStar).equal(getBasicInfo(h1).bst);
    });
    it('Should ignore non-existing key', function () {
      shall(undefined).equal(getBasicInfo(h1).notExist);
    });
  });
});

