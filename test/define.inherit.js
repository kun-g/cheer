//var assert = require("assert");
//require('../define');
//
//describe('Define', function () {
//  describe('callback exception handling', function() {
//    it('Should be equal', function() {
//      x = {
//        a:1,
//        b:2,
//        sum : function () {
//          return this.a + this.b;
//        }
//      };
//
//      assert.equal(x.sum(), wrapCallback(x, x.sum)());
//    });
//  });
//
//  describe('#selectElementFromWeightArray', function () {
//    var testTable = [{weight:1, id:1}, {weight:2, id:2}, {weight:3, id:3}, {weight:4, id:4}];
//    it('select 1', function () {
//      assert.equal(1, selectElementFromWeightArray(testTable, 0).id);
//    });
//    it('select 2', function () {
//      assert.equal(2, selectElementFromWeightArray(testTable, 0.12).id);
//      assert.equal(2, selectElementFromWeightArray(testTable, 0.2).id);
//      assert.equal(2, selectElementFromWeightArray(testTable, -0.11).id);
//      assert.equal(2, selectElementFromWeightArray(testTable, 0.283).id);
//    });
//    it('select 3', function () {
//      assert.equal(3, selectElementFromWeightArray(testTable, 0.35).id);
//    });
//    it('select 4', function () {
//      assert.equal(4, selectElementFromWeightArray(testTable, 0.99).id);
//    });
//  });
//
//  describe('#moment', function () {
//    moment = require('moment');
//    helper = require('../helper');
//    it('helper of time', function () {
//      helper.diffDate(1393171200000, '2014/02/24').should.equal(0);
//      helper.diffDate(1393171200000, '2014/02/25').should.equal(1);
//      helper.diffDate('2014/02/24', '2014/02/25').should.equal(1);
//      helper.diffDate('2014/02/23', '2014/02/25').should.equal(2);
//      helper.diffDate('2014/01/01', '2014/02/25').should.equal(55);
//    });
//  });
//
//  describe('#isNameValid', function () {
//    it('Should reject"?"', function () {
//      assert.equal(false, isNameValid('Yes?No?!'));
//      assert.equal(false, isNameValid('Yes.No!'));
//      assert.equal(false, isNameValid('Yes#No'));
//      assert.equal(false, isNameValid('Yes No'));
//      assert.equal(false, isNameValid('%'));
//      assert.equal(false, isNameValid('['));
//      assert.equal(false, isNameValid(']'));
//      assert.equal(false, isNameValid('*'));
//    });
//  });
//
//  describe('#getBasicInfo', function () {
//    var h1 = {name:'p1', gender:1, blueStar:0};
//    it('Should translate existing key', function () {
//      assert.equal(h1.name, getBasicInfo(h1).nam);
//      assert.equal(h1.gender, getBasicInfo(h1).gen);
//      assert.equal(h1.blueStar, getBasicInfo(h1).bst);
//    });
//    it('Should ignore non-existing key', function () {
//      assert.equal(undefined, getBasicInfo(h1).notExist);
//    });
//  });
//
//  describe('#Helper Lib', function () {
//    var helperLib = require('../helper');
//    it('C', function () {
//      helperLib.calculateTotalItemXP({xp: 0, quality: 0, rank: 0}).should.equal(0);
//      helperLib.calculateTotalItemXP({xp: 100, quality: 0, rank: 0}).should.equal(100);
//      helperLib.calculateTotalItemXP({xp: 100, quality: 1, rank: 1}).should.equal(100);
//      helperLib.calculateTotalItemXP({xp: 100, quality: 1, rank: 2}).should.equal(200);
//      helperLib.calculateTotalItemXP({xp: 100, quality: 2, rank: 2}).should.equal(100);
//    });
//  });
//
//  describe('#Mercenary', function () {
//    it('Should x', function () {
//    });
//  });
//});
