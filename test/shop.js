require('should');
var libShop = require('../js/shop');

describe('Shop',function(){
    it('fixed shop', function(done) {
        var shop_config = {
            type: 'fixed',
            currency: 'gold',
            goods: [
              { id : 1, count: 1, price: 20 } },
              { id : 2, count: 1, price: 20 } },
              { id : 3, count: 1, price: 20 }, limit: [{vip: 5}] }
            ]
        };

        libShop.createShop(shop_config).goods.should.equal([
              { id : 1, count: 1, price: 20 },
              { id : 2, count: 1, price: 20 },
              { id : 3, count: 1, price: 20, limit: [{vip: 5}] }
        ]);
    });

    it('random shop', function(done) {
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

    it('none-optional parameters', function(done) {
        libShop.createShop({}).should.throw('Missing Type');
        libShop.createShop({type: 'fixed'}).should.throw('Missing currency');
        libShop.createShop({type: 'fixed', currency: 'gold'}).should.throw('Missing goods');
        libShop.createShop({
            type: 'fixed',
            currency: 'gold',
            goods: [ { id : 1 } ]
        }).should.throw('Missing price');
    });

    it('optional parameters', function(done) {
        libShop.createShop({
            type: 'fixed',
            currency: 'gold',
            goods: [ { id: 1, prize: 10 } ]
        }).goods.should.eql([{id: 1, count: 1, prize: 10}]);
    });
});
