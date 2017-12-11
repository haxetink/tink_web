package;

import haxe.ds.Option;
import haxe.io.Bytes;
import tink.core.Either;
import tink.http.Response;
import tink.web.forms.FormFile;
import tink.web.routing.Response;

using tink.io.Source;

typedef Complex = { 
  foo: Array<{ ?x: String, ?y:Int, z:Float }>
}

class Fake {
  
  public function new() {}
  
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
  @:restrict(false, new tink.core.Error(Conflict, 'custom message')) @:get public function customForbid() return 'nope';

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
  
  @:get public function headers(header: { accept:String } ) {
    return header.accept;
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