require('should');
var libShop = require('../js/shop');

selectElementFromWeightArray = function (array, randNumber) {
    if (!array) {
        logError({action: 'selectElementFromWeightArray', reason: 'emptyArray'});
        return null;
    }
    var total = array.reduce(function (r, l) {return r+l.weight;}, 0);
    if (randNumber < 1) randNumber *= total;
    randNumber = Math.ceil(Math.abs(randNumber%total));
    for (var k in array) {
        if (randNumber <= array[k].weight) {
            if (!array[k]) {
                logError({action: 'selectElementFromWeightArray', reason: 'emptyArray1'});
            }
            return array[k];
        }
        randNumber -= array[k].weight;
    }
    logError({action: 'selectElementFromWeightArray', reason: 'emptyArray2'});
    return null;
};

deepCopy = function (obj) {
    if (typeof obj === 'object') {
        var ret = {};
        if (Array.isArray(obj)) ret = [];
        for (k in obj) {
            var v = obj[k];
            ret[k] = deepCopy(v);
        }
        return ret;
    } else {
        return obj;
    }
};


describe('Shop',function(){
    it('fixed shop', function() {
        var shop_config = {
            type: 'fixed',
            currency: 'gold',
            goods: [
                { id : 1, count: 1, price: 20, limit: {count: 5} },
                { id : 2, count: 1, price: 20 },
                { id : 3, count: 1, price: 20, limit: {vip: 5} }
            ]
        };

        libShop.createShop(shop_config).goods.should.eql([
              { id : 1, count: 1, price: 20, limit: {count: 5} },
              { id : 2, count: 1, price: 20 },
              { id : 3, count: 1, price: 20, limit: {vip: 5} }
        ]);
    });

    it('random shop', function() {
        var shop_config = {
            type: 'random',
            currency: 'diamond',
            goods: [
                [ { weight: 1, id: 1, price: 10 }, { weight: 1, id: 2, price: 1 } ],
                [ { weight: 1, id: 3, price: 10 } ]
            ]
        };

        var goods = libShop.createShop(shop_config).goods;
        if (goods.length != 2 || (goods[0].id != 1 && goods[0].id != 2)) {
            (true).should.equal(false);
        }
    });

    it('none-optional parameters', function() {
        (function(){libShop.createShop({})}).should.throw('Missing Type');
        (function(){libShop.createShop({type: 'fixed'})}).should.throw('Missing currency');
        (function(){libShop.createShop({type: 'fixed', currency: 'gold'})}).should.throw('Missing goods');
        (function(){libShop.createShop({type: 'fixed', currency: 'gold', goods: [ {id: 1} ] })}).should.throw('Missing price');
    });

    it('optional parameters', function() {
        libShop.createShop({
            type: 'fixed',
            currency: 'gold',
            goods: [ { id: 1, price: 10 } ]
        }).goods.should.eql([{id: 1, count: 1, price: 10}]);
    });

    describe('sell goods', function () {
        var shop_config = {
            type: 'fixed',
            currency: 'gold',
            goods: [
              { id : 1, count: 1, price: 20, limit: {count: 5} },
              { id : 2, count: 1, price: 10, limit: {vip: 2} },
              { id : 3, count: 1, price: 20, limit: {vip: 5} }
            ]
        };

        var shop = libShop.createShop(shop_config);
        shop.version = 1;
        var customer = {
            addMoney: function (currency, point) {
                if (point != null && point + this[currency] < 0) {
                    return false;
                }
                if (point != null ) {
                    this[currency] += point;
                }
                return true;
            },
            vipLevel: function () { return 2; },
            gold: 30,
            aquireItem: function () {
                return [{}];
            }
        };

        it('version check', function () {
            (function(){return {error:shop.sell(customer, 0, 1, 0).error}}()).should.eql({
                error: {
                    message: 'Version miss match',
                    data: {
                        source: shop.version,
                        remote: 0
                    }
                }
            });
        });

        it('money check', function () {
            (function(){
                return {error:shop.sell(customer, 0, 2, 1).error}
            }()).should.eql({
                error: {
                    message: 'Insufficient money',
                    data: {
                        index: 0,
                        currency: shop_config.currency,
                        amount: 2 * 20
                    }
                }
            });
        });

        it('vip check', function () {
            (function(){return {error:shop.sell(customer, 2, 1, 1).error}}()).should.eql({
                error: {
                    message: 'Insufficient vip level',
                    data: {
                        index: 2,
                        level: 5
                    }
                }
            });
        });

        it('good trade', function () {
            (function(){return {result:shop.sell(customer, 0, 1, 1).result}}()).should.eql({
                result: {
                    good: { id: 1, count: 1, price: 20 }
                }
            });
            customer.gold.should.equal(10);
            shop.goods[0].limit.count.should.equal(4);
            shop.version.should.equal(2);
        });

        it('version changes if and only if data changes', function () {
            (function(){return {result:shop.sell(customer, 1, 1, 2).result}}()).should.eql({
                result: {
                    good: { id : 2, count: 1, price: 10 }
                }
            });
            customer.gold.should.equal(0);
            shop.version.should.equal(2);
        });
    });
});
