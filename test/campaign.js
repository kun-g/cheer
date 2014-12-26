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
        counter.isFulfiled("2012-12-12").should.equal(true);
        counter.incr(0, "2012-12-13").counter.should.equal(0);
        counter.incr(0, "2013-01-13").counter.should.equal(0);
        counter.incr(1, "2013-01-13").counter.should.equal(1);
    });
});

describe('Campaign', function () {
    counters = {
        goblin: {
            key: 'goblin',
            initial_value: 0,
            uplimit: 3,
            duration: { time: 'time@ThisCounter', units: 'day' }
        },
        enhance: {
            key: 'enhance',
            initial_value: 0,
            uplimit: 3,
            duration: { time: 'time@ThisCounter', units: 'day' }
        }
    };

    events = {
        goblin: {
            storeType: "player",
            id: 0,
            counter: counters.goblin,
            available_condition: [
                { type: 'counter', func: "notFulfiled" },
                {
                    type: 'time',
                    timeExpr: {
                        duration: { hour: 2 },
                        time: { time: "time@Arguments", startOf: 'day', offset: { hour: 12 } }
                    }
                }
            ]
        },

        enhance: {
            storeType: "player",
            id: 1,
            counter: counters.enhance,
            available_condition: [
            { type: 'counter', func: "notFulfiled" },
            {
                type: 'time',
                timeExpr: {
                    or: [
                    { time: {time: "time@Arguments", offset: { day: 0 }, startOf: 'week'}, units: 'day' },
                    { time: {time: "time@Arguments", offset: { day: 2 }, startOf: 'week'}, units: 'day' },
                    { time: {time: "time@Arguments", offset: { day: 4 }, startOf: 'week'}, units: 'day' },
                    { time: {time: "time@Arguments", offset: { day: 6 }, startOf: 'week'}, units: 'day' }
                    ]
                }
            }
            ]
        },

        infinite: {
            storeType: "player",
            id: 3,
            available_condition: [
            {
                type: 'function',
                func: function (theData, utils) {
                    return Math.floor(utils.libTime.diff(theData.time, '2014-06-14').as('week')) % 2 == 0;
                }
            }
            ],
                reset_condition: {
                    or: [
                    {
                        type: 'function',
                        func: function (theData, utils) {
                            return !theData.object.timestamp.infinite;
                        }
                    },
                    {
                        type: 'time',
                        timeExpr: {
                            not: [
                            { time: 'infinite@Timestamp', units: 'week' }
                            ]
                        }
                    }
                    ]
                },
                reset_action: [
                {
                    type: 'function',
                    func: function (theData, util) {
                        var obj = theData.object;
                        obj.timestamp['infinite'] = theData.time;
                        obj.stage[120]['level'] = 0
                            //TODO:uncomment this
                            //obj.notify('stageChanged',{stage:120})
                    }
                }
            ]
        },

        //  monthCard: {
        //    storeType: "player",
        //    id: -1,
        //    actived: (obj, util) ->
        //      return 0 unless obj.counters.monthCard
        //      return 1 unless obj.timestamp.monthCard
        //      return 0 if moment().isSame(obj.timestamp.monthCard, 'day')
        //      return 1
        //  },

        //  hunting: {
        //    storeType: "player",
        //    id: 4,
        //    actived: (obj, util) ->
        //      if checkBountyValidate(4,util.today)
        //#if exports.dateInRange(util.today,[{from:7,to:13},{from:21,to:27}])
        //        return 1
        //      else
        //        return 0
        //          ,
        //          stages: [121, 122, 123, 125, 126, 127, 128, 129, 130, 131, 132],
        //          canReset: (obj, util) ->
        //            return (diffDate(obj.timestamp.hunting, util.today) >= 7 )
        //            ,
        //          reset: (obj, util) ->
        //            obj.timestamp.hunting = util.currentTime()
        //            stages = [121, 122, 123, 125, 126, 127, 128, 129, 130, 131, 132]
        //            for s in stages when obj.stage[s]
        //              obj.stage[s].level = 0
        //                obj.modifyCounters('monster',{ value : 0,notify:{name:'countersChanged',arg:{type : 'monster'}}})
        //  },
        //  pkCounter: {
        //    storeType: "player",
        //#id: -1,
        //    actived: 1,
        //    canReset: (obj, util) ->
        //      return (util.diffDay(obj.timestamp.currentPKCount, util.today))
        //      ,
        //    reset: (obj, util) ->
        //      obj.timestamp.currentPKCount = util.currentTime()
        //      obj.counters.currentPKCount = 0
        //      obj.flags.rcvAward = false
        //  },
        //
        //  event_daily: {
        //    "flag": "daily",
        //    "resetTime": { hour: 8 },
        //    "storeType": "player",
        //    "daily": true,
        //    "reward": [
        //    { "prize":{ "type":0, "value":33, "count":1 }, "weight":1 },
        //    { "prize":{ "type":0, "value":34, "count":1 }, "weight":1 },
        //    { "prize":{ "type":0, "value":35, "count":1 }, "weight":1 },
        //    { "prize":{ "type":0, "value":36, "count":1 }, "weight":1 },
        //    { "prize":{ "type":0, "value":37, "count":1 }, "weight":1 }
        //    ],
        //      "steps": 4,
        //      "quest": [
        //        128, 129, 130, 131, 132, 133, 134, 135,
        //      136, 137, 138, 139, 140, 141, 142, 143,
        //      144, 145, 146, 147, 148, 149, 150, 151
        //        ]
        //  },
        //
        //  weapon: {
        //    storeType: "player",
        //    id: 2,
        //    actived: 1,
        //    count: (obj, util) ->
        //      return obj.getPrivilege('EquipmentRobbers')
        //      ,
        //    canReset: (obj, util) ->
        //      return (util.diffDay(obj.timestamp.weapon, util.today)) and (
        //          util.today.weekday() is 1 or
        //          util.today.weekday() is 3 or
        //          util.today.weekday() is 5 or
        //          util.today.weekday() is 0
        //          )
        //      ,
        //    reset: (obj, util) ->
        //      obj.timestamp['weapon'] = util.currentTime()
        //      obj.counters['weapon'] = 0
        //  },
    }
    var Campaign = require("../js/campaign").Campaign;
    it('', function () {
        var player ={ type: 'player', counters:{} };
        var guild = { type: 'guild', counters:{} }
        var campaign = new Campaign(events.goblin);

        campaign.isActive(player, "2012-12-13T12:12:00").should.equal(true);
        campaign.isActive(guild, "2012-12-13T12:12:00").should.equal(false);
        campaign.isActive(player, "2012-12-13T15:12:00").should.equal(false);

        player.counters.goblin.incr(1, "2012-12-13T12:12:00");
        campaign.isActive(player, "2012-12-13T12:12:00").should.equal(true);
        player.counters.goblin.incr(1, "2012-12-13T12:12:00");
        campaign.isActive(player, "2012-12-13T12:12:00").should.equal(true);
        player.counters.goblin.incr(1, "2012-12-13T12:12:00");
        campaign.isActive(player, "2012-12-13T12:12:00").should.equal(false);
        campaign.isActive(player, "2012-12-14T12:12:00").should.equal(true);
        //campaign.onEvent(player, "event_goblin_complete");
        //player.counters.goblin.counter.should.equal(1);
    });
});

