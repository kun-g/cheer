"use strict";
var dbLib = require('./db');
require('./shop');

var handle = {};
function addHandler (index, func, args, description, needPid) {
  var arg = [];
  for (var i = 0; i < args.length; i+=2) { arg[args[i]] = args[i+1]; }
  var handler = { 'func': func, 'args': arg, 'description': description, needPid:needPid };

  handle[index] = handler;
}

function handler_syncData(arg, player, handler) {
  var ev = [];

  //logWarn({ action : 'syncData', arg : arg });

  arg.forEach(function (e) {
    if (e == 'inv') { ev.push(player.syncBag(true)); }
    else if (e == 'fog') { ev = ev.concat(player.syncFurance(true)); }
    else if (e == 'stg') { ev = ev.concat(player.syncStage(true)); }
    else if (e == 'act') { ev = ev.concat(player.syncHero(true)); }
    else if (e == 'dgn') { ev = ev.concat(player.syncDungeon(true)); }
    else if (e == 'eng') { ev = ev.concat(player.syncEnergy(true)); }
    else if (e == 'qst') { ev = ev.concat(player.syncQuest(true)); }
    //else if (e == 'frd') { ev = ev.concat(player.syncQuest(true)); }
  });
  handler( ev );
}
addHandler(Request_SyncData, handler_syncData, [], '', true);

dbWrapper = require('./dbWrapper');
function handler_queryRoleInfo(arg, player, handler, rpcID) {
  dbWrapper.getPlayerHero(arg.nam, function (err, hero) {
    if (hero) {
      handler([{REQ : rpcID, RET : RET_OK, arg: getBasicInfo(hero)}]);
    } else {
      handler([{REQ : rpcID, RET : RET_PlayerNotExists}]);
    }
  });
}
addHandler(RPC_RoleInfo, handler_queryRoleInfo, [], '', true);

/*
 * Dungeon
 */
function handler_exploreDungeon(arg, player, handler, reqID, socket, flag, req) {
  handler(player.dungeonAction(req));
  player.saveDB();
}
addHandler(Request_DungeonExplore, handler_exploreDungeon, ['tar', 'number'], 'Request to move around', true);

function handler_doActivate(arg, player, handler, reqID, socket, flag, req) {
  handler(player.dungeonAction(req));
  player.saveDB();
}
addHandler(Request_DungeonActivate, handler_doActivate, ['tar', 'number'], 'try to triger an mechanism', true);

function handler_doAttack(arg, player, handler, reqID, socket, flag, req) {
  handler(player.dungeonAction(req));
  player.saveDB();
}
addHandler(Request_DungeonAttack, handler_doAttack, ['tar','number'], 'doAttack', true);

function handler_doSpell(arg, player, handler, reqID, socket, flag, req) {
  handler(player.dungeonAction(req));
  player.saveDB();
}
addHandler(Request_DungeonSpell, handler_doSpell, [], 'try to cast a spell', true);

function  handler_doCancelDungeon(arg, player, handler, reqID, socket, flag, req) {
  handler(player.dungeonAction(req));
  player.saveDB();
}
addHandler(REQUEST_CancelDungeon, handler_doCancelDungeon, [], '', true);

function  handler_doCheckPos(arg, player, handler, reqID, socket, flag, req) {
  handler(player.dungeonAction(req));
  player.saveDB();
}
addHandler(Request_DungeonValidatePos ,  handler_doCheckPos, [], '', true);


function  handler_doRevive(arg, player, handler, reqID, socket, flag, req) {
  handler(player.dungeonAction(req));
  player.saveDB();
}
addHandler(Request_DungeonRevive, handler_doRevive, [], '', true);

function handler_doCardSpell(arg, player, handler, reqID, socket, flag, req) {
  var ret = player.dungeonAction(req);
  if (ret == null) {
    ret = [{NTF:Event_Fail, msg : '_FIXME_Response_Invalid@'+'handler_doCardSpell'}];
  }
  handler(ret);
  player.saveDB();
}
addHandler(Request_DungeonCard, handler_doCardSpell, ['slt', 'number'], 'do Card spell', true);

/*
 * Request_DungeonUseItem = 7,
 * args:
  * sid 位置
  * opn 操作
 */
