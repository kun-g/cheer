/*
 * 游戏角色迁移工具
 */

var dbLib = require('./db');
var async = require('async');

function moveAccount(oldName, newName){
    var newAccountId;
    async.waterfall([
        function (cb) {
            getAccountIdByName(newName, cb);
        },
        function (newAID, cb) {
            newAccountId = newAID;
            getAccountIdByName(oldName, cb);
        },
        function (oldAID, cb) {
            getNameByAccountId(oldAID, cb);
        },
        function (theOldNam, cb) {
            if( theOldNam == oldName ){
                setNameOfAccountId(oldName, newAccountId, cb)
            }else{
                cb('Account&Name not match');
            }
        },
        function (cb) {
            setAccountIdOfPlayer(newAccountId, oldName, cb)
        }
    ], function (err) {
        if(err) console.log(err);
        else console.log('MoveAccount Done');
    })
}
exports.moveAccount = moveAccount;

function getNameByUserId(userId, tunnelType){
    async.waterfall([
        function (cb) {
            getAccountIdByUserId(userId, tunnelType, cb);
        },
        function (account, cb) {
            getNameByAccountId(account, cb)
        }
    ], function (err, name) {
        if(err) console.log(err);
        else {
            console.log('Name: '+name);
        }
    })
}
exports.getNameByUserId = getNameByUserId;

var getAccountIdByName = function (name, callback) {
    dbLib.getAccountByPlayerName(name, callback);
};

var getNameByAccountId = function (accountId, callback) {
    dbLib.getPlayerNameByID(accountId, gServerName, callback)
};

var setNameOfAccountId = function (name, accountId, callback) {
    dbLib.setNameOfAccount(accountId, name, callback);
};

var setAccountIdOfPlayer = function (accountId, playerName, callback) {
    dbLib.setAccountOfPlayer(playerName, accountId, callback);
};

var getAccountIdByUserId = function (userId, tunnel, callback) {
    dbLib.loadPassport(tunnel, userId, false, callback);
};