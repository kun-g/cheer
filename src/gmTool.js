require('./define');
var dbLib = require('./db');
var async = require('async');
require('./globals');

//players = ['天走卢克', '埃及傲', '萌成喵', '鲍哥', '江湖飘', '飛扬', 
//        'Doyle', '豆豆同学丶', '震北冥', '888666', '蛋町' ];
players = ['jvf','oakk'];

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
    //{type: PRIZETYPE_ITEM, value: 871, count: 1000},//至尊礼包
    {type: PRIZETYPE_ITEM, value: 866, count: 1},//�������
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
    '0000118300011393882339PP25',
    '0000168703011393799422APP111',
    '0000001500011392348155APP111',
    '0000001200011392614569APP111',
    '0000019902011392608462APP111',
    '0000065700011393209471APP111',
    '0000019903011392475337APP111',
    '0000323000011396101164APP111',
    '0000026201011394758829APP111',
    '0000011805011392810113APP111',
    '0000001504011392348088APP111',
    '0000125405011393085645PP25',
    '0000118604011393165353PP25',
    '0000019903011392608284APP111',
    '0000036006011392825112APP111',
    '0000140402011393430283PP25',
    '0000036002011392548156APP111',
    '0000026202011394758389APP111',
    '0000037307011392553572APP111',
    '0000059706011392816116APP111',
    '0000078703011393505148APP111',
    '0000059702011392688594APP111',
    '0000071601011392716412APP111',
    '0000014001011392441246APP111',
    '0000306902011394998654APP111',
    '0000001200011392358187APP111',
    '0000145504011393430792APP111',
    '0000128202011393044247PP25',
    '0000085607011393510451PP25',
    '0000019905011392523993APP111',
    '0000042702011393200528APP111',
    '0000054302011392569058APP111',
    '0000085602011393765973PP25',
    '0000001903011392383875APP111',
    '0000032503011393082130APP111',
    '0000128902011393145057APP111',
    '0000001200011392368657APP111',
    '0000085605011392817634APP111',
    '0000018802011392615074APP111',
    '0000032502011392528228APP111',
    '0000001200011392378035APP111',
    '0000134803011393150035APP111',
    '0000102403011393348965PP25',
    '0000073800011392708427APP111',
    '0000061402011392576202APP111',
    '0000447502011399313267PP25',
    '0000385500011397800238ND91',
    '0000334700011397827706ND91',
    '0000329900011397121082ND91',
    '0000477400011398736336ND91',
    '0000404301011398183831ND91',
    '0000477603011398775089PP25',
    '0000404307011398184390ND91',
    '0000463201011398404014PP25',
    '0000334900011397442385ND91',
    '0000461102011398532729ND91',
    '0000417103011398331412PP25',
    '0000387203011398683935ND91',
    '0000329900011397122950ND91',
    '0000036003011399567086APP111',
    '0000036004011400941838APP111',
    '0000459403011398416485PP25',
    '0000473605011398741398PP25',
    '0000493601011399541297PP25',
    '0000334800011397827494ND91',
    '0000405201011398236390ND91',
    '0000477505011398611269PP25',
    '0000487403011399157695ND91',
    '0000387205011400839327ND91',
    '0000433800011398341956PP25',
    '0000334501011397187870ND91',
    '0000329900011397122101ND91',
    '0000388206011398182526ND91',
    '0000447606011398339291PP25',
    '0000477602011399033700PP25',
    '0000001400011398185928PP25',
    '0000487403011401725227ND91',
    '0000483202011401552231PP25',
    '0000510802011401633094PP25',
    '0000036003011401432598APP111'
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
    var time = moment(x.time*1000);
    var rmb = queryTable(TABLE_CONFIG, 'Product_List')[x.productID].rmb;
    pushPayment(paymentDB, time.format('MM'), {rmb: rmb, tunnel: x.tunnel});
    //if (time.format('MM') < 8) console.log(x.time, rmb, e, x.tunnel);
  });
  //for (var k in paymentDB) {
    //paymentDB[k] =
      //paymentDB[k].reduce(
      //    function (r, e) {
      //      if (!r[e.tunnel]) r[e.tunnel] = 0;
      //      r[e.tunnel] += e.rmb;
      //      return r;
      //    },
      //    {}
      //  );
      //}
  //console.log(paymentDB);
  //accountDBClient.keys('Receipt.*', function (err, list) {
  //  console.log(list);
  //  //list.forEach( function (e) { console.log(unwrapReceipt(e)); } );
  //});
}

initGlobalConfig(null, function () {
  //loadReceipt ();
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
