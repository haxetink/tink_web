package;

import haxe.ds.Option;
import haxe.io.Bytes;
import tink.core.Either;
import tink.http.Response;
import tink.web.forms.FormFile;
import tink.web.routing.Response;
import tink.web.routing.Context;

using tink.io.Source;

typedef Complex = {
  foo: Array<{ ?x: String, ?y:Int, z:Float }>
}


class Fake {

  public function new() {}
  @:sub('/recurse/$id') public function recurse(id:String) return new Fake();

  @:get public function anonOrNot(user:Option<{ id: Int }>)
    return {
      id: switch user {
        case Some(v): v.id;
        case None: -1;
      }
    }

  @:get public function withUser(user: { admin: Bool } )
    return { admin: user.admin };

  @:restrict(false) @:get public function noaccess() return 'nope';

  @:get public var yo(default, null):String = 'yo';

  @:html(function (u) return '<html><body>Yo</body></html>')
  @:params(bar in query)
  @:get public function complex(query: Complex, ?bar:String)
    return query;

  @:delete('/remove/$id') public function delete(id:Int)
    return { deleted: true };

  @:params(bar.foo in query)
  @:get public function temp(bar:{foo:String})
    return bar;

  @:post public function streaming(body:RealSource)
    return body;

  @:post public function buffered(body:Bytes)
    return body;

  @:post public function textual(body:String)
    return body;

  @:get('/queryParam?param=$value')
  public function queryParam(value:String)
    return { value: value };

  @:produces('foo')
  @:post public function streamingFoo(body:RealSource)
    return body;
  @:produces('foo')
  @:post public function bufferedFoo(body:Bytes)
    return body;
  @:produces('foo')
  @:post public function textualFoo(body:String)
    return body;

  @:get public function promiseString():Promise<String>
    return 'foo';

  @:get public function promiseBytes():Promise<Bytes>
    return Bytes.ofString('foo');

  @:statusCode(201)
  @:post public function statusCode()
    return 'Done';

  @:header('tink', 'web')
  @:header('tink_web', 'foobar')
  @:post public function responseHeader()
    return 'Done';

  @:header('tink', 'web')
  @:header('tink_web', 'foobar')
  @:get public function issue114():Noise
    return Noise;

  @:header('tink', 'web')
  @:header('tink_web', 'foobar')
  @:statusCode(418)
  @:get public function issue114_2():Promise<Noise>
    return Promise.NOISE;

  @:params(error in query)
  @:get public function noise(?error:Bool):Promise<Noise>
    return error ? new Error('Errored') : Promise.NOISE;

  @:statusCode(307)
  @:get('/statusCode') public function redirectStatusCode()
    return tink.Url.parse('https://example.com');

  @:get public function headers(header: { var accept:String; @:name('x-bar') var bar:String; } ) {
    return header;
  }

  @:get public function typed() {
    return new tink.web.Response(
      new tink.http.Response.ResponseHeader(200, 'OK', []),
      {message: 'This is typed!'}
    );
  }

  @:consumes('application/json')
  @:post public function enm(body:{ field: Either<String, String> })
    return 'ok';

  @:consumes('application/json')
  @:post public function array(body:Array<Int>)
    return body;

  @:consumes('application/json')
  @:post public function int(body:Int)
    return body;

  @:params(v in query)
  @:get public function enumAbstractStringInQuery(v:EStr):EStr
    return v;

  @:params(v in query)
  @:get public function enumAbstractIntInQuery(v:EInt):EInt
    return v;

  @:params(notfoo = query['foo'])
  @:params(bar.baz = query['baz'])
  @:get public function alias(notfoo:String, bar:{baz:String}, ctx:Context):{foo:String, baz:String, query:String}  {
    return {
      foo: notfoo,
      baz: bar.baz,
      query: @:privateAccess ctx.request.header.url.query,
    }
  }

  @:params(obj.foo = query['foo'])
  @:params(obj.bar = header['x-bar'])
  @:params(obj.baz = body['baz'])
  @:get public function merged(obj:{foo:String, bar:String,baz:String}):{foo:String, bar:String, baz:String} {
    return obj;
  }

  @:get('enum_abs_str/$v') public function enumAbstractStringInPath(v:EStr):EStr
    return v;

  @:get('enum_abs_int/$v') public function enumAbstractIntInPath(v:EInt):EInt
    return v;

  @:get('/flag/$flag')
  @:get('/flag/')
  public function flag(?flag:Bool = true)
    return { flag: flag };

  @:get('/count/$number')
  @:get('/count/')
  public function count(?number:Int = 123)
    return { number: number };

  @:restrict(true)
  @:html(function (o) return '<p>Hello ${o.hello}</p>')
  @:get('/$who')
  @:get('/')
  public function hello(?who:String = 'world') {
    return {
      hello: who
    };
  }

  @:post
  public function upload(body: { datafile1: FormFile } ) {
    return body.datafile1.read().all()
      .next(function (chunk) return {
        name: body.datafile1.fileName,
        content: chunk.toString(),
      });
  }

  @:post public function post(body: { foo:String, bar: Int })
    return body;

  @:post public function optional(body: { foo:String, ?bar: Int })
    return {bar:body.bar};

  

  @:post public function nullableQuery1(?query: { foo:String })
    return {foo: query == null ? null : query.foo};
  
  @:params(nullableValue = query)
  @:post public function nullableQuery2(?nullableValue: { foo:String })
    return {foo: nullableValue == null ? null : nullableValue.foo};
  
  @:restrict(user.id == a)
  @:sub('/sub/$a/$b')
  public function sub(a, b) {
    return new FakeSub(a, b);
  }

}

@:restrict(this.b > user.id)
class FakeSub {

  var a:Int;
  var b:Float;

  public function new(a, b) {
    this.a = a;
    this.b = b;
  }

  @:restrict(user.admin)
  @:get('/test/$blargh')
  public function foo(blargh:String, /*path:Array<String>,*/ query: { c:String, d:String } ) {
    return haxe.Json.stringify({
      a: a,
      b: b,
      c: query.c,
      d: query.d,
      blargh: blargh,
      //path: path,
    });
  }

  @:get public function whatever()
    return { foo: 'bar' }

}

@:enum
abstract EStr(String) {
  var A = 'a';
  var B = 'b';

  @:to
  public inline function toStringly():tink.Stringly return this;
}

@:enum
abstract EInt(Int) {
  var A = 1;
  var B = 2;

  @:to
  public inline function toStringly():tink.Stringly return this;
}
