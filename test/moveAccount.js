/*
 * 游戏角色迁移工具
 * 参数: oldName newName [serverIP accountPort playerPort Branch]
 *
 * Created By Jovi
 */

var redis = require('redis');
var async = require('async');

var OLD_NAME = 'Lily';
var NEW_NAME = 'Lucy';
var serverIP = '10.4.3.41';
var accountPort = '6380';
var playerPort = '6380';
var Branch = 'Master';

var accountDB = redis.createClient(accountPort, serverIP);
var playerDB = redis.createClient(playerPort, serverIP);


function main(args){
    if(args[2]) serverIP = args[2];
    if(args[3]) accountPort = args[3];
    if(args[4]) playerPort = args[4];
    if(args[5]) Branch = args[5];
    moveAccount(args[0], args[1]);
}

function moveAccount(oldName, newName){
    var newAccountId;
    async.waterfall([
        function (cb) {
            getAccountIdByName(newName, cb)
        },
        function (newAID, cb) {
            newAccountId = newAID;
            setNameOfAccountId(oldName, newAID, cb)
        },
        function (cb) {
            setAccountIdOfPlayer(newAccountId, oldName, cb)
        }
    ], function (err) {
        if(err) console.log(err);
        else console.log('MoveAccount Done');
    })
}

var getAccountIdByName = function (name, callback) {
    playerDB.hget(makeFullName(name), 'accountID', callback);
};

var setNameOfAccountId = function (name, accountId, callback) {
    accountDB.hset(makeFullAccount(accountId), Branch, name, callback);
};

var setAccountIdOfPlayer = function (accountId, playerName, callback) {
    playerDB.hset(makeFullName(playerName), 'accountID', accountId, callback);
};

var makeFullName = function (name) {
    return Branch+'.player.'+name;
};

var makeFullAccount = function (accountId) {
    return 'Account.'+accountId;
};

main(process.argv.slice(2));