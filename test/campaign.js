var Counter = require('../js/counter').Counter;
require('should');

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
    var Campaign = require("../js/campaign").Campaign;
    it('Goblin', function () {
        var counter = {
            key: 'goblin',
            initial_value: 0,
            uplimit: 3,
            duration: { time: 'time@ThisCounter', units: 'day' }
        };
        var config = {
            storeType: "player",
            id: 0,
            counter: counter,
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
        };
        var player ={ type: 'player', counters:{} };
        var guild = { type: 'guild', counters:{} }
        var campaign = new Campaign(config);

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
    it('Enhance', function () {
        var counter = {
            key: 'enhance',
            initial_value: 0,
            uplimit: 3,
            duration: { time: 'time@ThisCounter', units: 'day' }
        };
        var config = {
            storeType: "player",
            id: 1,
            counter: counter,
            available_condition: [
            { type: 'counter', func: "notFulfiled" },
            {
                type: 'time',
                timeExpr: {
                    or: [
                    { time:{ time:"time@Arguments", offset:{ day:0 }, startOf:'week'}, units:'day' },
                    { time:{ time:"time@Arguments", offset:{ day:2 }, startOf:'week'}, units:'day' },
                    { time:{ time:"time@Arguments", offset:{ day:4 }, startOf:'week'}, units:'day' },
                    { time:{ time:"time@Arguments", offset:{ day:6 }, startOf:'week'}, units:'day' }
                    ]
                }
            }
            ]
        };
        var player ={ type: 'player', counters:{} };
        var guild = { type: 'guild', counters:{} }
        var campaign = new Campaign(config);
        campaign.isActive(player, "2014-10-04T12:12:00").should.equal(true);
        campaign.isActive(guild, "2014-10-04T12:12:00").should.equal(false);
        campaign.isActive(player, "2014-10-03T15:12:00").should.equal(false);
        campaign.isActive(player, "2014-10-06T15:12:00").should.equal(false);
        campaign.isActive(player, "2014-10-05T12:12:00").should.equal(true);
    });
    it('Endless/Hunting', function () {
        var config = {
            storeType: "player",
            id: 3,
            available_condition: [
            {
                type: 'function',
                func: function (theData, utils) {
                    return Math.floor(utils.libTime.diff(theData.time,'2014-06-14').as('week'))%2==0;
                }
            }
            ],
            reset_condition: {
                or: [
                {
                    type: 'function',
                    func: function (theData, utils) { return !theData.object.timestamp.infinite; }
                },
                {
                    type: 'time',
                    timeExpr: {
                        not: [ { time: 'infinite@Timestamp', units: 'week' } ]
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
                    obj.stage[120]['level'] = 0;
                    //TODO:uncomment this
                    //obj.notify('stageChanged',{stage:120})
                }
            }
            ]
        };
        var player ={ type: 'player', counters:{}, stage:{120:{level:12}}, timestamp: {} };
        var guild = { type: 'guild', counters:{} }
        var campaign = new Campaign(config);

        campaign.isActive(player, "2014-06-14").should.equal(true);
        campaign.isActive(player, "2014-06-21").should.equal(false);
        campaign.canReset(player, "2014-06-21").should.equal(true);
        campaign.reset(player, '2014-06-21'); player.stage[120].level.should.equal(0);
        campaign.canReset(player, "2014-06-21").should.equal(false);
    });
    it('Month Card', function () {
        var counter = {
            key: 'monthCard',
            initial_value: 0,
            //uplimit: 31,
            uplimit: 3,
            count_down: { time: 'time@ThisCounter', units: 'day' },
            duration: { time: 'time@ThisCounter', units: 'month' }
        };
        var config = {
            storeType: "player",
            id: -1,
            counter: counter,
            available_condition: [ { type: 'counter', func: "notCounted" } ]
        };
        var player ={type:'player', counters:{monthCard:{counter:2,time:"2014-06-13"}}, timestamp:{}};
        var guild = { type: 'guild', counters:{} };
        var campaign = new Campaign(config);
        campaign.isActive(player, "2014-06-14").should.equal(true);
        player.counters.monthCard.counter.should.equal(2);
        campaign.activate(player, 1, "2014-06-14");
        player.counters.monthCard.counter.should.equal(3);
        campaign.isActive(player, "2014-06-14").should.equal(false);
        campaign.isActive(player, "2014-06-15").should.equal(true);
        campaign.isActive(player, "2014-07-01").should.equal(true);
        campaign.activate(player, 1, "2014-07-01");
        player.counters.monthCard.counter.should.equal(1);
    });
    it('PK', function () {
        var counter = {
            key: 'monthCard',
            initial_value: 0,
            uplimit: 5,
            duration: { time: 'time@ThisCounter', units: 'day' }
        };
        var config = {
            storeType: "player",
            id: -1,
            counter: counter,
            available_condition: [ { type: 'counter', func: "notFulfiled" } ]
        };
        var player ={ type: 'player', counters:{}, timestamp: {} };
        var guild = { type: 'guild', counters:{} }
        var campaign = new Campaign(config);
        campaign.isActive(player, "2014-06-14").should.equal(true);
        player.counters.monthCard.incr(1, "2014-06-14").counter.should.equal(1);
        player.counters.monthCard.incr(1, "2014-06-14").counter.should.equal(2);
        player.counters.monthCard.incr(1, "2014-06-14").counter.should.equal(3);
        player.counters.monthCard.incr(1, "2014-06-14").counter.should.equal(4);
        player.counters.monthCard.incr(1, "2014-06-14").counter.should.equal(5);
        campaign.isActive(player, "2014-06-14").should.equal(false);
        campaign.isActive(player, "2014-06-15").should.equal(true);
        player.counters.monthCard.incr(1, "2014-06-15").counter.should.equal(1);
    });
    it('Startup', function () {
        var server = {type:'server', counters:{}, timestamp:{}};
        var player = {type:'player', counters:{}, timestamp:{}, getServer:function(){return server;}};
        var configPlayer = {
            storeType: "player",
            counter: {
                key: 'startupReward',
                initial_value: 0,
                count_down: { time: 'time@ThisCounter', units: 'day' }
            },
            available_condition: [
                { type: 'counter', func: "notCounted" },
                {
                    type: 'function',
                    func: function (theData, utils) {
                        return campaignServer.isActive(theData.object.getServer(), theData.time);
                    }
                }
            ],
            activate: function (theData, util) {
                var obj = theData.object;
                var server = obj.getServer();
                var prize = server.startup_reward;
                obj.mail = prize;
            }
        };
        var configServer = {
            storeType: "server",
            counter: {
                key: 'startupReward',
                initial_value: -1,
                uplimit: 2,
                count_down: { time: 'time@ThisCounter', units: 'day' }
            },
            available_condition: [ { type: 'counter', func: "notFulfiled" } ],
            update: function (theData, util) {
                var obj = theData.object;
                var counter = obj.counters.startupReward;
                obj.startup_reward = counter.counter;
            }
        };
        var campaignPlayer = new Campaign(configPlayer);
        var campaignServer = new Campaign(configServer);
        campaignServer.isActive(server, "2014-06-14").should.equal(true);
        campaignPlayer.isActive(player, "2014-06-14").should.equal(true);
        campaignServer.isActive(player, "2014-06-14").should.equal(false);
        campaignServer.activate(server, 1, "2014-06-14"); campaignServer.update(server);
        server.startup_reward.should.equal(0);
        campaignPlayer.activate(player, 1, "2014-06-14"); player.mail.should.equal(0);
        campaignServer.activate(server, 1, "2014-06-14"); campaignServer.update(server);
        server.startup_reward.should.equal(0);
        campaignServer.activate(server, 1, "2014-06-14"); campaignServer.update(server);
        server.startup_reward.should.equal(0);

        campaignServer.isActive(server, "2014-06-15").should.equal(true);
        campaignPlayer.isActive(player, "2014-06-15").should.equal(true);
        campaignServer.activate(server, 1, "2014-06-15"); campaignServer.update(server);
        campaignPlayer.activate(player, 1, "2014-06-15"); player.mail.should.equal(1);
        server.startup_reward.should.equal(1);
        campaignPlayer.activate(player, 1, "2014-06-15"); player.mail.should.equal(1);

        campaignServer.activate(server, 1, "2014-06-16"); campaignServer.update(server);
        server.startup_reward.should.equal(2);
        campaignServer.isActive(server, "2014-06-16").should.equal(false);
        campaignPlayer.isActive(player, "2014-06-16").should.equal(false);
    });


    /*
    it('FirstCharge', function () {
        var config = {
            storeType: "player",
            counter: {
                key: 'firstCharge',
                iniitial_value: 0,
                uplimit: 1
            },
            available_condition: [ { type: 'counter', func: "notFulfiled" } ]
        };
    });
    */

    it('Daily Event', function () {
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
    });
    it('Equipment Robbers', function () {
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
    });
/*
    it('charge', function () {
        var config = {
        "show": true,
        "title": "中秋充值奖励",
        "banner":"event-banner-wzydr.png",
        "description": [],
        "mailTitle": "《中秋充值》活动奖励",
        "mailBody": "恭喜你完成活动，点击领取活动奖励！",
        "date": "2014/09/15",
        "dateDescription": "截止日期2014年9月15日24时",
        "objective": {
            "6": { "award": [ {"type":0,"value":853,"count":5}, {"type":0,"value":540,"count":2} ] },
            "12": {
                "award": [
                    {"type":0,"value":853,"count":10},
                    {"type":0,"value":540,"count":2},
                    {"type":0,"value":538,"count":1}
                ]
            },
            "30": {
                "award": [
                    {"type":0,"value":871,"count":5},
                    {"type":0,"value":540,"count":3},
                    {"type":0,"value":538,"count":1}
                ]
            },
            "68": {
                "award": [
                    {"type":0,"value":871,"count":5},
                    {"type":0,"value":538,"count":1},
                    {"type":0,"value":540,"count":4},
                    {"type":0,"value":860,"count":1}
                ]
            },
            "128": {
                "award": [
                    {"type":0,"value":871,"count":10},
                    {"type":0,"value":539,"count":1},
                    {"type":0,"value":860,"count":3},
                    {"type":0,"value":552,"count":1}
                ]
            },
            "198": {
                "award": [
                    {"type":0,"value":871,"count":20},
                    {"type":0,"value":539,"count":1},
                    {"type":0,"value":552,"count":1},
                    {"type":0,"value":860,"count":6}
                ]
            },
            "328": {
                "award": [
                    {"type":0,"value":871,"count":20},
                    {"type":0,"value":28,"count":4},
                    {"type":0,"value":551,"count":1},
                    {"type":0,"value":860,"count":10}
                ]
            },
            "648": {
                "award": [
                    {"type":0,"value":871,"count":30},
                    {"type":0,"value":28,"count":10},
                    {"type":0,"value":552,"count":1},
                    {"type":0,"value":551,"count":1},
                    {"type":0,"value":860,"count":20}
                ]
            }
        }
    }
    });
/*
    "Charge": ,
    "DuanwuCharge": {
        "show": true,
        "title": "端午粽子派送",
        "banner":"event-banner-dwj.png",
        "description": [
            "单笔充值达到6元，12元，30元，68元，128元，198元，328元，648元分别得到奖励。",
            "***奖励内容：",
            "充值6元，即可获得",
            "##[{\"type\":2,\"count\":60},{\"type\":0,\"value\":862,\"count\":1}]",
            "** \n充值12元，即可获得",
            "##[{\"type\":2,\"count\":130},{\"type\":0,\"value\":862,\"count\":3}]",
            "** \n充值30元，即可获得",
            "##[{\"type\":2,\"count\":330},{\"type\":0,\"value\":862,\"count\":7}]",
            "** \n充值68元，即可获得",
            "##[{\"type\":2,\"count\":760},{\"type\":0,\"value\":862,\"count\":10}]",
            "** \n充值128元，即可获得",
            "##[{\"type\":2,\"count\":1460},{\"type\":0,\"value\":862,\"count\":10},{\"type\":0,\"value\":863,\"count\":3}]",
            "** \n充值198元，即可获得",
            "##[{\"type\":2,\"count\":2260},{\"type\":0,\"value\":862,\"count\":12},{\"type\":0,\"value\":863,\"count\":6}]",
            "** \n充值328元，即可获得",
            "##[{\"type\":2,\"count\":3760},{\"type\":0,\"value\":862,\"count\":15},{\"type\":0,\"value\":863,\"count\":9}]",
            "** \n充值648元，即可获得",
            "##[{\"type\":2,\"count\":7480}, {\"type\":0,\"value\":862,\"count\":17},{\"type\":0,\"value\":863,\"count\":11}]"
        ],
        "mailTitle": "《端午送粽子》活动奖励",
        "mailBody": "恭喜你完成活动，点击领取礼包！",
        "date": "2014/06/05",
        "dateDescription": "截止日期2014年6月5日24时",
        "objective": {
            "6": {
                "award": [
                    {"type":0,"value":862,"count":1}
                ]
            },
            "12": {
                "award": [
                    {"type":0,"value":862,"count":3}
                ]
            },
            "30": {
                "award": [
                    {"type":0,"value":862,"count":7}
                ]
            },
            "68": {
                "award": [
                    {"type":0,"value":862,"count":10}
                ]
            },
            "128": {
                "award": [
                    {"type":0,"value":862,"count":10},
                    {"type":0,"value":863,"count":3}
                ]
            },
            "198": {
                "award": [
                    {"type":0,"value":862,"count":12},
                    {"type":0,"value":863,"count":6}
                ]
            },
            "328": {
                "award": [
                    {"type":0,"value":862,"count":15},
                    {"type":0,"value":863,"count":9}
                ]
            },
            "648": {
                "award": [
                    {"type":0,"value":862,"count":17},
                    {"type":0,"value":863,"count":11}
                ]
            }
        }
    },
  "LevelUp": {
    "show": true,
      "banner":"event-banner-jncj.png",
    "title": "冲级得礼包",
    "description": ["玩家凡注册之日起一周内冲到6级即可获得丰厚奖励。"],
      "mailTitle": "《冲级得礼包》奖励",
      "mailBody": "恭喜你完成冲级活动，点击领取奖励！",
      "date": "2014/07/05",
      "timeLimit": 604800,
      "dateDescription": "截止日期为2014年7月5日24时",
    "level": [
      {
        "count": 6,
        "award": [
            {"type":1, "count":6000 },
            { "type":2,"count":150 }
        ]
      }
    ]
  },
  "TotalCharge": {
    "show": false,
    "title": "累充活动",
    "description": ["累积充值达到指定数值，即可获得相应礼包！"],
      "mailTitle": "VIP等级提升",
      "mailBody": "VIP等级得到提升，您已经拥有购买相应VIP宝箱的权限以及以礼品。",
    "level": [
      {
        "count": 30,
        "award": [
            {"type":2, "count":100 },
            {"type":0,"value":540,"count":3},
            {"type":0,"value":539,"count":1}
        ]
      },
        {
            "count": 100,
            "award": [
                {"type":2, "count":300 },
                {"type":0,"value":540,"count":3},
                {"type":0,"value":539,"count":1}
            ]
        },
        {
            "count": 150,
            "award": [
                {"type":0,"value":540,"count":3},
                {"type":0,"value":539,"count":1},
                {"type":0,"value":871,"count":10}
            ]
        },
        {
            "count": 250,
            "award": [
                {"type":0,"value":540,"count":3},
                {"type":0,"value":539,"count":1},
                {"type":0,"value":871,"count":20}
            ]
        },
        {
            "count": 400,
            "award": [
                {"type":0,"value":540,"count":3},
                {"type":0,"value":871,"count":30}
            ]
        },
        {
            "count": 850,
            "award": [
                {"type":0,"value":540,"count":3}
            ]
        },
        {
            "count": 1400,
            "award": [
                {"type":0,"value":540,"count":3}
            ]
        }
    ]
  },
  "Friend": {
    "show": true,
    "title": "朋友去哪儿？！",
      "banner":"event-banner-zyqne.png",
    "description": ["俗话说“一个好汉三个帮”，身为勇士的你单枪匹马可不成，多加些小伙伴一起冒险吧。活动期间内成功添加20名好友就有惊喜大礼哦！"],
    "mailTitle": "《朋友去哪儿？！》活动奖励",
    "mailBody": "恭喜你完成《朋友去哪儿？！》活动，点击领取奖励礼包！",
    "date": "2014/02/28",
    "dateDescription": "截止日期2014年2月28日24时",
    "level": [
      {
        "count": 20,
        "award": [
            { "type":2, "count":50 },
            { "type":0,"value":0, "count":5 },
            { "type":0,"value":540, "count":1 }
        ]
      }
    ]
  },
};
*/
});
});
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
