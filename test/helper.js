var shall = require('should');
var helpLib = require('../js/helper');
events = helpLib.events;

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

describe('Campaign', function () {
//describe('#Helper Lib', function () {
//  var helperLib = require('../helper');
//  it('C', function () {
//    helperLib.calculateTotalItemXP({xp: 0, quality: 0, rank: 0}).should.equal(0);
//    helperLib.calculateTotalItemXP({xp: 100, quality: 0, rank: 0}).should.equal(100);
//    helperLib.calculateTotalItemXP({xp: 100, quality: 1, rank: 1}).should.equal(100);
//    helperLib.calculateTotalItemXP({xp: 100, quality: 1, rank: 2}).should.equal(200);
//    helperLib.calculateTotalItemXP({xp: 100, quality: 2, rank: 2}).should.equal(100);
//  });
//});
//describe('#moment', function () {
//  moment = require('moment');
//  helper = require('../helper');
//  it('helper of time', function () {
//    helper.diffDate(1393171200000, '2014/02/24').should.equal(0);
//    helper.diffDate(1393171200000, '2014/02/25').should.equal(1);
//    helper.diffDate('2014/02/24', '2014/02/25').should.equal(1);
//    helper.diffDate('2014/02/23', '2014/02/25').should.equal(2);
//    helper.diffDate('2014/01/01', '2014/02/25').should.equal(55);
//  });
//});

//  before(function (done) {
//    initGlobalConfig(done);
//  });
  describe('ChainEvent', function () {
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
  });
});

