var shall = require('should');
var helpLib = require('../js/helper');
var dbWrapper = require('../js/dbWrapper');
var playerLib = require('../js/player');
var async = require('async');
events = helpLib.events;

describe('Helper', function () {
  describe('React programming', function () {
    var tap = helpLib.tap;
    function generate(marker) {
      return function (key, val) {
        if ( marker[key] ) {
          marker[key] += 1;
        } else {
          marker[key] = 1;
        }
      };
    }
    var obj = {name: 'Obj', age: 3, friend: ['Tx'], equip: {body: 3}}, marker = {};
    var cb1 = generate(marker);
    var mark2 = {};
    var cb2 = generate(mark2);
    for (var key in obj) tap(obj, key, cb1);
    tap(obj, 'friend', cb2);
    obj.name = 'React';
    obj.age += 1;
    shall(marker).eql({ name: 1, age: 1 });
    obj.age += 1;
    shall(marker).eql({ name: 1, age: 2 });
    delete obj.name;
    shall(marker).eql({ name: 1, age: 2 });
    shall(obj.name).equal(undefined);

    obj.equip.newProperty('head', 0);
    shall(marker).eql({ name: 1, age: 2, equip: 1 });
    obj.equip.newProperty('arm', 1);
    shall(marker).eql({ name: 1, age: 2, equip: 2 });
    obj.equip.head = 5;
    shall(marker).eql({ name: 1, age: 2, equip: 3 });
    obj.equip.body = 6;
    shall(marker).eql({ name: 1, age: 2, equip: 4 });

    obj.friend.push('T0');
    shall(marker).eql({ name: 1, age: 2, equip: 4, friend: 1 });
    obj.friend.push('T1');
    shall(marker).eql({ name: 1, age: 2, equip: 4, friend: 2 });
    obj.friend[1] = 'T2';
    shall(marker).eql({ name: 1, age: 2, equip: 4, friend: 3 });
  });

  describe('Leaderboard', function () {
    var dbLib = require('../js/db');

    gServerName = 'UnitTest';
    gServerID = 1;
    dbPrefix = gServerName;
    dbLib.initializeDB({
      "Account": { "IP": "localhost", "PORT": 6379},
      "Role": { "IP": "localhost", "PORT": 6379},
      "Publisher": { "IP": "localhost", "PORT": 6379},
      "Subscriber": { "IP": "localhost", "PORT": 6379}
    });

    var config = [
      {
        name: 'battleForce',
        key: 'battleForce',
        reverse: false,
        initialValue: 5,
        type: 'player',
        resetTime: { weekday: 4, hour: 8 },
        availableConfition: true
      },
      {
        name: 'goldenSlime',
        key: 'scores.goldenSlime',
        reverse: true,
        initialValue: 5,
        type: 'player',
        availableConfition: true
      }
    ];
    var players = [
      { name: 'Ken',  type: 'player', scores: {} },
      { name: 'Ken1', type: 'player', scores: {} },
      { name: 'Ken2', type: 'player', scores: {} },
      { name: 'Ken3', type: 'player', scores: {} },
      { name: 'Ken4', type: 'player', scores: {} },
      { name: 'Ken5', type: 'player', scores: {} }
    ];
    helpLib.initLeaderboard(config);
    players.forEach(helpLib.assignLeaderboard);
    it('monitor root values', function (done) {
      players.forEach(function (p, i) {
        p.battleForce -= i;
        shall(p.scores.goldenSlime).equal(5);
      });

      helpLib.getPositionOnLeaderboard(0, 'Ken', 0, 10, console.log);
      done();
      /* TODO:
      async.map(
        players,
        function (e, cb) { helpLib.getPositionOnLeaderboard(0, e.name, cb); },
        function (err, result) {
          for (var i in result) {
            if (result[i] != players[i].battleForce) {
              done(Error('No'));
            }
          }

          done();
        });
        */
    });
  });

  describe('Time Method', function () {
    it('Diff', function () {
      var diff = helpLib.diffDate;
      var x = diff('2014/3/16', '2014/3/12', 'second');
    });
    it('Match', function () {
      var match = helpLib.matchDate;
      shall(match('2014/4/16', '2014/4/17', {weekday: 10})).equal(false);
      shall(match('2014/4/16', '2014/4/17', {weekday: 4})).equal(true);
      shall(match('2014/4/16', '2014/4/17', {monthday: 17})).equal(true);
      shall(match('2014/4/16', '2014/4/18', {monthday: 19})).equal(false);
      shall(match('2014/4/16', '2014/4/18', {weekday: 7, hour: 12})).equal(false);
      shall(match('2014/4/16', '2014/4/20', {weekday: 7, hour: 12})).equal(false);
      shall(match('2014/4/16', '2014/4/20 13:00:00', {weekday: 7, hour: 12})).equal(true);
    });
  });
});
/*
describe('Unlock', function () {
  var updateLockStatus = helpLib.updateLockStatus;
  var me = {
    stage: []
  };
  var config = [
    { nolimitation: true },
    { cond: { '==': [1, 1] } },
    { cond: {
              '==': [
                { type: "getProperty", key: "stage.1" }, true
              ]
            }
    }
  ];

  it('Basic', function () {
    shall(updateLockStatus(me.stage, me, config)).eql([0, 1]);
  });
});
describe('calculateTotalItemXP', function () {
  var calculate = helpLib.calculateTotalItemXP;
  shall(calculate({xp: 0, quality: 0, rank: 0})).equal(0);
  shall(calculate({xp: 100, quality: 0, rank: 0})).equal(100);
  shall(calculate({xp: 100, quality: 1, rank: 1})).equal(100);
  shall(calculate({xp: 100, quality: 1, rank: 2})).equal(200);
  shall(calculate({xp: 100, quality: 2, rank: 2})).equal(100);
});
*/