var USE_ITEM_OPT_EQUIP = 1;
var USE_ITEM_OPT_ENHANCE = 2;
var USE_ITEM_OPT_LEVELUP = 3;
var USE_ITEM_OPT_CRAFT = 4;
var USE_ITEM_OPT_DECOMPOSE = 5;
var USE_ITEM_OPT_INJECTWXP = 6;
var USE_ITEM_OPT_RECYCLE = 7; // 分解装备
var USE_ITEM_OPT_SELL = 8; // 出售
function handler_doUseItem(arg, player, handler, rpcID) {
  var slot = Math.floor(arg.sid);
  var opn = Math.floor(arg.opn);

  var ret = null;
  switch (opn) {
    case USE_ITEM_OPT_INJECTWXP:
      ret = player.injectWXP(arg.opd, slot);
      break;
    case USE_ITEM_OPT_SELL:
      ret = player.sellItem(slot, arg.sho);
      break;
    case USE_ITEM_OPT_LEVELUP:
      ret = player.levelUpItem(slot, arg.sho);
      break;
    case USE_ITEM_OPT_ENHANCE:
      ret = player.enhanceItem(slot);
      break;
    case USE_ITEM_OPT_RECYCLE:
      ret = player.recycleItem(slot);
      break;
    case USE_ITEM_OPT_DECOMPOSE:
      ret = player.transformGem(arg.cid, arg.opc);
      break;
    case USE_ITEM_OPT_CRAFT:
      ret = player.upgradeItemQuality(slot);
      break;
    default:
      ret = player.useItem(slot, opn);
      break;
  }

  var evt = {REQ : rpcID, RET : RET_OK};
  if (ret.ret) evt.RET = ret.ret;
  if (ret.res) evt.RES = ret.res;
  if (ret.prize) evt.prz = ret.prize;
  if (ret.out) evt.out = ret.out;
  var res = [evt];
  if (ret.ntf) res = res.concat(ret.ntf);
  handler(res);
  player.saveDB();
}
addHandler(Request_DungeonUseItem, handler_doUseItem,
    ['sid', 'number', 'opn', 'number'], 'try to use', true);

function handler_doRequireMercenaryList(arg, player, handler, rpcID) {
  player.mercenary = [];
  player.requireMercenary(function (lst) {
    if (lst) {
      handler([{REQ : rpcID, RET : RET_OK},
        {NTF: Event_MercenaryList, arg : lst.map(getBasicInfo)}]);
    } else {
      handler({REQ : rpcID, RET : RET_RequireMercenaryFailed});
    }
  });
  player.saveDB();
}
addHandler(RPC_RequireMercenaryList,  handler_doRequireMercenaryList,
    [], 'RequireMercenaryList', true);

function handler_doClaimLoginStreakReward(arg, player, handler, rpcID) {
  var ret = player.claimLoginReward();
  var res = [{REQ: rpcID, RET: ret.ret}];
  if (ret.res) res = res.concat(ret.res);
  if (ret.ret === RET_OK) player.saveDB();
  handler(res);
}
addHandler(RPC_ClaimLoginStreakReward,  handler_doClaimLoginStreakReward, [], '', true);


// Request_RefreshRefreshMercenaryList
function handler_doRefreshMercenaryList(arg, player, handler, rpcID) {
  if (player.addGold(RECRUIT_COST)) {
    player.log('refreshMercenaryList')

    player.replaceMercenary(arg.sid, function (teammate) {
      handler([{REQ : rpcID, RET : RET_OK, arg : getBasicInfo(teammate)}, {NTF: Event_InventoryUpdateItem, arg:{god:player.gold}}]);
    });
  } else {
    handler([{REQ : rpcID, RET : RET_NotEnoughGold}]);
  }
  player.saveDB();
}
addHandler(RPC_RefreshMercenaryList, handler_doRefreshMercenaryList, [], '', true);

// Request_ClaimDungeonReward 
function handler_doCalimDungeonReward(arg, player, handler) {
  //var ret = player.claimDungeonAward();
  //handler(ret);
  player.saveDB();
}
addHandler(Request_ClaimDungeonReward,  handler_doCalimDungeonReward,
    [], 'Calim Dungeon Reward', true);

