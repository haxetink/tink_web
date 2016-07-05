package;

import haxe.Constraints.IMap;
import haxe.PosInfos;
import haxe.io.Bytes;
import haxe.unit.TestCase;
import tink.core.Error.ErrorCode;
import tink.http.Header.HeaderField;
import tink.http.Request;
import tink.http.Response.OutgoingResponse;
import tink.io.Source;
import tink.web.Session;
import tink.web.helpers.AuthResult;
import tink.io.IdealSource;

import tink.web.Request;
import tink.web.Response;
import tink.web.Router;
import haxe.ds.Option;

using tink.CoreApi;

class DispatchTest extends TestCase {
  
  static function loggedin(admin:Bool, id:Int = 1):Session<{ admin: Bool, id:Int }>
    return new Session(function () return Future.sync(Success(Some({ admin: admin, id:id }))));
    
  static var anon:Session<{ admin: Bool, id:Int }> = new Session(function () return Future.sync(Success(None)));
  
  static function logginFail():Session<{ admin: Bool, id:Int }>
    return new Session(function () return Future.sync(Failure(new Error('whoops'))));
    
  static var f = new Fake();
  static var r = new Router<{ admin: Bool, id:Int }, Fake>();
  static function check() {
    tink.Web.route((null:IncomingRequest), f, {
      session: loggedin(true)
    });    
  }
  function expect<A>(value:A, req, ?session) {
    
    if (session == null)
      session = loggedin(true);
    
    var succeeded = false;
    
    r.route(session, f, req).handle(function (o) {
      var o = o.sure();
      if (o.header.statusCode != 200)
        fail('Request to ${req.header.uri} failed because ${o.header.reason}');
      else
        o.body.all().handle(function (b) {
          structEq(value, haxe.Json.parse(b.toString()));
          succeeded = true;
        });
    });
    
    assertTrue(succeeded);
  }  
  
  function shouldFail(e:ErrorCode, req, ?session, ?pos) {
    var failed = false;
    
    if (session == null)
      session = loggedin(true);
      
    var res:Future<OutgoingResponse> = r.route(session, f, req).handleError(OutgoingResponse.reportError);
    
    res.handle(function (o) {
      assertEquals(e, o.header.statusCode, pos);  
      failed = true;
    });
    
    assertTrue(failed);
    
  }
  
  function testDispatch() {
      
    expect({ hello: 'world' }, get('/'));
    expect({ hello: 'haxe' }, get('/haxe'));
    expect("yo", get('/yo'));
    expect( { a: 1, b: 2, blargh: 'yo', path: ['sub', '1', '2', 'test', 'yo'] }, get('/sub/1/2/test/yo?c=3&d=4'));
    
    shouldFail(ErrorCode.UnprocessableEntity, get('/sub/1/2/test/yo'));
    var complex: { foo: Array<{ ?x: String, ?y:Int, z:Float }> } = { foo: [ { z: .0 }, { x: 'hey', z: .1 }, { y: 4, z: .2 }, { x: 'yo', y: 5, z: .3 } ] };
    expect(complex, get('/complex?foo[0].z=.0&foo[1].x=hey&foo[1].z=.1&foo[2].y=4&foo[2].z=.2&foo[3].x=yo&foo[3].y=5&foo[3].z=.3'));
    
    shouldFail(ErrorCode.UnprocessableEntity, req('/post', POST, [], 'bar=4'));
    shouldFail(ErrorCode.UnprocessableEntity, req('/post', POST, [new HeaderField('content-type', 'application/x-www-form-urlencoded')], 'bar=bar&foo=hey'));
    shouldFail(ErrorCode.UnprocessableEntity, req('/post', POST, [], 'bar=5&foo=hey'));
    
    expect({ foo: 'hey', bar: 4 }, req('/post', POST, [new HeaderField('content-type', 'application/x-www-form-urlencoded')], 'bar=4&foo=hey'));
    expect({ foo: 'hey', bar: 4 }, req('/post', POST, [new HeaderField('content-type', 'application/json')], haxe.Json.stringify({ foo: 'hey', bar: 4 })));
    
  }
  
  function testAuth() {
    shouldFail(ErrorCode.Unauthorized, get('/'), anon);
    shouldFail(ErrorCode.Unauthorized, get('/haxe'), anon);
    shouldFail(ErrorCode.Forbidden, get('/noaccess'));
    shouldFail(ErrorCode.Forbidden, get('/sub/2/2/whatever'));
  }
  
  function get(url, ?headers)
    return req(url, GET, headers);
  
  function req(url:String, ?method = tink.http.Method.GET, ?headers, ?body:Source) {
    if (headers == null)
      headers = [];
      
    if (body == null)
      body = Empty.instance;
    return new IncomingRequest('1.2.3.4', new IncomingRequestHeader(method, url, '1.1', headers), Plain(body));
  }
  
  //TODO: this is a useless duplication with tink_json tests
  function fail( reason:String, ?c : PosInfos ) : Void {
    currentTest.done = true;
    currentTest.success = false;
    currentTest.error   = reason;
    currentTest.posInfos = c;
    throw currentTest;
  }
  
  function structEq<T>(expected:T, found:T) {
    
    currentTest.done = true;
    
    if (expected == found) return;
    
    var eType = Type.typeof(expected),
        fType = Type.typeof(found);
    if (!eType.equals(fType))    
      fail('$found should be $eType but is $fType');
    
    switch eType {
      case TNull, TInt, TFloat, TBool, TClass(String), TUnknown:
        assertEquals(expected, found);
      case TFunction:
        throw 'not implemented';
      case TObject:
        for (name in Reflect.fields(expected)) {
          structEq(Reflect.field(expected, name), Reflect.field(found, name));
        }
      case TClass(Array):
        var expected:Array<T> = cast expected,
            found:Array<T> = cast found;
            
        if (expected.length != found.length)
          fail('expected $expected but found $found');
        
        for (i in 0...expected.length)
          structEq(expected[i], found[i]);
          
      case TClass(_) if (Std.is(expected, IMap)):
        var expected = cast (expected, IMap<Dynamic, Dynamic>);
        var found = cast (found, IMap<Dynamic, Dynamic>);
        
        for (k in expected.keys()) {
          structEq(expected.get(k), found.get(k));
        }
        
      case TClass(Date):
        
        var expected:Date = cast expected,
            found:Date = cast found;
        
        if (expected.getSeconds() != found.getSeconds() || expected.getMinutes() != found.getMinutes())//python seems to mess up time zones and other stuff too ... -.-
          fail('expected $expected but found $found');    
          
      case TClass(Bytes):
        
        var expected = (cast expected : Bytes).toHex(),
            found = (cast found : Bytes).toHex();
        
        if (expected != found)
          fail('expected $expected but found $found');
            
      case TClass(cl):
        throw 'comparing $cl not implemented';
        
      case TEnum(e):
        
        var expected:EnumValue = cast expected,
            found:EnumValue = cast found;
            
        assertEquals(Type.enumConstructor(expected), Type.enumConstructor(found));
        structEq(Type.enumParameters(expected), Type.enumParameters(found));
    }
  }  
  
}