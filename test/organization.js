var libOrg = require('../js/organization');
var libRPC = require('../js/rpc');
var RPC_Client = libRPC.RabbitMQ_RPC_Client;
Organization = libOrg.Organization;

//describe('Organization', function () {
//    it('Member management, Attribute modification(no priviledge)', function () {
//        var org = new Organization();
//        org.addMember('ken'); org.members().should.equal(['ken']);
//        org.delMember('ken'); org.members().should.equal([]);
//        org.setAttr('level', 0); org.attr('level').should.equal(0);
//    });
//    it('Member management, Stats modification(with priviledge)', function () {
//        var org = new Organization({
//            priviledge: { member: true, priviledge: true }
//        });
//        org.setCreator("ken");
//        var invitation = org.invite("kun").by("ken");
//        //org.invite(
//    });
//});

var Guild = libOrg.Guild;

describe('Guild', function () {
    //it('Creation/Member/Priviledge', function () {
    //    var g = new Guild('Ken');
    //    invitation = g.invite('kun').by('Ken'); invitation.accept();
    //    invitation = g.invite('kevin').by('Ken'); invitation.decline();
    //    g.members({name:'kun'}).length.should.equal(1);
    //    g.members({name:'kevin'}).length.should.equal(0);
    //    g.assign
    //});
    it('RPC', function (done) {
        console.log(libOrg.prefix+'_rpc');
        RPC_Client('amqp://106.186.31.71', 'ken', 'tringame', libOrg.prefix+'_rpc',
            function (client) {
                client.request(libOrg.prefix+'.create_guild', {name: 'test'}, done);
            });
    });
});