//var _ = require('./underscore.js');
//var guildTemplate = { type: 'guild' };
//var campainTests = [
//function () {
//  
//  return true;
//},
//function () {
//  var player = _({counters:{}}).extend(_(playerTemplate).clone());
//  var guild = _({counters:{}}).extend(_(guildTemplate).clone());
//  var campaign = new Campaign(events.enhance);
//  
//  log(' '+0); if (!campaign.isActive(player, "2014-10-04T12:12:00")) return false;
//  log(' '+1); if (campaign.isActive(guild, "2014-10-04T12:12:00")) return false;
//  log(' '+2); if (campaign.isActive(player, "2014-10-03T15:12:00")) return false;
//  log(' '+3); if (campaign.isActive(player, "2014-10-06T15:12:00")) return false;
//  log(' '+4); if (!campaign.isActive(player, "2014-10-05T12:12:00")) return false;
//  
//  return true;
//},
//function () {
//  var player = _({
//    stage:{120:{level:12}},
//    timestamp: {}
//  }).extend(_(playerTemplate).clone());
//  var campaign = new Campaign(events.infinite);
//  
//  log(' '+0); if (!campaign.isActive(player, "2014-06-14")) return false;
//  log(' '+1); if (campaign.isActive(player, "2014-06-21")) return false;
//  log(' '+2); if (!campaign.canReset(player, "2014-06-21")) return false;
//  log(' '+3); campaign.reset(player, '2014-06-21'); if (player.stage[120].level != 0) return false;
//  log(' '+4); if (campaign.canReset(player, "2014-06-21")) return false;
//  
//  return true;
//}
//];
//
//function runTest(e) {
//  log(e.toString());
//  return e();
//}
//
//for (var k in campainTests) {
//  if ( !runTest( campainTests[k] )) {
//    console.log("This test failed.");
//    debug = true;
//    runTest( campainTests[k] );
//    break;
//  }
//}
//
////console.log(moment.isMoment());
////[F] min
////[F] max
////[F] utc
////[F] unix
////[F] updateOffset ?
////[F] isMoment
////[F] isDuration
////[F] weekdays
////[F] months
////[F] invalid
////[F] parseZone
////[F] parseTwoDigitYear
////var t = moment();
////console.log("valueOf", t.valueOf());
////console.log("unix", t.unix());
////console.log("utc", t.utc().format());
////console.log("toString", t.toString());
////console.log("toDate", t.toDate());
////console.log("toISOString", t.toISOString());
////console.log("toArray", t.toArray());
////console.log("isValid", t.isValid());
////console.log("isDSTShifted", t.isDSTShifted());
////console.log("parsingFlags", t.parsingFlags());
////console.log("invalidAt", t.invalidAt());
////console.log("subtract", t.subtract());
////console.log("diff", t.diff().valueOf());
////console.log("from", t.from(t.clone().startOf('month')));
////console.log("fromNow", t.fromNow());
////console.log("calendar", t.calendar());
////console.log("isLeapYear", t.isLeapYear());
////console.log("isDST", t.isDST());
////console.log("zone", t.zone());
////console.log("parseZone", t.parseZone());
////console.log("hasAlignedHourOffset", t.hasAlignedHourOffset());
////console.log("daysInMonth", t.daysInMonth());
////console.log("dayOfYear", t.dayOfYear());
////console.log("quarter", t.quarter());
////console.log("weekYear", t.weekYear());
////console.log("isoWeekYear", t.isoWeekYear());
////console.log("isoWeek", t.isoWeek());
////console.log("isoWeekday", t.isoWeekday());
////console.log("isoWeeksInYear", t.isoWeeksInYear());
////console.log("weeksInYear", t.weeksInYear());
////console.log("get", t.get());
////console.log("set", t.set());
////console.log("_dateTzOffset", t._dateTzOffset());
////console.log("milliseconds", t.milliseconds());
////console.log("millisecond", t.millisecond());
////console.log("toJSON", t.toJSON());
//
//numberConfig = {
//  campaign_goblin: function (theData, utils) {
//    return function () {
//      var count = 3;
//      if (theData.object.vipBounes().goblin) count += theData.object.vipBounes().goblin;
//      if (theData.object.guildBounes().goblin) count += theData.object.guildBounes().goblin;
//      if (theData.global.bounes().goblin) count += theData.global.bounes().goblin;
//      return count;
//    }
//  }
//};
//
//function ComposedNumber(create) { this.create = create; }
//ComposedNumber.prototype.valueOf = function () { return this.getter(); };
//ComposedNumber.prototype.toString = function () { return this.getter(); };
//ComposedNumber.prototype.toJSON = function () { return this.getter(); };

/*
var numberArray = [];
//GC test
function Player() {
  this.number = 0;
  this.buffer = new Buffer(1024*1024);
  this.buffer.fill('x');
  var that = this;
  function getter () {
    that.number += 1;
    return this.number+5;
  }
  this.counter = new ComposedNumber(getter.bind(this));
  // TODO: this cause crash
  // numberArray.push(this.counter);
}

util = require('util');
var keep = [];
console.log("Generating start");
for (var i = 0; i < 1601; i++) {
  keep.push(new Player());
  if (i % 100 == 0) console.log(i, util.inspect(process.memoryUsage()));
}
console.log("Generating done");
console.log("Releasing nodes");
var count = 0;
while (keep.length) {
  count += 1;
  count %= 100;
  keep.pop();
  if (count === 0) console.log(util.inspect(process.memoryUsage()));
}
console.log(util.inspect(process.memoryUsage()));
console.log("Generating start");
for (var i = 0; i < 1601; i++) {
  keep.push(new Player());
  if (i % 100 == 0) console.log(i, util.inspect(process.memoryUsage()));
}
*/
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