function handler_doBuyItem(arg, player, handler, rpcID) {

  var ret = gShop.sellProduct(arg.sid, arg.cnt, arg.ver, player);
  if (typeof ret == 'number') {
    handler([{REQ : rpcID, RET : ret}]);
  } else {
    handler([{REQ : rpcID, RET : RET_OK}].concat(ret));
  }
  player.saveDB();
}
addHandler(RPC_StoreBuyItem, handler_doBuyItem, [], 'Money!!', true);

function handler_doBuyEnergy(arg, player, handler, rpcID) {
  var diamondCost = 0;
  var ENERGY_ADD;
  switch (+arg.typ) {
    case FEATURE_ENERGY_RECOVER: 
      if (player.counters.energyRecover >= player.vipOperation('dayEnergyBuyTimes')){
          handler(new Error(RET_DungeonNotExist));
          return;
      }
      var recoverTimes = player.counters.energyRecover;
      var ret = buyEnergyCost(recoverTimes,
              player.vipOperation('freeEnergyTimes'),
              player.vipOperation('energyPrize')); 
      diamondCost = ret.prize;
      ENERGY_ADD = ret.add ;
      break;
    case FEATURE_INVENTORY_STROAGE: 
      var x = Math.floor((player.inventory.size() - 30)/5);
      if (x > 5) x = 5;
      diamondCost = 30*x + 50;
      break;
    case FEATURE_FRIEND_STROAGE: 
      var x = Math.floor((player.contactBook.limit - 20)/5);
      if (x > 5) x = 5;
      diamondCost = 30*x + 50;
      break;
    case FEATURE_FRIEND_GOLD: diamondCost = +arg.tar; break;
    case FEATURE_PK_COOLDOWN: diamondCost = 50; break;
    case FEATURE_PK_COUNT: diamondCost = 100; break;
    case FEATURE_REVIVE: 
      if(typeof player.dungeon == 'undefined' || player.dungeon == null) {
        handler(new Error(RET_DungeonNotExist));
        return;
      }
      diamondCost = buyReviveCost(player.dungeon.revive, 0,player.vipOperation('reviveBasePrice')); 
      break;
  }
  var evt = [];
  var product = '';
  if (diamondCost && player.addDiamond(-Math.ceil(diamondCost)) !== false) {
    evt.push({REQ : rpcID, RET : RET_OK});
    if (+arg.typ === FEATURE_ENERGY_RECOVER) {
      player.energy += ENERGY_ADD;
      player.counters.energyRecover++;
      product = 'energyTime';
      evt.push(player.syncEnergy());
      evt.push(player.syncCounters(['energyRecover']));
      evt.push({ NTF: Event_InventoryUpdateItem, arg : {dim : player.diamond }});
    } else if (+arg.typ === FEATURE_INVENTORY_STROAGE) {
      product = 'inventory';
      evt.push({NTF: Event_InventoryUpdateItem, 
        arg: {
          cap : player.extendInventory(5),
          dim : player.diamond 
        }
      });
    } else if (+arg.typ === FEATURE_FRIEND_STROAGE) {
      product = 'friend';
      player.contactBook.limit = +player.contactBook.limit + 5;
      dbLib.extendFriendLimit(player.name);
      evt.push({NTF: Event_FriendInfo, arg: { cap : player.contactBook.limit } });
      evt.push({NTF: Event_InventoryUpdateItem, arg: { dim : player.diamond } });
    } else if (+arg.typ === FEATURE_FRIEND_GOLD) {
      player.addGold(diamondCost*Rate_Gold_Diamond);
      evt.push({NTF: Event_InventoryUpdateItem, arg: {
        dim: player.diamond,
        god: player.gold
      } });
    } else if (+arg.typ === FEATURE_PK_COOLDOWN) {
      player.clearCDTime();
      evt.push({NTF: Event_InventoryUpdateItem, arg: {
        dim: player.diamond
      } });
    } else if (+arg.typ === FEATURE_PK_COUNT) {
      player.addPkCount(1);
      evt.push({NTF: Event_InventoryUpdateItem, arg: {
        dim: player.diamond
      } });
    } else if (+arg.typ === FEATURE_REVIVE) {
        ret = player.aquireItem(ItemId_RevivePotion , 1, true);
        if (ret && ret.length > 0) {
            evt = evt.concat(ret.concat({
                            NTF: Event_InventoryUpdateItem, 
                            arg:{god:player.gold, dim:player.diamond}}));
        } else {
            player.addMoney(p.price.type, cost);
            evt = [{REQ : rpcID, RET : RET_NotEnoughDiamond}];
        } ;
    }
    player.saveDB();
  } else {
    evt = [{REQ : rpcID, RET : RET_NotEnoughDiamond}];
  }

  logUser({
    name : player.name,
    action : 'buy',
    product : product,
    payMethod: 'diamond',
    item: product,
    cost : diamondCost
  });

  handler(evt);
}
addHandler(RPC_BuyFeature, handler_doBuyEnergy, [], 'Money!!', true);

