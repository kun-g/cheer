var routerLib= require('../js/router');
var shall = require('should');

describe('Router', function () {
  before(function (done) {
    done();
  });

  it('ArgCheck', function () {

    function argErrorHandler(errorArg) {
      //console.log(errorArg);
      req ={CMD:1}
      err = {
        type : 'Handler Failed',
        cmd : req.CMD,
        error_message : "arg type invalid: arg:"+errorArg.argName+" expected:" 
        +errorArg.expectType+" actual???:" +errorArg.actualType}
      //console.log(err);
      throw (err);
    }

    var data =[
      {
        args :{name0:'p1', age0:1, danger0:false, food0:['apple','bread']},
        checkLst :{'name0':'string', age0:'number', danger0:'boolean', food0:'object'},
        result: true,
        errHandler:null,
        
      },
      {
        args :{name1:'p1', age1:1, danger1:false, food1:['apple','bread']},
        checkLst :{'name1':'string', age1:'number', danger1:'bool', food1:'object'},
        result: false,
        errHandler:null,
      },
      {
        args :{name2:'p1', age2:1, danger2:false, food2:['apple','bread']},
        checkLst :{'name2':'string', age2:'string', danger2:'boolean', food2:'object'},
        result:false,
        errHandler:argErrorHandler,
      },
      {
        args :{name3:'p1', age3:1, danger3:false },
        checkLst :{'name3':'string', age3:'number', danger3:'boolean', food3:{type:'object',opt:true}},
        result:true,
        errHandler:argErrorHandler,
      },
      {
        args :{name3:'p1', age3:1, danger3:false },
        checkLst :{'name3':'string', age3:'number', danger3:'boolean', food3:{type:'object',opt4:true}},
        result:false,
        errHandler:argErrorHandler,
      },




    ];
    
    data.forEach(function(e) {
      //routerLib.checkArgs(e.args, e.checkLst,e.errHandler);
      if (e.result) {
        (function() {routerLib.checkArgs(e.args, e.checkLst,e.errHandler);}).should.not.throw();
      } else {
        (function() {routerLib.checkArgs(e.args, e.checkLst,e.errHandler);}).should.throw();
      }
    });
  });
});

