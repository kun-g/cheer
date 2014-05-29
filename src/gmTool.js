require('./define');
var dbLib = require('./db');
var async = require('async');
require('./globals');

//players = ['天走卢克', '埃及傲', '萌成喵', '鲍哥', '江湖飘', '飛扬', 
//        'Doyle', '豆豆同学丶', '震北冥', '888666', '蛋町' ];
players = ['jvf'];

//serverName = 'Develop';
serverName = 'Master';

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

function syncItem() {
  require('./helper').initLeaderboard(queryTable(TABLE_LEADBOARD));
  initServer();
  gServerID = -1;
  count = 0;
  dbClient.keys("Master.player.*", function (err, list) {
    list = list.map( function (e) { return e.slice('Master.player.'.length); } );
    list = ['豆豆同学丶'];
    async.map(list,
      function(name, cb) {
        if (list.indexOf(name) < 0) {
          cb();
        } else {
          dbLib.loadPlayer(name, function (err, player) {
            function showInventory() {
              var bag = player.inventory.map(
                function (e, i) {
                  if (!e) return null;
                  var ret = { id: e.id, name: e.label, slot: i };
                  if (e.enhancement) {
                    ret.enhancement = JSON.parse(JSON.stringify(e.enhancement));
                  }
                  if (player.isEquiped(i)) ret.equip = true;
                  return ret;
                })
              .filter( function (e) { return e; } );
              logInfo({ diamond: player.diamond, bag: bag});
            }
            //showInventory();
            if (player.migrate()) {
              console.log(name);
              player.save(cb);
            } else {
              cb();
            }
            player = null;
            //showInventory();
          });
        }
      }, function(err) {console.log('Done', err);});
  });
}

xwrapReceipt = function(receipt) {
  var x = receipt.split('@');
  var id = x[0];
      productID = x[1];
      serverID = x[2];
      time = x[3];
      tunnel = x[4];
  return {
    id: id,
    serverID: +serverID,
    time: +time,
    productID: +productID,
    tunnel: tunnel
  };
};

function loadReceipt () {
  require('./globals');
  list = [
  ];
  moment = require('moment');
  var paymentDB = {};
  function pushPayment(db, month, pay) {
    if (!db[month]) db[month] = [];
    db[month].push(pay);
  }
  function wrapReceipt(id, productID, server, time, tunnel) {
    function pad (num, n) { while (num.length < n) num = '0'+num; return num; }
    id = pad(id.toString(), 8);
    productID = pad(productID.toString(), 2);
    server = pad(server.toString(), 2);
    return id+productID+server+time+tunnel;
  }
  list.forEach( function (e) {
    var x = unwrapReceipt(e);
    if (x.productID < 10) {
    } else {
      x = xwrapReceipt(e);
      if (x.tunnel == null) x.tunnel = 'APP111';
      dbClient.hget('Master.player.'+x.id, 'accountID', function (err, id) { console.log(wrapReceipt(id, x.productID, x.serverID, x.time, x.tunnel)); });
    }
    var time = moment(x.time*1000);
    var rmb = queryTable(TABLE_CONFIG, 'Product_List')[x.productID].rmb;
    pushPayment(paymentDB, time.format('MM'), {rmb: rmb, tunnel: x.tunnel});
    //if (time.format('MM') < 8) console.log(x.time, rmb, e, x.tunnel);
  });
  for (var k in paymentDB) {
    paymentDB[k] =
      paymentDB[k].reduce(
          function (r, e) {
            if (!r[e.tunnel]) r[e.tunnel] = 0;
            r[e.tunnel] += e.rmb;
            return r;
          },
          {}
        );
      }
  //console.log(paymentDB);
  //accountDBClient.keys('Receipt.*', function (err, list) {
  //  console.log(list);
  //  //list.forEach( function (e) { console.log(unwrapReceipt(e)); } );
  //});
}

initGlobalConfig(null, function () {
  loadReceipt ();
});
//async.map(players, function (playerName, cb) {
//  dbLib.deliverMessage(playerName, rewardMessage, cb);
//}, function (err, result) {
//  console.log('Done');
//  dbLib.releaseDB();
//});

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