function handler_doClaimQuestReward(arg, player, handler, rpcID) {
  var ret = player.claimQuest(arg.qid);
  if (typeof ret == 'number') {
    handler([{REQ : rpcID, RET : ret}]);
  } else {
    handler([{REQ : rpcID, RET : RET_OK}].concat(ret));
  }
  player.saveDB();
}
addHandler(RPC_ClaimQuestReward, handler_doClaimQuestReward, [], 'Money!!', true);

function handler_doUpdateTutorial(arg, player, handler, rpcID) {
  player.log('updateTutorial', {tutorial: arg.stg});
  player.tutorialStage = +arg.stg;
  player.saveDB();
}
addHandler(Request_TutorialStageComplete, handler_doUpdateTutorial, [], '', true);

function handler_doChat(arg, player, handler, rpcID) {
  dbLib.broadcast({
    NTF:Event_ChatInfo, 
    arg: {
      src: player.name,
      typ: CHAT_TYPE_PLAYER,
      txt: arg.txt,
      vip: player.vipLevel(),
      cla: player.hero.class,
      pow: player.battleForce
    }
  });

  logUser({
    name : player.name,
    action : 'chat',
    type : 'global',
    text : arg.txt
  });

  //TODO:聊天信息间隔
  handler({REQ : rpcID, RET : RET_OK});
}
addHandler(RPC_Chat, handler_doChat, [], 'Money!!', true);

function handler_doInviteFriend(arg, player, handler, rpcID) {
  player.inviteFriend(arg.nam, arg.id, function (err, ret) {
    handler({REQ: rpcID, RET: err.message});
  });
}
addHandler(RPC_InviteFriend, handler_doInviteFriend, [], 'Money!!', true);
 
function handler_doRemoveFriend(arg, player, handler, rpcID) {
  handler({REQ : rpcID, RET : player.removeFriend(arg.nam)});
}
addHandler(RPC_RemoveFriend, handler_doRemoveFriend, [], 'Money!!', true);

function handler_doHireFriend(arg, player, handler, rpcID) {
  player.hireFriend(arg.nam, function (lst) {
    if (Array.isArray(lst)) {
      handler([{REQ : rpcID, RET : RET_OK},
        {NTF: Event_MercenaryList, arg : lst.map(getBasicInfo)}]);
    } else {
      handler({REQ : rpcID, RET : RET_HireFriendFailed});
    }
  });
}
addHandler(RPC_HireFriend, handler_doHireFriend, [], 'Money!!', true);

function handler_doWhisper(arg, player, handler, rpcID) {
  player.whisper(arg.nam, arg.txt, function (err, ret) {
    if (err == null) err = RET_OK;
    handler({REQ : rpcID, RET : err});
  });
}
addHandler(RPC_Whisper, handler_doWhisper, [], '', true);

function handler_doOperateNotify(arg, player, handler, rpcID) {
  player.operateMessage(arg.typ, arg.sid, arg.opn, function (err, ret) {
    if (err == null) err = RET_OK;
    if (ret) {
      ret = [{REQ: rpcID, RET: err}].concat(ret);
    } else {
      ret = [{REQ: rpcID, RET: err}];
    }
    handler(ret);
    player.saveDB();
  });
}
addHandler(RPC_OperateNotify, handler_doOperateNotify, [], '', true);

exports.route = handle;
