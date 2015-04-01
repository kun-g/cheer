var moment = require('moment');

function Shop() {
  this.version = 0;
  this.stock = [];
}

Shop.prototype.addProduct = function (index, product) {
  if (product == null || index == null) return;
  this.stock[index] = product;
  this.version += 1;
};

Shop.prototype.removeProduct = function (index) {
  delete this.stock[index];
  this.version += 1;
};

Shop.prototype.sellProduct = function (index, count, version, player) {
  if (this.version !== version) return RET_ShopVersionNotMatch;
  if (!player) return RET_PlayerInfoError;
  if (!count || count < 0) count = 1;
  var p = this.stock[index];

  if (p.limit) {
    if (p.limit.vip != null && p.limit.vip > player.vipLevel()) return RET_VipLevelIsLow;
    if (p.limit.count != null) {
      if (p.limit.count <= player.getPurchasedCount(p.id)) {
        return RET_SoldOut;
      } else if (count > p.limit.count) {
        count = p.limit.count;
      }
    }
    var dateLimit = p.limit.date;
    if ( dateLimit != null) {
        var nowTime = moment();
        if (! (nowTime.diff(moment(dateLimit.begin)) >0 && nowTime.diff(moment(dateLimit.end)) < 0)){
            return RET_SoldOut;
        }
    }
  }

  var cost = p.price.amount*count;
  if (p.price && false === player.addMoney(p.price.type, -(cost))) {
    if (p.price.type === 'gold') return RET_NotEnoughGold;
    if (p.price.type === 'diamond') return RET_NotEnoughDiamond;
  }

  logUser({
    name : player.name,
    action : 'buy',
    product : 'shop',
    index : index,
    item : p.id,
    count : count,
    payMethod: p.price.type,
    cost : cost
  });

  if (p.count != null) {
    count *= p.count;
  }

  var ret = player.aquireItem(p.id, count, true);
  if (ret && ret.length > 0) {
    if (p.limit) { player.addPurchasedCount(p.id, count); }
    return ret.concat({NTF: Event_InventoryUpdateItem, arg:{god:player.gold, dim:player.diamond}});
  } else {
    player.addMoney(p.price.type, cost);
    return RET_InventoryFull;
  }
};

Shop.prototype.dump = function (player) {
  var items = gShop.stock.filter(function (p) {
        //if (p.limit && p.limit.vip != null && p.limit.vip > player.vipLevel()) return false;
        return true;
      })
    .map(function (p, index) {
    var ret = {
      sid : index,
      cid : p.id
    };
    if (p.count) ret.cnt = p.count;
    if (p.price) {
      ret.cost = {};
      if (p.price.type === 'gold') ret.cost.gold = p.price.amount;
      if (p.price.type === 'diamond') ret.cost.diamond = p.price.amount;
    }
    if(p.limit && p.limit.date){
        ret.date = p.limit.date;
    }
    return ret;
  });

  var categories = gShop.stock.reduce(function (r, l, cid) {
    if (l.category) {
      l.category.forEach(function (c) {
        if (c) {
          if (r[c.id] == null) r[c.id] = [];
          r[c.id].push(cid);
        }
        return r;
      });
    }
    return r;
  }, []);

  if (items.length <= 0) {
    logError({type:'emptyShopList', stock: gShop.stock});
  }

  return {items : items, categories : categories, version : this.version};
};

//--------------------------------------------------------------------------//

