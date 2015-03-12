require('should');
var libShop = require('../js/shop');

describe('Shop',function(){
    it('fixed shop', function() {
        var shop_config = {
            type: 'fixed',
            currency: 'gold',
            goods: [
              { id : 1, count: 1, price: 20, limit: {count: 5} } },
              { id : 2, count: 1, price: 20 } },
              { id : 3, count: 1, price: 20 }, limit: {vip: 5} }
            ]
        };

        libShop.createShop(shop_config).goods.should.equal([
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
              [ { weight: 1, id: 1, prize: 10 }, { weight: 1, id: 2, prize: 1 } ],
              [ { weight: 1, id: 3, prize: 10 } ]
            ]
        };

        var goods = libShop.createShop(shop_config).goods;
        if (goods.length != 2 || (goods[0].id != 1 && goods[0].id != 2)) {
            (true).should.equal(false);
        }
    });

    it('none-optional parameters', function() {
        libShop.createShop({}).should.throw('Missing Type');
        libShop.createShop({type: 'fixed'}).should.throw('Missing currency');
        libShop.createShop({type: 'fixed', currency: 'gold'}).should.throw('Missing goods');
        libShop.createShop({
            type: 'fixed',
            currency: 'gold',
            goods: [ { id : 1 } ]
        }).should.throw('Missing price');
    });

    it('optional parameters', function() {
        libShop.createShop({
            type: 'fixed',
            currency: 'gold',
            goods: [ { id: 1, prize: 10 } ]
        }).goods.should.eql([{id: 1, count: 1, prize: 10}]);
    });

    describe('sell goods', function () {
        var shop_config = {
            type: 'fixed',
            currency: 'gold',
            goods: [
              { id : 1, count: 1, price: 20 }, limit: {count: 5} },
              { id : 2, count: 1, price: 10 }, limit: {vip: 2}},
              { id : 3, count: 1, price: 20 }, limit: {vip: 5} }
            ]
        };

        var shop = libShop.createShop(shop_config);
        shop.version = 1;
        var customer = {
            costMoney: function (currency, point) {
                if (point && point > this[type]) {
                    return false;
                }
                if (point) {
                    this[currency] += point;
                }
                return true;
            },
            vipLevel: function () { return 2; },
            gold: 30
        };

        it('version check', function () {
            shop.sell(customer, 0, 1, 0).should.eql({
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
            shop.sell(customer, 0, 2, 1).should.eql({
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

        it('good trade', function () {
            shop.sell(customer, 0, 1, 1).should.eql({
                result: {
                    good: { id: 1, count: 1, price: 20 }
                }
            });
            customer.gold.should.equal(10);
            shop.goods[0].limit.count.should.equal(4);
            shop.version.should.equal(2);
        });

        it('vip check', function () {
            shop.sell(customer, 2, 1, 1).should.eql({
                error: {
                    message: 'Insufficient vip level',
                    data: {
                        index: 0,
                        level: 5
                    }
                }
            });
        });

        it('version changes if and only if data changes', function () {
            shop.sell(customer, 1, 1, 2).should.eql({
                result: {
                    good: { id: 1, count: 1, price: 20 }
                }
            });
            customer.gold.should.equal(0);
            shop.version.should.equal(2);
        });
    });
});
