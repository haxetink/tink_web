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
    
  @:params(bar in query)
  @:get public function complex(query: Complex, ?bar:String) 
    return query;
  
  // @:post public function streaming(body:RealSource)
  //   return body.all();
    
  @:post public function buffered(body:Bytes)
    return body;
    
  @:post public function textual(body:String)
    return body;
    
  @:statusCode(201)
  @:post public function statusCode()
    return 'Done';
    
  @:header('tink', 'web')
  @:header('tink_web', 'foobar')
  @:post public function responseHeader()
    return 'Done';
    
  @:params(error in query)
  @:get public function noise(?error:Bool):Promise<Noise>
    return error ? new Error('Errored') : Promise.NOISE;
    
  @:statusCode(307)
  @:get('/statusCode') public function redirectStatusCode()
    return tink.Url.parse('https://example.com');
  
  @:get public function headers(header: { accept:String } ) {
    return {header: header.accept};
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
  
  @:params(v in query)
  @:get public function enumAbstractStringInQuery(v:EStr):EStr
    return v;
  
  @:params(v in query)
  @:get public function enumAbstractIntInQuery(v:EInt):EInt
    return v;
  
  // @:params(v = query['foo'])
  // @:get public function paramKey(v:String, ctx:Context):{parsed:String, raw:String}  {
  //   return {
  //     parsed: v,
  //     raw: @:privateAccess ctx.request.header.url.query,
  //   }
  // }
  
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