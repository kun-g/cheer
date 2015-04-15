shall = require('should')
helpLib = require('../js/helper')
dbWrapper = require('../js/dbWrapper')
playerLib = require('../js/player')
async = require('async')
reqh = require('../js/requestHandlers')
#describe('Helper', function () {
#  describe('React programming', function () {
#    var tap = helpLib.tap;
#    function generate(marker) {
#      return function (key, val) {
#        if ( marker[key] ) {
#          marker[key] += 1;
#        } else {
#          marker[key] = 1;
#        }
#      };
#    }
#    var obj = {name: 'Obj', age: 3, friend: ['Tx'], equip: {body: 3}}, marker = {};
#    var cb1 = generate(marker);
#    var mark2 = {};
#    var cb2 = generate(mark2);
#    for (var key in obj) tap(obj, key, cb1);
#    tap(obj, 'friend', cb2);
#    obj.name = 'React';
#    obj.age += 1;
#    shall(marker).eql({ name: 1, age: 1 });
#    obj.age += 1;
#    shall(marker).eql({ name: 1, age: 2 });
#    delete obj.name;
#    shall(marker).eql({ name: 1, age: 2 });
#    shall(obj.name).equal(undefined);
#
#    obj.equip.newProperty('head', 0);
#    shall(marker).eql({ name: 1, age: 2, equip: 1 });
#    obj.equip.newProperty('arm', 1);
#    shall(marker).eql({ name: 1, age: 2, equip: 2 });
#    obj.equip.head = 5;
#    shall(marker).eql({ name: 1, age: 2, equip: 3 });
#    obj.equip.body = 6;
#    shall(marker).eql({ name: 1, age: 2, equip: 4 });
#
#    obj.friend.push('T0');
#    shall(marker).eql({ name: 1, age: 2, equip: 4, friend: 1 });
#    obj.friend.push('T1');
#    shall(marker).eql({ name: 1, age: 2, equip: 4, friend: 2 });
#    obj.friend[1] = 'T2';
#    shall(marker).eql({ name: 1, age: 2, equip: 4, friend: 3 });
#  });
#
#  describe('Helper', function () {
#    it('warpRivalLst',function(done){
#      var data = [{
#        value:[ [ 'P36', '36' ], [ 'P78', '78' ], [ 'P94', '94' ] ],
#        check:{ name:['P36','P78','P94'], rnk:[36,78,94]}},
#      ]
#      
#      async.map(data, 
#        function(e,cb){
#          shall(helpLib.warpRivalLst(e.value)).eql(e.check);
#          cb();
#        },done);
#    });
#  });
#
#
#  describe('Leaderboard', function () {
#    var dbLib = require('../js/db');
#
#    gServerName = 'UnitTest';
#    gServerID = 1;
#    dbPrefix = gServerName;
#    dbLib.initializeDB({
#      "Account": { "IP": "localhost", "PORT": 6379},
#      "Role": { "IP": "localhost", "PORT": 6379},
#      "Publisher": { "IP": "localhost", "PORT": 6379},
#      "Subscriber": { "IP": "localhost", "PORT": 6379}
#    });
#
#    var config = [
#      {
#        name: 'battleForce',
#        key: 'battleForce',
#        reverse: false,
#        initialValue: 5,
#        type: 'player',
#        resetTime: { weekday: 4, hour: 8 },
#        availableConfition: true
#      },
#      {
#        name: 'goldenSlime',
#        key: 'scores.goldenSlime',
#        reverse: true,
#        initialValue: 5,
#        type: 'player',
#        availableConfition: true
#      }
#    ];
#    config = require('../../data/stable/leadboard').data
#    config[4].resetTime={ weekday:5,hour:19};
#    var players = [
#      //{ name: 'Ken',  type: 'player', monster:1, scores: {} ,saveDB:function(){}},
#      //{ name: 'Ken1', type: 'player', monster:2, scores: {} ,saveDB:function(){}},
#      //{ name: 'Ken2', type: 'player', monster:3, scores: {} ,saveDB:function(){}},
#      //{ name: 'Ken3', type: 'player', monster:4, scores: {} ,saveDB:function(){}},
#      //{ name: 'Ken4', type: 'player', monster:5, scores: {} ,saveDB:function(){}},
#      //{ name: 'Ken5', type: 'player', monster:6, scores: {} ,saveDB:function(){}},
#      //{ name: 'Ken6', type: 'player', monster:7, scores: {} ,saveDB:function(){}},
#      //{ name: 'Ken7', type: 'player', monster:8, scores: {} ,saveDB:function(){}},
#      //{ name: 'Ken8', type: 'player', monster:9, scores: {} ,saveDB:function(){}},
#      //{ name: 'Ken9', type: 'player', monster:10, scores: {} ,saveDB:function(){}},
#      { name: 'Ken10', type: 'player', counters:{worldBoss:{'133':2}},monster:13, scores: {} ,saveDB:function(){}},
#      { name: 'Ken11', type: 'player', counters:{worldBoss:{'133':3}},monster:15, scores: {} ,saveDB:function(){}},
#      { name: 'Ken12', type: 'player', counters:{worldBoss:{'133':4}},monster:16, scores: {} ,saveDB:function(){}},
#      { name: 'Ken12', type: 'player', counters:{worldBoss:{'133':5}},monster:13, scores: {} ,saveDB:function(){}},
#    ];
#    helpLib.initLeaderboard(config);
#    players.forEach(function(p) {
#      helpLib.assignLeaderboard(p,4);
#    })
#    it('monitor root values', function (done) {
#//      players.forEach(function (p, i) {
#//        p.battleForce -= i;
#//        shall(p.scores.goldenSlime).equal(5);
#//      });
#
#      helpLib.getPositionOnLeaderboard(4, 'Ken10', 0, 10, 
#        function(err,ret) {
#          console.log(ret);
#          done();
#        });
#      /* TODO:
#      async.map(
#        players,
#        function (e, cb) { helpLib.getPositionOnLeaderboard(0, e.name, cb); },
#        function (err, result) {
#          for (var i in result) {
#            if (result[i] != players[i].battleForce) {
#              done(Error('No'));
#            }
#          }
#
#          done();
#        });
#        */
#    });
#    it('kill monster prize', function (done) {
#      
#      console.log('TestKillMonster',helpLib.intervalEvent.killMonsterPrize)
#      helpLib.intervalEvent.killMonsterPrize.func({
#          helper:helpLib, 
#          db:{
#            deliverMessage:function(name,mail) {
#              console.log('res',name,mail.txt) 
#            }}})
#      done();
#    });
#    it('kill worldBoss prize', function (done) {
#
#      gServerObject = {
#        getType: function () { return 'server'; },
#        counters:{'133':200},
#      };
#
#      helpLib.initObserveration(gServerObject);
#      gServerObject.installObserver('countersChanged');
#
#      //helpLib.intervalEvent.worldBoss.time ={weekday:5};
#      console.log('TestKillMonster',helpLib.intervalEvent.worldBoss)
#      helpLib.intervalEvent.worldBoss.func({
#          helper:helpLib, 
#          db:{
#            deliverMessage:function(name, message, callback, serverName) {
#              console.log('res',name,message,callback,serverName) 
#            },
#          },
#          sObj: gServerObject
#      })
#      reqh.route.RPC_WorldStageInfo.func(
#          null,
#          {name:'ken1', counters:{worldBoss:{'133':2}}},
#          function(ret) {console.log(ret)},
#          null);
#      done();
#    });
#
#  });
#
#  describe('Time Method', function () {
#    it('dateInRange', function() {
#      var date = [
#        {result:true, time:'2014/4/1',range:[{from:1,to:2}, {from:4,to:20}]},
#        {result:false, time:'2014/4/3',range:[{from:1,to:2}, {from:4,to:20}]},
#        {result:true, time:'2014/4/4',range:[{from:1,to:2}, {from:4,to:20}]},
#        {result:true, time:'2014/4/19',range:[{from:1,to:2}, {from:4,to:20}]},
#      ]
#
#      date.forEach(function(e) {
#        helpLib.dateInRange(e.time,e.range).should.eql(e.result);
#      });
#    });
#    it('Diff', function () {
#      var diff = helpLib.diffDate;
#      var x = diff('2014/3/16', '2014/3/12', 'second');
#    });
#    it('Match', function () {
#      var match = helpLib.matchDate;
#      shall(match('2014/4/16', '2014/4/17', {weekday: 10})).equal(false);
#      shall(match('2014/4/16', '2014/4/17', {weekday: 4})).equal(true);
#      shall(match('2014/4/16', '2014/4/17', {monthday: 17})).equal(true);
#      shall(match('2014/4/16', '2014/4/18', {monthday: 19})).equal(false);
#      shall(match('2014/4/16', '2014/4/18', {weekday: 7, hour: 12})).equal(false);
#      shall(match('2014/4/16', '2014/4/20', {weekday: 7, hour: 12})).equal(false);
#      shall(match('2014/4/16', '2014/4/20 13:00:00', {weekday: 7, hour: 12})).equal(true);
#      shall(match('2014/4/16', '2014/4/16 13:00:00', { hour: 18})).equal(false);
#      shall(match('2014/4/16', '2014/4/16 13:00:00', { hour: 12})).equal(true);
#    });
#    it('Diff Date', function () {
#      var diffDate = helpLib.diffDate;
#      diffDate(1393171200000, '2014/02/24').should.equal(0);
#      diffDate(1393171200000, '2014/02/25').should.equal(1);
#      diffDate('2014/02/24', '2014/02/25').should.equal(1);
#      diffDate('2014/02/23', '2014/02/25').should.equal(2);
#      diffDate('2014/01/01', '2014/02/25').should.equal(55);
#    });
#  });
#});
#
#describe('Unlock', function () {
#  var updateLockStatus = helpLib.updateLockStatus;
#  var me = {
#    stage: []
#  };
#  var config = [
#    { nolimitation: true },
#    { cond: { '==': [1, 1] } },
#    { cond: {
#              '==': [
#                { type: "getProperty", key: "stage.1" }, true
#              ]
#            }
#    }
#  ];
#
#  it('Basic', function () {
#    shall(updateLockStatus(me.stage, me, config)).eql([0, 1]);
#  });
#});
#/*
#describe('calculateTotalItemXP', function () {
#  var calculate = helpLib.calculateTotalItemXP;
#  shall(calculate({xp: 0, quality: 0, rank: 0})).equal(0);
#  shall(calculate({xp: 100, quality: 0, rank: 0})).equal(100);
#  shall(calculate({xp: 100, quality: 1, rank: 1})).equal(100);
#  shall(calculate({xp: 100, quality: 1, rank: 2})).equal(200);
#  shall(calculate({xp: 100, quality: 2, rank: 2})).equal(100);
#});
#*/
#
#
#describe('Prize', function () {
#  it('Basic', function () {
#    var prize = [
#      { rate: 0, prize: [] },
#      { rate: 1, prize: [] }
#    ];
#  });
#});
#
#describe('Campaign', function () {
#  var events = {
#    "event_daily": {
#      "flag": "daily",
#      "resetTime": { hour: 8 },
#      "storeType": "player",
#      "daily": true,
#      "reward": [
#        { "prize":{ "type":0, "value":33, "count":1 }, "weight":1 },
#        { "prize":{ "type":0, "value":34, "count":1 }, "weight":1 },
#        { "prize":{ "type":0, "value":35, "count":1 }, "weight":1 },
#        { "prize":{ "type":0, "value":36, "count":1 }, "weight":1 },
#        { "prize":{ "type":0, "value":37, "count":1 }, "weight":1 }
#      ],
#      "steps": 4,
#      "quest": [
#        128, 129, 130, 131, 132, 133, 134, 135,
#        136, 137, 138, 139, 140, 141, 142, 143,
#        144, 145, 146, 147, 148, 149, 150, 151
#      ]
#
#    },
#    event_robbers: {
#      storeType: "player",
#      actived: 1,
#      count: 5,
#      canProceed: function (obj, util) {
#        return (
#            obj.counters.robbers < 2 &&
#            obj.battleForce >= 75 &&
#            util.today.hour() >= 6 &&
#            util.today.hour() <= 10
#          );
#      },
#      canReset: function (obj, util) {
#        return (util.diffDay(obj.timestamp.robbers, util.today) &&
#          util.today.hour() >= 8);
#      },
#      reset: function (obj, util) {
#        obj.timestamp.robbers = util.currentTime();
#        obj.counters.robbers = 0;
#      }
#    },
#    event_weapon: {
#      storeType: "player",
#      actived: 1,
#      count: 5,
#      canProceed: function (obj, util) {
#        return ( obj.counters.weapon < 2 ) &&
#            ( util.today.weekday() === 2 ||
#              util.today.weekday() === 4 ||
#              util.today.weekday() === 5 ||
#              util.today.weekday() === 0 );
#      },
#      canReset: function (obj, util) {
#        return util.diffDay(obj.timestamp.weapon, util.today);
#      },
#      reset: function (obj, util) {
#        obj.timestamp.weapon = util.currentTime();
#        obj.counters.weapon = 0;
#      },
#      stageID: 1024
#    },
#    event_enhance: {
#      storeType: "player",
#      actived: 1,
#      count: 5,
#      canProceed: function (obj, util) {
#        return ( obj.counters.enhance < 2 ) &&
#            ( util.today.weekday() === 1 ||
#              util.today.weekday() === 3 ||
#              util.today.weekday() === 6 ||
#              util.today.weekday() === 0 );
#      },
#      canReset: function (obj, util) {
#        return util.diffDay(obj.timestamp.enhance, util.today);
#      },
#      reset: function (obj, util) {
#        obj.timestamp.enhance = util.currentTime();
#        obj.counters.enhance = 0;
#      },
#      stageID: 1024
#    },
#    //event_unlock_class: {
#    //  storeType: "server",
#    //  canProceed: function (obj, util) {
#    //    return obj.flags.energy && ( obj.counters.energy < 2 )
#    //      && util.timeMatch(obj.event_energy.date, null, { hour: 8} );
#    //  },
#    //}
#  };
#  var helperLib = require('../js/helper');
#
#  before(function (done) {
#    initGlobalConfig('../../build/', done);
#  });
#
#  describe('ChainEvent', function () {
#    it('Should be ok~', function () {
#      // TODO:
#      var me = new playerLib.Player({name: 'T'});
#      me.createHero({name: 'T', class: 1, gender: 1, hairStyle: 1, hairColor: 1});
#      me.startDungeon = function () {
#        var quest = this.event_daily.quest;
#        quest = quest[this.event_daily.step];
#        this.quests[quest].counters[0] = 20;
#      };
#      helpLib.initCampaign(me, events);
#
#      // event_robbers
#      shall(me.counters).have.property('robbers').equal(0);
#      shall(me.timestamp).have.property('robbers');
#      shall(me.counters).have.property('weapon').equal(0);
#      shall(me.timestamp).have.property('weapon');
#      shall(me.counters).have.property('enhance').equal(0);
#      shall(me.timestamp).have.property('enhance');
#
#      helpLib.initCampaign(me, events);
#      // initial event
#      //shall(me).not.have.property('event_daily');
#      me.flags.daily = true;
#      helpLib.initCampaign(me, events);
#      shall(me).have.property('event_daily');
#      shall(me.event_daily).have.property('status').equal('Ready');
#      shall(me.event_daily).have.property('reward');
#      shall(me.event_daily).have.property('rank');
#      shall(me.event_daily.stepPrize).have.property('length').equal(4);
#      shall(me.event_daily.quest).have.property('length').equal(4);
#      shall(me.event_daily).have.property('step').equal(0);
#      // start event
#      helpLib.proceedCampaign(me, 'event_daily', events);
#      shall(me.quests[me.event_daily.quest[0]]).have.property('counters');
#      helpLib.initCampaign(me, events);
#      shall(me.event_daily.status).equal('Complete');
#      helpLib.proceedCampaign(me, 'event_daily', events);
#      shall(me.event_daily.step).equal(1);
#      helpLib.proceedCampaign(me, 'event_daily', events);
#      helpLib.proceedCampaign(me, 'event_daily', events);
#      // deal with undeleted quests
#      var quest = me.event_daily.quest;
#      quest = quest[me.event_daily.step+1];
#      me.quests[quest] = {counters: 2};
#      helpLib.proceedCampaign(me, 'event_daily', events);
#      shall(me.event_daily.step).equal(2);
#      helpLib.proceedCampaign(me, 'event_daily', events);
#      helpLib.proceedCampaign(me, 'event_daily', events);
#      shall(me.event_daily.step).equal(3);
#      helpLib.proceedCampaign(me, 'event_daily', events);
#      helpLib.initCampaign(me, events);
#      shall(me.event_daily.status).equal('Complete');
#      shall(me.event_daily.step).equal(4);
#      shall(me.event_daily.status).equal('Complete');
#      helpLib.proceedCampaign(me, 'event_daily', events);
#      shall(me.event_daily.step).equal(5);
#      shall(me.event_daily.status).equal('Done');
#      helpLib.proceedCampaign(me, 'event_daily', events);
#      shall(me.event_daily.status).equal('Done');
#      me.event_daily.date = '2014-03-05T16:00:00';
#      helpLib.initCampaign(me, events);
#      shall(me.event_daily).have.property('step').equal(0);
#      shall(me.event_daily.status).equal('Ready');
#    });
#  });
#});