describe('Campaign', function () {
  var helperLib = require('../js/helper');
  describe('#Helper Lib', function () {
    it('C', function () {
      helperLib.calculateTotalItemXP({xp: 0, quality: 0, rank: 0}).should.equal(0);
      helperLib.calculateTotalItemXP({xp: 100, quality: 0, rank: 0}).should.equal(100);
      helperLib.calculateTotalItemXP({xp: 100, quality: 1, rank: 1}).should.equal(100);
      helperLib.calculateTotalItemXP({xp: 100, quality: 1, rank: 2}).should.equal(200);
      helperLib.calculateTotalItemXP({xp: 100, quality: 2, rank: 2}).should.equal(100);
    });
  });
  describe('#moment', function () {
    moment = require('moment');
    it('helper of time', function () {
      helperLib.diffDate(1393171200000, '2014/02/24').should.equal(0);
      helperLib.diffDate(1393171200000, '2014/02/25').should.equal(1);
      helperLib.diffDate('2014/02/24', '2014/02/25').should.equal(1);
      helperLib.diffDate('2014/02/23', '2014/02/25').should.equal(2);
      helperLib.diffDate('2014/01/01', '2014/02/25').should.equal(55);
    });
  });

  before(function (done) {
    initGlobalConfig('../build/', done);
  });
  describe('ChainEvent', function () {
    it('Should be ok~', function () {
      var me = new playerLib.Player({name: 'T'});
      me.createHero({name: 'T', class: 1, gender: 1, hairStyle: 1, hairColor: 1});
      //var me = { 
      //  battleForce: 75,
      //  flags: {},
      //  quests: [],
      //  attrSave: function (key, value) { this[key] = value; },
      //  getType: function () { return 'player'; },
      //  acceptQuest: function (qid) { this.quests[ qid ] = { counters:[0] }; },
      //  isQuestAchieved: function (qid) {
      //  if (this.quests[qid] == null) return false;
      //  return this.quests[qid].counters[0] >= 2;
      //},
      //startDungeon: function () {
      //  var quest = this.event_daily.quest;
      //  quest = quest[this.event_daily.step];
      //  this.quests[quest].counters[0]++;
      //},
      //claimPrize: function (prize) { return []; }
      //};
      me.startDungeon = function () {
        var quest = this.event_daily.quest;
        quest = quest[this.event_daily.step];
        this.quests[quest].counters[0] = 20;
      };
      helpLib.initCampaign(me, events);
      helpLib.initCampaign(me, events);
      // initial event
      //shall(me).not.have.property('event_daily');
      me.flags.daily = true;
      me.dumpChanged();
      helpLib.initCampaign(me, events);
      shall(me).have.property('event_daily');
      shall(me.event_daily).have.property('status').equal('Ready');
      shall(me.event_daily).have.property('reward');
      shall(me.event_daily).have.property('rank');
      shall(me.event_daily.stepPrize).have.property('length').equal(4);
      shall(me.event_daily.quest).have.property('length').equal(4);
      shall(me.event_daily).have.property('step').equal(0);
      // start event
      helpLib.proceedCampaign(me, 'event_daily', events);
      shall(me.quests[me.event_daily.quest[0]]).have.property('counters');
      helpLib.initCampaign(me, events);
      shall(me.event_daily.status).equal('Complete');
      helpLib.proceedCampaign(me, 'event_daily', events);
      shall(me.event_daily.step).equal(1);
      helpLib.proceedCampaign(me, 'event_daily', events);
      helpLib.proceedCampaign(me, 'event_daily', events);
      // deal with undeleted quests
      var quest = me.event_daily.quest;
      quest = quest[me.event_daily.step+1];
      me.quests[quest] = {counters: 2};
      helpLib.proceedCampaign(me, 'event_daily', events);
      shall(me.event_daily.step).equal(2);
      helpLib.proceedCampaign(me, 'event_daily', events);
      helpLib.proceedCampaign(me, 'event_daily', events);
      shall(me.event_daily.step).equal(3);
      helpLib.proceedCampaign(me, 'event_daily', events);
      helpLib.initCampaign(me, events);
      shall(me.event_daily.status).equal('Complete');
      shall(me.event_daily.step).equal(4);
      shall(me.event_daily.status).equal('Complete');
      helpLib.proceedCampaign(me, 'event_daily', events);
      shall(me.event_daily.step).equal(5);
      shall(me.event_daily.status).equal('Done');
      helpLib.proceedCampaign(me, 'event_daily', events);
      shall(me.event_daily.status).equal('Done');
      me.event_daily.date = '2014-03-05T16:00:00';
      helpLib.initCampaign(me, events);
      shall(me.event_daily).have.property('step').equal(0);
      shall(me.event_daily.status).equal('Ready');
    });
  });
});
