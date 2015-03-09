require('should');
verify = require('../js/timeUtils').verify;
function makeF(e) {
    return function () {
        verify(e.time, e.timeExp, {
            PLAYER: {
                created_date: '2014-02-14T12:42:04+08:00'
            },
            test: {
                date0: '2014-09-12T12:42:00',
            date1: '2014-09-13T12:42:00'
            }
        }).should.equal(e.result);
    }
}


describe('Time', function () {
    var verifyTests = [
    {
        time: '2014-5-13',
        timeExp: {
            time:{ time: "time@Arguments", offset: { day: 2 }, startOf: 'week' },
            units: 'day',
        },
        string:'is Tuesday',
        result: true
    },
    {
        time: '2014-5-12 0:59:0',
        timeExp: {
            time:{ time: "time@Arguments", offset: { day: 2 }, startOf: 'week' },
            units: 'day',
        },
        string:'is Tuesday',
        result: false
    },
 


    {
        time: '2014-12-03 0:59:0',
        timeExp: {
            duration: { minute: 1 },
            time: { time: 'time@Arguments', startOf: 'day', offset: { minute: 59 } }
        },
        string:'is 0:59:0',
        result: true
    },
    {
        time: '2014-12-03 1:0:0',
        timeExp: {
            duration: { minute: 1 },
            time: { time: 'time@Arguments', startOf: 'day', offset: { minute: 59 } }
        },
        string:'is 0:59:0',
        result: false
    },
 
    {
        time: '2014-12-03 1:59:0',
        timeExp: {
            duration: { minute: 1 },
            time: { time: 'time@Arguments', startOf: 'day', offset: { minute: 59 } }
        },
        string:'is 0:59:0',
        result: false
    },
    {
        time: '2014-12-03 0:58:0',
        timeExp: {
            duration: { minute: 1 },
            time: { time: 'time@Arguments', startOf: 'day', offset: { minute: 59 } }
        },
        string:'is 0:59:0',
        result: false
    },
 
    {
        time: null,
        timeExp: {
            duration: { days: 1 },
        time: '2014-12-03'
        },
        string:'is 2014-12-03',
        result: false
    },
    {
        time:  '2014-12-04',
        timeExp: {
            units: 'day',
        time: '2014-12-03'
        },
        string:'is not 2014-12-03',
        result: false
    },
    {
        time: {
            time: 'created_date@PLAYER',
            duration: { day: 3 }
        },
        timeExp: {
            duration: { day: 8 },
            time: 'created_date@PLAYER'
        },
        string:'8 days since created_date@PLAYER',
        result: true
    },
    {
        time: {
            time: 'created_date@PLAYER',
            offset: { day: 9 }
        },
        timeExp: {
            duration: { day: 8 },
            time: 'created_date@PLAYER'
        },
        string:'8 days since created_date@PLAYER',
        result: false
    },
    {
        time: null,
        timeExp: {
            time: '2014-06-09',
            duration: { month: 2 }
        },
        string: 'is between 2014-6-9 and 2014-8-9',
        result: false
    },
    {
        time: "2014-12-12T12:42:00",
        timeExp: {
            duration: { hour: 2 },
            time: {
                time: "time@Arguments",
                startOf: 'day',
                offset: { hour: 12 }
            }
        },
        string: 'is between 12:00 and 14:00',
        result: true
    },
    {
        time: "2014-12-12T15:42:00",
        timeExp: {
            duration: { hour: 2 },
            time: {
                time: "time@Arguments",
                startOf: 'day',
                offset: { hour: 12 }
            }
        },
        string: 'is between 12:00 and 14:00',
        result: false
    },
    {
        time: "date0@test",
        timeExp: {
            or: [
            {
                duration: {
                    hour: 2
                },
                time: {
                    time: "date0@test",
                    offset: { hour: 12 },
                    startOf: 'day'
                },
                units: "hours"
            },
            {
                duration: {
                    hour: 3
                },
                time: {
                    time: "date0@test",
                    offset: { hour: 17 },
                    startOf: 'day'
                },
                units: "hours"
            }
            ]
        },
        string: 'now is between 12:00 and 14:00 or between 17:00 and 20:00',
        result: true
    },
    {
        time: "date1@test",
        timeExp: {
            and: [
            {
                or: [
                {
                    duration: { hour: 2 },
                    time: { time: "date1@test", offset: { hour: 12 }, startOf: 'day' },
                    units: "hours"
                },
                {
                    duration: { hour: 3 },
                    time: { time: "date1@test", offset: { hour: 17 }, startOf: 'day' },
                    units: "hours"
                }
                ]
            },
            {
                or: [
                { time: {time: "date1@test", offset: { day: 0 }, startOf: 'week'}, units: 'day' },
                { time: {time: "date1@test", offset: { day: 2 }, startOf: 'week'}, units: 'day' },
                { time: {time: "date1@test", offset: { day: 4 }, startOf: 'week'}, units: 'day' },
                { time: {time: "date1@test", offset: { day: 6 }, startOf: 'week'}, units: 'day' }
                ]
            },
            ]
        },
        string: 'now is between 12:00 and 14:00 or between 17:00 and 20:00 of Sunday or Tuesday or Thursday or Saturday',
        result: true
    },
    {
        time: null,
        timeExp: {
            from: '2014-06-09',
            units: 'day'
        },
        string: 'now is after 2014-6-9',
        result: true
    },
    {
        time: "2014-12-12",
        timeExp: {
            time: 'time@Arguments', units: 'month' 
        },
        string: 'same month',
        result: true
    },
    {
        time: "2014-12-12",
        timeExp: {
            time: {
                time: 'time@Arguments',
                offset: { month: 1 }
            },
            units: 'month' 
        },
        string: 'same month',
        result: false
    }
    ];

    for (var k in verifyTests) {

        var e =  verifyTests[k];

        var f =  makeF(e);
        it('Unit Test#'+k, f);
    };
});


