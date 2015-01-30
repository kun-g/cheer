RECEIPT_STATE_NEW = 'NEW';
RECEIPT_STATE_FAIL = 'FAIL';
RECEIPT_STATE_AUTHORIZED = 'AUTHORIZED';
RECEIPT_STATE_DELIVERED = 'DELIVERED';
RECEIPT_STATE_CLAIMED = 'CLAIMED';

MESSAGE_TYPE_FriendApplication = 200;
MESSAGE_TYPE_SystemReward = 201;
MESSAGE_TYPE_ChargeDiamond = 202;

CHAT_TYPE_PLAYER = 0;
CHAT_TYPE_SYSTEM = 1;
CHAT_TYPE_BROADCAST = 2;

Event_UpdateStageInfo = 12;
Event_DungeonReward = 13;
Event_MercenaryList = 14;
Event_UpdateDungeon = 15;
Event_UpdateEnergy = 17;
Event_UpdateExp = 18;
Event_ChatInfo = 20;
Event_FriendInfo = 21;
Event_CampaignUpdate = 22;
Event_TutorialInfo = 23;
Event_PlayerInfo = 24;
Event_Broadcast = 25;
Event_ABIndex = 26;
Event_UpdateDailyQuest = 27;
Event_UpdateFlags = 28;
Event_UpdateCounters = 29;
Event_BountyUpdate = 30;

Event_ExpiredPID = 100;
Event_Echo = 101;
Event_UpdateBinary = 102;
Event_UpdateResource = 103;

Event_FriendApplication = 200;
Event_SystemReward = 201;

Event_CampaignLoginStreak = 300;

Request_SyncData = 0;
RPC_StoreBuyItem = 9;
Request_StoreUpdateItemRemain = 10;
Request_ClaimDungeonReward = 11; // [sid]
RPC_RequireMercenaryList = 12; // nop
RPC_RefreshMercenaryList = 13; // id list
RPC_BuyFeature = 16;
RPC_ClaimQuestReward = 18;
RPC_Chat = 19;
RPC_InviteFriend = 21;
RPC_RemoveFriend = 22;
RPC_HireFriend = 23;
RPC_Whisper = 24;
RPC_OperateNotify = 25;
RPC_RoleInfo = 26;
Request_TutorialStageComplete = 27;
Request_Stastics = 28;
RPC_ClaimLoginStreakReward = 300;

function fixNumber(num, len){
    var str = ""+num;
    if( str.length > len ){
        str = str.substr(0, len);
    }
    while(str.length < len){
        str = "0" + str;
    }
    return str;
}

wrapReceipt = function(id, pid, zoneId, sid, time, tunnel) {
    var actorName = fixNumber(id, 8);
    var productId = fixNumber(pid, 2);
    var zoneId = fixNumber(zondId, 2);
    var time = fixNumber(Math.floor((new Date()).valueOf/1000), 10);
    return actorName+productId+zoneId+time+tunnel;
}

unwrapReceipt = function(receipt) {
  var id = receipt.slice(0, 8),
      productID = receipt.slice(8, 10),
      serverID = receipt.slice(10, 12),
      time = receipt.slice(12, 22),
      tunnel = receipt.slice(22, receipt.length);
  return {
    id: +id,
    serverID: +serverID,
    time: +time,
    productID: +productID,
    tunnel: tunnel
  };
};

var zlib = require('zlib');
var http = require('http');
postPaymentInfo = function (level, orderID) {
  var info = unwrapReceipt(orderID);
  var productList = queryTable(TABLE_IAP, 'list');
  var cfg = productList[info.productID];
  if (!cfg) return ;
  var currencyAmount = cfg.rmb;
  var virtualCurrencyAmount = cfg.diamond;
  var serverID = gServerID;
  var gameVersion = queryTable(TABLE_VERSION, 'bin_version') + '@' + queryTable(TABLE_VERSION, 'resource_version');

  var options = {
    host: 'api.talkinggame.com',
    port: 80,
    method: 'POST',
    path: '/api/charge/25DEA3B267F80E2AA9BDA3F4D9F23A88'
  };
  req = http.request(options, function (res) {
    var gunzip = zlib.createGunzip();
    res.pipe(gunzip);
    gunzip.on('data', function (chunk) {
      //console.log(chunk.toString());
    });
  });
  req.on('error', function (e) { logError({action: 'talkinggame', error: JSON.stringify(e)}); });
  var gzip = zlib.createGzip();
  gzip.pipe(req);
  var payment = {
    msgID: 0,
    status: 'success', 
    OS: 'ios',
    accountID: info.name,
    orderID: orderID,
    currencyAmount: currencyAmount,
    currencyType: 'CNY',
    virtualCurrencyAmount: virtualCurrencyAmount,
    chargeTime: +info.time*1000,
    paymentType: info.tunnel,
    gameServer: serverID,
    gameVersion: gameVersion
  };
  if (level > 0) { payment.level = level; }
  gzip.write(JSON.stringify([payment]));
  gzip.end();
};
gPlayerDB = [];

time_format = "YYYY-MM-DDTHH:mm:ss";

md5Hash = function (data) {
  var hash = require('crypto').createHash('md5');
  hash.update(data);
  return hash.digest('hex');
};

isClassMatch = function (myClass, classLimit) {
  if (!classLimit) return true;
  return classLimit.reduce(function (r, l) { return r || myClass === l; }, false);
};
