libOrg = require('../js/organization');
Organization = libOrg.Organization;

describe('Organization', function () {
    it('Member management, Attribute modification(no priviledge)', function () {
        var org = new Organization();
        org.addMember('ken'); org.members().should.equal(['ken']);
        org.delMember('ken'); org.members().should.equal([]);
        org.setAttr('level', 0); org.attr('level').should.equal(0);
    });
    it('Member management, Stats modification(with priviledge)', function () {
        var org = new Organization({
            priviledge: { member: true, priviledge: true }
        });
        org.setCreator("ken");
        var invitation = org.invite("kun").by("ken");
        //org.invite(
    });
});

var Guild = libOrg.Guild;

describe('Guild', function () {
    it('Creation/Member/Priviledge', function () {
        var g = new Guild('Ken');
        invitation = g.invite('kun').by('Ken'); invitation.accept();
        invitation = g.invite('kevin').by('Ken'); invitation.decline();
        g.members({name:'kun'}).length.should.equal(1);
        g.members({name:'kevin'}).length.should.equal(0);
        g.assign
    });
});
