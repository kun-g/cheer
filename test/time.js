require('should');
verify = require('../js/timeUtils').verify;

describe('Time', function () {
    var verifyTests = [
    {
        time: null,
        timeExp: {
            units: 'day',
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

    var theData = {
        PLAYER: {
            created_date: '2014-02-14T12:42:04+08:00'
        },
        test: {
            date0: '2014-09-12T12:42:00',
            date1: '2014-09-13T12:42:00'
        }
    };

    for (var k in verifyTests) {
        it('Unit Test#'+k, function () {
            var e =  verifyTests[k];
            verify(e.time, e.timeExp, theData).should.equal(e.result);
        });
    };
});
