shall = require('should');
require('../js/define');
var playerLib = require('../js/player');
//var assert = require("assert");
//var serialLib = require('../serializer');
//var dungeonLib = require('../js/dungeon');
//var should = require('should');
//var spellLib = require('../js/spell');
var helpLib = require('../js/helper');
var dbLib = require('../js/db');


dbPrefix = 'Develop'+'.';
dbLib.initializeDB({
  "Account": { "IP": "10.4.3.41", "PORT": 6379},
  "Role": { "IP": "10.4.3.41", "PORT": 6379},
  "Publisher": { "IP": "10.4.3.41", "PORT": 6379},
  "Subscriber": { "IP": "10.4.3.41", "PORT": 6379}
  // "Account": { "IP": "localhost", "PORT": 6379},
  // "Role": { "IP": "localhost", "PORT": 6379},
  // "Publisher": { "IP": "localhost", "PORT": 6379},
  // "Subscriber": { "IP": "localhost", "PORT": 6379}
});

/*
var unitLib = require('../js/unit');

describe('Unit', function () {
    it('levelUp', function () {
        //var data =[
        //{exp: 0, lvl: 1, skill:{'0':1,'76':1}},
        //{exp: 110, lvl: 2, skill:{'0':1,'76':1}},
        //{exp: 300, lvl: 3, skill:{'0':1,'2':1,'76':1}},
        //{exp: 1600, lvl: 9, skill:{'0':2,'2':1, '76':1}},
        //{exp: 1603, lvl: 9, skill:{'0':2,'2':1, '76':1}},
        //{exp: 300, lvl: 4, skill:{'2':1}},
        //{exp: 300, lvl: 4, skill:{'2':1}},
        //{exp: 300, lvl: 4, skill:{'2':1}},
        //]

        //helpLib.initLeaderboard(queryTable(TABLE_LEADBOARD));
    });
});

*/
