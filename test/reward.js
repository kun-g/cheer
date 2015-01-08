require('should');
var libReward = require('../js/reward');

var env = {};

function Player () {
    this.reward_modifier = libReward.config.reward_modifier;
    this.envReward_modifier = env;
}

for (var k in libReward) {
    if (typeof libReward[k] === 'function') Player.prototype[k] = libReward[k];
}

describe('Reward', function () {
    describe('Generation', function () {
        var p = new Player();
        var rewardConfig = [[
            {
                "rate": 1,
                "prize": [ { "weight": 1, "type": PRIZETYPE_GOLD, "count": 100 } ]
            },
            {
                "rate": 0.9,
                "prize": [
                    { "weight": 1, "type": PRIZETYPE_ITEM, "value": 853, "count": 1 },
                    { "weight": 3, "type": PRIZETYPE_GOLD, "count": 50 },
                    { "weight": 1, "type": PRIZETYPE_ITEM, "value": 854, "count": 5 }
                ]
            },
        ],[
            {
                "rate": 1,
                "prize": [ { "weight": 1, "type": PRIZETYPE_GOLD, "count": 100 } ]
            },
        ]];
        queryTable = function () { return rewardConfig; }
        it('without modifier', function () {
            p.generateReward(rewardConfig, [0], function () { return 0.95; }).should.eql(
                [{type: PRIZETYPE_GOLD, count: 100}]
            );
            p.generateReward(rewardConfig, [0], function () { return 0; }).should.eql(
                [{type:PRIZETYPE_ITEM, value: 853, count:1}, {type: PRIZETYPE_GOLD, count: 100} ]
            );
        });
        it('without duplicate', function () {
            env.gold = 0.2;
            p.generateReward(rewardConfig, [0], function () { return 0.21; }).should.eql(
                [{type: PRIZETYPE_GOLD, count: 150} ]
            );
        });

        it('dungeon reward#0', function () {
            var dungeon = {
                result: DUNGEON_RESULT_DONE,
                config: {goldRate:0.6, prizeGold: 100},
                killingInfo: [{dropInfo:[1]}],
                prizeInfo: []
            };
            p.generateDungeonReward(dungeon).should.eql([]);
            dungeon.result = DUNGEON_RESULT_WIN;
            p.generateDungeonReward(dungeon).should.eql([
                {type:PRIZETYPE_GOLD, count: 100*0.6 + 100}
            ]);
        });
        it('dungeon reward#1', function () {
            var dungeon = {
                result: DUNGEON_RESULT_DONE,
                config: {goldRate:0.6, prizeGold: 100},
                killingInfo: [{dropInfo:[1]}],
                prizeInfo: [
                    {type:PRIZETYPE_ITEM, value: 854, count:1},
                    {type:PRIZETYPE_ITEM, value: 854, count:2},
                    {type: PRIZETYPE_GOLD, count: 110}
                ]
            };
            p.reward_modifier.dungeon_gold = 1;
            env.dungeon_gold = 1;
            env.dungeon_item_count = 1;
            p.generateDungeonReward(dungeon).should.eql([]);
            dungeon.result = DUNGEON_RESULT_WIN;
            p.generateDungeonReward(dungeon).should.eql([
                {type:PRIZETYPE_ITEM, value: 854, count:6},
                {type:PRIZETYPE_GOLD, count: (100*0.6 + 100 + 110) * 3}
            ]);
        });

        it('sweep reward', function () {
        });
    });

    it('Claim', function () { });
});
