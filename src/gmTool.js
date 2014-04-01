require('./define');
var dbLib = require('./db');
var async = require('async');
require('./globals');

//players = ['天走卢克', '埃及傲', '萌成喵', '鲍哥', '江湖飘', '飛扬', 
//        'Doyle', '豆豆同学丶', '震北冥', '888666', '蛋町' ];
players = ['jvf'];

serverName = 'Develop';
//serverName = 'Master';

var config = {
  Develop: {
    ip: '10.4.3.41',
    port: 6379,
    port2: 6379
  },
  Master: {
    ip: '10.4.4.188',
    port: 6380,
    port2: 6381
  }
};

config = config[serverName];
ip = config.ip;
port = config.port;
port2 = config.port2;
dbPrefix = serverName+'.';

var rewardMessage = {
  type: Event_SystemReward,
  src: MESSAGE_REWARD_TYPE_SYSTEM,
  tit: '奖励',
  txt: '首充奖励',
  prize: [
    //{type: PRIZETYPE_EXP, count: 10000},
    //{type: PRIZETYPE_ITEM, value: 0, count: 50},
    //{type: PRIZETYPE_ITEM, value: 539, count: 2},
    //{type: PRIZETYPE_ITEM, value: 528, count: 1},
    //{type: PRIZETYPE_ITEM, value: 529, count: 1},
    //{type: PRIZETYPE_ITEM, value: 535, count: 1},
    //{type: PRIZETYPE_ITEM, value: 539, count: 1},
    //{type: PRIZETYPE_ITEM, value: 61, count: 1},

    //鮑哥
    //{type: PRIZETYPE_ITEM, value: 539, count: 2}, //大活力药剂
    //{type: PRIZETYPE_ITEM, value: 538, count: 8}, //小活力药剂
    //{type: PRIZETYPE_ITEM, value: 540, count: 27}, //复活

    // 蛋町
    //{type: PRIZETYPE_ITEM, value: 268, count: 1},
    //{type: PRIZETYPE_ITEM, value: 401, count: 1},

    //{type: PRIZETYPE_ITEM, value: 551, count: 1},
    //{type: PRIZETYPE_ITEM, value: 552, count: 1},
    //{type: PRIZETYPE_ITEM, value: 533, count: 99},
    //{type: PRIZETYPE_WXP, count: 10000},
    //{type: PRIZETYPE_GOLD, count: 100000},
    //{type: PRIZETYPE_EXP, count: 10000},
    //{type: PRIZETYPE_DIAMOND, count: 150}
    //{type: PRIZETYPE_WXP, count: 10000},
    //{type: PRIZETYPE_GOLD, count: 100000},
    //{type: PRIZETYPE_DIAMOND, count: 10000},
    //{type: PRIZETYPE_ITEM, value: 533, count: 20}//至尊礼包
    //{type: PRIZETYPE_ITEM, value: 553, count: 1},//至尊礼包
    {type: PRIZETYPE_ITEM, value: 0, count: 1000},//至尊礼包
    //{type: PRIZETYPE_EXP, count: 1000000},
  ]
};
dbLib.initializeDB({
  "Account": { "IP": ip, "PORT": port},
  "Role": { "IP": ip, "PORT": port2},
  "Publisher": { "IP": ip, "PORT": port},
  "Subscriber": { "IP": ip, "PORT": port}
});
async.map(players, function (playerName, cb) {
  dbLib.deliverMessage(playerName, rewardMessage, cb);
}, function (err, result) {
  console.log('Done');
  dbLib.releaseDB();
});

/*
receipt = 'qqd@1@1393082131@3@APP111';

/*
receipt = playerName+'@1@1392358195@0';
dbWrapper = require('./dbWrapper');
console.log(unwrapReceipt(receipt));
dbWrapper.updateReceipt(receipt, RECEIPT_STATE_AUTHORIZED, function (err) {
  dbLib.deliverMessage(playerName, {
    type: MESSAGE_TYPE_ChargeDiamond,
    paymentType: 'PP25',
    receipt: receipt
  }, null, serverName);
  console.log('Err', err);
});
*/
