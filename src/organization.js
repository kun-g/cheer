var organizationPrefix = '';
var guildPrefix = '';
var status = 'Initializing';

var Type_Guild = 'guild';


exports.onDatabaseReady = function () {
    organizationPrefix = dbPrefix + 'org' + dbSeparator;
    guildPrefix = dbPrefix + 'org' + dbSeparator + 'guild' + dbSeparator;
};

exports.prefix = 'org';
exports.router = {
    create_guild: function (params, response) {
        var name = params.name;
        console.log("create_guild", name);
        response(name);
        //dbClient.hset(guildPrefix+name, {name: name}, function (err, res) {
        //    console.log(err, res);
        //});
    },
    deleteGuild: function (params, response) {
    },
};
