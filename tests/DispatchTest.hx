package;

import haxe.Constraints.IMap;
import haxe.PosInfos;
import haxe.Timer;
import haxe.io.Bytes;
import tink.core.Error.ErrorCode;
import tink.http.Header;
import tink.http.Header.HeaderField;
import tink.http.Message;
import tink.http.Request;
import tink.http.Response.OutgoingResponse;
import tink.io.Source;
import tink.web.Session;
import tink.web.routing.Context;
import tink.web.routing.Router;
import tink.testrunner.*;
import tink.unit.Assert.*;
import deepequal.DeepEqual.*;
//import tink.web.helpers.AuthResult;

//import tink.web.Request;
//import tink.web.Response;
//import tink.web.Router;
import haxe.ds.Option;

using tink.io.Source;
using tink.CoreApi;

@:asserts
@:allow(tink.unit)
class DispatchTest {
  
  static function loggedin(admin:Bool, id:Int = 1):Session<{ admin: Bool, id:Int }>
    return {
      getUser: function () return Some({ admin: admin, id:id }),
    }
    
  static var anon:Session<{ admin: Bool, id:Int }> = { getUser: function () return None };
  
  static function logginFail():Session<{ admin: Bool, id:Int }>
    return { getUser: function () return new Error('whoops') };
    
  static var f = new Fake();
  
  public static function exec(req, ?session):Promise<OutgoingResponse> {
    
    if (session == null)
      session = loggedin(true);
      
    return 
      new Router<Session<{ admin: Bool, id:Int }>, Fake>(f)
        .route(Context.authed(req, function (_) return session));
  }
  
  public function new() {}
  
  @:variant({ flag: true },               get('/flag/'))
  @:variant({ number: 123 },              get('/count/'))
  @:variant({ number: 321 },              get('/count/321'))
  @:variant({ hello: 'world' },           get('/'))
  @:variant('<p>Hello world</p>',         get('/', []))
  @:variant({ hello: 'haxe' },            get('/haxe'))
  @:variant("yo",                         get('/yo'))
  @:variant({ foo: 'hey', bar: 4 },       req('/post', POST, [new tink.http.Header.HeaderField('content-type', 'application/x-www-form-urlencoded')], 'bar=4&foo=hey'))
  @:variant({ foo: 'hey', bar: 4 },       req('/post', POST, [new tink.http.Header.HeaderField('content-type', 'application/json')], haxe.Json.stringify({ foo: 'hey', bar: 4 })))
  @:variant({header: 'application/json'}, get('/headers', [new tink.http.Header.HeaderField('accept', 'application/json')]))
  @:variant({ a: 1, b: 2, c: '3', d: '4', blargh: 'yo', /*path: ['sub', '1', '2', 'test', 'yo']*/ }, 
     get('/sub/1/2/test/yo?c=3&d=4'))
  @:variant({ foo: ([ { z: .0 }, { x: 'hey', z: .1 }, { y: 4, z: .2 }, { x: 'yo', y: 5, z: .3 } ]:Array<Dynamic>) },
     get('/complex?foo[0].z=.0&foo[1].x=hey&foo[1].z=.1&foo[2].y=4&foo[2].z=.2&foo[3].x=yo&foo[3].y=5&foo[3].z=.3'))
  public function dispatch(value:Dynamic, req, ?session)
    return expect(value, req, session);
  
  
  @:variant(UnprocessableEntity, get('/count/foo'))
  @:variant(UnprocessableEntity, get('/sub/1/2/test/yo'))
  @:variant(UnprocessableEntity, req('/post', POST, [], 'bar=4'))
  @:variant(UnprocessableEntity, req('/post', POST, [new tink.http.Header.HeaderField('content-type', 'application/x-www-form-urlencoded')], 'bar=bar&foo=hey'))
  @:variant(UnprocessableEntity, req('/post', POST, [], 'bar=5&foo=hey'))
  public function dispatchError(code:ErrorCode, req, ?session)
    return shouldFail(code, req, session);
  
  
  function multipartReq()
    return req('/upload', POST, [
      new HeaderField('Content-Type', 'multipart/form-data; boundary=----------287032381131322'),
      new HeaderField('Content-Length', 514),
    ], 
      '------------287032381131322\r\nContent-Disposition: form-data; name="datafile1"; filename="r.gif"\r\nContent-Type: image/gif\r\n\r\nGIF87a.............,...........D..;\r\n------------287032381131322\r\nContent-Disposition: form-data; name="datafile2"; filename="g.gif"\r\nContent-Type: image/gif\r\n\r\nGIF87a.............,...........D..;\r\n------------287032381131322\r\nContent-Disposition: form-data; name="datafile3"; filename="b.gif"\r\nContent-Type: image/gif\r\n\r\nGIF87a.............,...........D..;\r\n------------287032381131322--\r\n'
    );
  
  #if tink_multipart
  public function multipart() {
    return expect({
      content: 'GIF87a.............,...........D..;',
      name: 'r.gif',
    }, multipartReq());
  }
  #else
  public function multipart()
    return shouldFail(NotAcceptable, multipartReq());
  #end
  
  @:variant({ foo: 'bar' },     get('/sub/1/2/whatever')                                    )
  @:variant({ id: -1 },         get('/anonOrNot'),          DispatchTest.anon               )
  @:variant({ id: 1 },          get('/anonOrNot')                                           )
  @:variant({ id: 4 },          get('/anonOrNot'),          DispatchTest.loggedin(true, 4)  )
  @:variant({ admin: true },    get('/withUser')                                            )
  @:variant({ admin: false },   get('/withUser'),           DispatchTest.loggedin(false, 2) )
  public function auth(value:Dynamic, req, ?session)
    return expect(value, req, session);
  
  @:variant(Unauthorized, get('/withUser'),          DispatchTest.anon)
  @:variant(Unauthorized, get('/'),                  DispatchTest.anon)
  @:variant(Unauthorized, get('/haxe'),              DispatchTest.anon)
  @:variant(Forbidden,    get('/noaccess')                            )
  @:variant(Forbidden,    get('/sub/2/2/')                            )
  @:variant(Forbidden,    get('/sub/1/1/whatever')                    )
  public function authError(code:ErrorCode, req, ?session)
    return shouldFail(code, req, session);
  
  
  static function expect(value:Dynamic, req, ?session, ?pos:PosInfos) {
    return exec(req, session).next(function (o):Promise<Assertion>
      return if (o.header.statusCode != 200)
        new Assertion(false, 'Request to ${req.header.url} failed because ${o.header.reason} (${o.header.statusCode.toInt()})');
      else
        o.body.all().next(function (b)
          return if (Std.is(value, String))
            assert(compare(value, b.toString(), pos), null, pos)
          else
            assert(compare(value, haxe.Json.parse(b.toString()), pos), null, pos)
        )
    );
  }
  
  static function shouldFail(code, req, ?session, ?pos:PosInfos) {
    return exec(req, session)
      .map(function(o) return switch o {
        case Success(_): new Assertion(false, 'Expected Failure but got Success', pos);
        case Failure(e): assert(e.code == code, null, pos);
      });
  }
  
}