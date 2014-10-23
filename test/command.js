var shall = require('should');
var Command = require('../js/commandStream').Command;
var installCommandExtention = require('../js/commandStream').installCommandExtention;
var makeCommand = require('../js/commandStream').makeCommand;

describe('Command', function () {
    it('Install extendtion', function () {
        function test () { }
        installCommandExtention(test);
        var obj = new test();
        obj.should.not.have.property('executeCommand');

        test.prototype.getCommandConfig = function () {};
        installCommandExtention(test);
        obj = new test();
        obj.should.have.property('executeCommand');
        obj.should.have.property('makeCommand');
    });

    describe('Basic', function () {
        var tests = {
            modify_property: function () {
                var obj = {};
                var property = {a:1, b:2, c:3};
                var c = makeCommand('modify_property');
                c.execute(obj, property);
                obj.should.eql(property);
                c.undo();
                obj.should.eql({});
            },
            incress_property: function () {
                var property = {a:1, b:2, c:3};
                var obj = {a:1, d: 1};
                var c = makeCommand('incress_property');
                c.execute(obj, property);
                obj.should.eql({a:2, b:2, c:3, d:1});
                c.undo();
                obj.should.eql({a:1, d:1});
            }
        };

        for (var k in tests) {
            var t = tests[k];
            if (typeof t === 'function') {
                it(k, t);
            } else {
                console.log('NotImplemented', typeof t);
            }
        }
    });
});
