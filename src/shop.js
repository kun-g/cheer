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
  if (this.version !== version) return RET_Unknown;
  if (!player) return RET_Unknown;
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

  ret = player.aquireItem(p.id, count, true);
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

gShop = new Shop();
