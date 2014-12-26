var Counter = require('../js/counter').Counter;
require('should');
//var dbLib = require('../db');
//var should = require('should');
//require('../define');
//require('../shared');
//initServer();
//gServerID = 1;
//var helpLib = require('../helper');
//
//events = helpLib.events;

describe('Campaign', function () {
    describe('Counter', function () {
        var testConfig = {
          rmb: {
            initial_value: 0
          },
          pvp_win: {
            initial_value: 0,
            uplimit: 4,
            combo: { duration: { minute: 10 }, time: 'time@ThisCounter' }
          },
          check_in: {
            initial_value: 0,
            count_down: { time: 'time@ThisCounter', units: 'day' },
            duration: { time: 'time@ThisCounter', units: 'month' }
          },
          milionaire_goblin: {
            initial_value: 0,
            uplimit: 3,
            duration: { time: 'time@ThisCounter', units: 'day' }
          },
        };

        it('incr && decr', function () {
            var counter = new Counter(testConfig.rmb);
            counter.incr(1).counter.should.equal(1);
            counter.incr(1).counter.should.equal(2);
            counter.decr(1).counter.should.equal(1);
            counter.update().counter.should.equal(1);
        });

        it('combo', function () {
            var counter = new Counter(testConfig.pvp_win);
            counter.incr(1, "2012-12-12").counter.should.equal(1);
            counter.incr(1, "2012-12-12").counter.should.equal(2);
            counter.incr(1, "2012-12-12T00:11:00").counter.should.equal(1);
            counter.incr(1, "2012-12-12T00:20:00").counter.should.equal(2);
            counter.update("2012-12-13").counter.should.equal(0);
            counter.incr(1, "2012-12-13").counter.should.equal(1);
            counter.incr(1, "2012-12-13").counter.should.equal(2);
            counter.incr(1, "2012-12-13").counter.should.equal(3);
            counter.incr(1, "2012-12-13").counter.should.equal(4);
            counter.incr(1, "2012-12-13").counter.should.equal(4);
        });

        it('count down', function () {
            var counter = new Counter(testConfig.check_in);
            counter.incr(1, "2012-12-12").counter.should.equal(1);
            counter.incr(1, "2012-12-12").counter.should.equal(1);
            counter.incr(1, "2012-12-13").counter.should.equal(2);
            counter.incr(0, "2013-01-13").counter.should.equal(0);
            counter.incr(1, "2013-01-19").counter.should.equal(1);
        });

        it('up limit', function () {
            var counter = new Counter(testConfig.milionaire_goblin);
            counter.incr(1, "2012-12-12").counter.should.equal(1);
            counter.incr(1, "2012-12-12").counter.should.equal(2);
            counter.incr(1, "2012-12-12").counter.should.equal(3);
            counter.incr(1, "2012-12-12").counter.should.equal(3);
            counter.incr(0, "2012-12-13").counter.should.equal(0);
            counter.incr(0, "2013-01-13").counter.should.equal(0);
            counter.incr(1, "2013-01-13").counter.should.equal(1);
        });
    });
//  before(function (done) {
//    initGlobalConfig(done);
//  });
//  describe('ChainEvent', function () {
//    it('Should be ok~', function () {
//      var me = { 
//        battleForce: 75,
//        quests: [],
//        attrSave: function (key, value) { this[key] = value; },
//        getType: function () { return 'player'; },
//        acceptQuest: function (qid) { this.quests[ qid ] = { counters:[0] }; },
//        isQuestAchieved: function (qid) {
//          if (this.quests[qid] == null) return false;
//          return this.quests[qid].counters[0] >= 2;
//        },
//        startDungeon: function () {
//          var quest = this.event_daily.quest;
//          quest = quest[this.event_daily.step];
//          this.quests[quest].counters[0]++;
//        },
//        claimPrize: function (prize) { return []; }
//      };
//      helpLib.initCampaign(me, events);
//      helpLib.initCampaign(me, events);
//      // initial event
//      //should(me).not.have.property('event_daily');
//      me.flags.daily = true;
//      helpLib.initCampaign(me, events);
//      should(me).have.property('event_daily');
//      should(me.event_daily).have.property('status').equal('Ready');
//      should(me.event_daily).have.property('reward');
//      should(me.event_daily).have.property('rank');
//      should(me.event_daily.stepPrize).have.property('length').equal(4);
//      should(me.event_daily.quest).have.property('length').equal(4);
//      should(me.event_daily).have.property('step').equal(0);
//      // start event
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      should(me.quests[me.event_daily.quest[0]]).have.property('counters');
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      helpLib.initCampaign(me, events);
//      should(me.event_daily.status).equal('Complete');
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      should(me.event_daily.step).equal(1);
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      // deal with undeleted quests
//      var quest = me.event_daily.quest;
//      quest = quest[me.event_daily.step+1];
//      me.quests[quest] = {counters: 2};
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      should(me.event_daily.step).equal(2);
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      should(me.event_daily.step).equal(3);
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      helpLib.initCampaign(me, events);
//      should(me.event_daily.status).equal('Complete');
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      should(me.event_daily.step).equal(4);
//      should(me.event_daily.status).equal('Complete');
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      should(me.event_daily.step).equal(5);
//      should(me.event_daily.status).equal('Done');
//      helpLib.proceedCampaign(me, 'event_daily', events);
//      should(me.event_daily.status).equal('Done');
//      me.event_daily.date = '2014-03-05T16:00:00';
//      helpLib.initCampaign(me, events);
//      should(me.event_daily).have.property('step').equal(0);
//      should(me.event_daily.status).equal('Ready');
//    });
//  });
});