describe('Triger just in time', function () {
    var t = {
        time: { time: 'time@Arguments', startOf: 'day', offset: { minute: 59 } },
        duration: {minute:1},
    }
    var t2 = {
        time:{ time: "time@Arguments", offset: { day: 2 }, startOf: 'week' },
        units: 'day',

    } 
    var t3 = {
        time: { time: '2014-05-13'},
        units: 'day',
    }
 
    var memDB = {};
    var cfg = [
        {
            time: t,
            check:[[0,false], [1,true],[2,false],[3, false],[4,false]],
            str:'[59,60) only triger once'
        },
        {
            time: t,
            check:[[0,false], [2,true],[3, false],[4,false]],
            str:'[59,60) only triger once'
        },
        {
            time: t,
            check:[[0,false], [3,false],[4,false]],
            str:'[59,60) only triger once'
        },


        {
            time: t2,
            check:[[4,false], [5,true],[6,false], [7,true]],
            str:'triger when weekday 2'
        },

        {
            time: t3,
            check:[[4,false],[5,true],[8,false],[6,false]],
            str:'triger on special day'
        }

    ]
    var nowTimeLst = [
        '2014-05-11 0:58:49', //0
        '2014-05-11 0:59:00', //1
        '2014-05-11 0:59:59', //2
        '2014-05-11 1:0:0',   //3
        '2014-05-11 1:0:1',   //4
        '2014-05-13 1:0:1',   //5
        '2014-05-14 1:0:1',   //6
        '2014-05-20 1:0:1',   //7
        '2014-05-13 3:0:1',   //8
    ];
    var check = [
        {idx:[0,1,2], checkpoint:'once a day'},
        {idx:[3], checkpoint:'once a day'},
        {idx:[4], checkpoint:'once a day'},
        ];
    check.forEach(function(plan) {
        it(plan.checkpoint, function(done) {
            plan.idx.forEach(function(idx) {
                var e = cfg[idx];
                e.check.forEach(function(ck) {
                    var key = 'e'+idx;
                    var ret1 = verify(nowTimeLst[ck[0]], e.time, {}) 
                    //console.log('====?', ret1, nowTimeLst[0]);
                    var ret2 =  memDB[key] != true;
                    var ret = ret1 && ret2;
                    memDB[key] = ret1;
                    ret.should.equal(ck[1], 'check: '+idx + ' '+ nowTimeLst[ck[0]] + ret1+ret2);
                });
            });
            done();
        });
    });
});
