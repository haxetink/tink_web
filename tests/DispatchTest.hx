package;

import haxe.Constraints.IMap;
import haxe.PosInfos;
import haxe.io.Bytes;
import haxe.unit.TestCase;
import tink.http.Request;
import tink.http.Response.OutgoingResponse;

import tink.io.IdealSource;

import tink.web.Request;
import tink.web.Response;
import tink.web.Router;
using tink.CoreApi;

class DispatchTest extends TestCase {
  
  static var f = new Fake();
  static var r = new Router<Fake>();
  
  function expect<A>(value:A, req) {
    
    var succeeded = false;
    
    var res:Future<OutgoingResponse> = r.route(f, req);
    
    res.handle(function (o) {
      o.body.all().handle(function (b) {
        structEq(value, haxe.Json.parse(b.sure().toString()));
        succeeded = true;
      });
    });
    
    assertTrue(succeeded);
  }  
  function testDispatch() {
      
    expect({ hello: 'world' }, get('/'));
    expect({ hello: 'haxe' }, get('/haxe'));
    expect("yo", get('/yo'));
    expect({ a: 1, b: 2, blargh: 'yo', path: ['sub', '1', '2', 'test', 'yo'] }, get('/sub/1/2/test/yo'));
  }
  
  function get(url, ?headers)
    return req(url, GET, headers);
  
  function req(url:String, ?method = tink.http.Method.GET, ?headers, ?body) {
    if (headers == null)
      headers = [];
      
    if (body == null)
      body = Empty.instance;
    return new IncomingRequest('1.2.3.4', new IncomingRequestHeader(method, url, '1.1', headers), body);
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
    
    var eType = Type.typeof(expected),
        fType = Type.typeof(found);
    if (!eType.equals(fType))    
      fail('$found should be $eType but is $fType');
    
    assertTrue(true);
    
    switch eType {
      case TNull, TInt, TFloat, TBool, TClass(String):
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
      case TUnknown:
        throw 'not implemented';
    }
  }  
  
}