Shop.prototype.sell = function (customer, index, count, version) {
    var ret = {};
    if( this.version !== version ){
        ret.error = {
            message: 'Version miss match',
            data:{
                source: this.version,
                remote: version
            }
        };
        return ret;
    }
    if( customer == null ) throw new Error('Missing customer');
    if( index == null ) throw new Error('Missing index');
    if( count == null || count < 0 ) count = 1;

    var good = this.goods[index];
    if( !good ) throw new Error('Missing good');

    if( good.limit ){
        if (good.limit.vip != null && good.limit.vip > customer.vipLevel()){
            ret.error = {
                message: 'Insufficient vip level',
                data: {
                    index: index,
                    level: good.limit.vip
                }
            };
            return ret;
        }

        if( good.limit.date != null ){
            var dateLimit = good.limit.date;
            var nowTime = moment();
            if (!( nowTime.diff(moment(dateLimit.begin))>0 && nowTime.diff(moment(dateLimit.end))<0 )){
                ret.error = {
                    message: 'sold out',
                    data:{
                        index: index
                    }
                };
                return ret;
            }
        }

        if( good.limit.count != null ){
            if( good.limit.count <= 0 ){
                ret.error = {
                    message: 'sold out',
                    data:{
                        index: index
                    }
                };
                return ret;
            }
            if( good.limit.count < count ){
                count = good.limit.count;
            }
        }
    }

    var cost = good.price * count;
    if( customer.addMoney(this.currency, -cost) === false ){
        ret.error = {
            message: 'Insufficient money',
            data: {
                index: 0,
                currency: this.currency,
                amount: cost
            }
        };
        return ret;
    }

    var itemCount = good.count * count;
    ret.ret = [];
    ret.ret = customer.aquireItem(good.id, itemCount, true);
    if( !(ret.ret && ret.ret.length > 0) ){
        customer.addMoney(this.currency, cost);
        ret.error = {
            message: 'Inventory full'
        };
        return ret;
    }
    ret.ret.concat({NTF: Event_InventoryUpdateItem, arg:{god:customer.gold, dim:customer.diamond, mst:customer.masterCoin}});

    if( good.limit && good.limit.count != null ){
        good.limit.count -= count;
        this.version += 1;
        ret.version = this.version;
    }

    ret.result = {
        good: {id:good.id, count:count, price:good.price}
    };
    ret.ret.concat({NTF: -1, arg:{/*currency:customer[this.currency]*/}}); //todo:

    return ret;
};

Shop.prototype.dump2 = function () {
    var crc = this.currency;
    var goods = this.goods.filter(function (p) {
        //if (p.limit && p.limit.vip != null && p.limit.vip > player.vipLevel()) return false;
        return true;
    }).map(function (p, index) {
        var ret = {
            idx : index,
            cid : p.id,
            cnt : p.count
        };
        ret.cost = {};
        ret.cost[crc] = p.price;
        if(p.limit && p.limit.date){
            ret.date = p.limit.date;
        }
        return ret;
    });

    if (goods.length <= 0) {
        logError({type:'emptyShopList', goods: this.goods});
    }

    return {
        goods: goods,
        version: this.version,
        currency: this.currency,
        resetTime: this.resetTime,
        refCost: this.refreshCurrentCost,
        refTimes: this.refreshTimes
    };
};

var createShop = function(config, shop, refresh){
    if( !config ) throw new Error('Missing Config');
    if( !config.type ) throw new Error('Missing Type');
    if( !config.currency ) throw new Error('Missing currency');
    if( !config.goods ) throw new Error('Missing goods');

    if( shop == null ){
        shop = new Shop();
    }else{
        if( refresh ){
            shop.refreshTimes = (shop.refreshTimes || 0) + 1;
        }
        shop.version = (shop.version || 0) + 1;
    }

    shop.goods = [];
    for( var index in config.goods ){
        var cfg_good = config.goods[index];
        var good = {};
        switch (config.type){
            case 'fixed':
                break;
            case 'random':
                if( Array.isArray(cfg_good)){
                    cfg_good = selectElementFromWeightArray(cfg_good, Math.random());
                }
                break;
            default :

        }
        if( !cfg_good.id ) throw new Error('Missing id');
        good.id = cfg_good.id;
        if( !cfg_good.price ) throw new Error('Missing price');
        good.count = cfg_good.count || 1;
        good.price = cfg_good.price;
        if(cfg_good.limit) good.limit = deepCopy(cfg_good.limit);

        shop.goods.push(good);
    }

    shop.type = config.type;
    shop.currency = config.currency;

    if( config.resetTime ){
        var nowTime = moment();
        if( nowTime.hour() < config.resetTime.hour ||
            (nowTime.hour() == config.resetTime.hour && nowTime.minute() < config.resetTime.minute) ){
            nowTime.subtract(1, 'day');
        }
        nowTime.hour(config.resetTime.hour || 0);
        nowTime.minute(config.resetTime.minute || 0);
        nowTime.second(0);
        shop.resetTime = config.resetTime;
        shop.createTime = nowTime.format();
    }

    // refreshBasicCost:{currency:'diamond', price:50}
    shop.refreshBasicCost = deepCopy(config.refreshBasicCost);

    var REFRESH_FACTOR = 0.5;
    shop.refreshCurrentCost = deepCopy(config.refreshBasicCost);
    shop.refreshCurrentCost.price = Math.floor(shop.refreshBasicCost.price * ( 1 + (shop.refreshTimes || 0) * REFRESH_FACTOR ));

    return shop;
};

exports.createShop = createShop;
exports.Shop = Shop;

gShop = new Shop();
