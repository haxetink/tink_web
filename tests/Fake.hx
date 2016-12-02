package;

import haxe.io.Bytes;
import tink.web.forms.FormFile;
import tink.web.routing.Response;
//import tink.web.RoutingContext;
//import tink.web.UploadedFile;

class Fake {
  
  public function new() {}
  
  @:restrict(false) @:get public function noaccess() return 'nope';

  @:get public var yo(default, null):String = 'yo';
    
  //@:params(bar in query)
  @:get public function complex(query: { foo: Array<{ ?x: String, ?y:Int, z:Float }> }, ?bar:String) {
    return haxe.Json.stringify(query);
  }
  
  @:post public function buffered(body:Bytes)
    return body;
    
  @:post public function textual(body:String)
    return body;
  
  @:get public function headers(header: { accept:String } ) {
    return header.accept;
  }    
    
  @:html(function (o) return '<p>Hello ${o.hello}</p>')
  @:get('/$who')
  @:get('/')
  public function hello(?who:String = 'world') {
    return {
      hello: who
    };
  }
  
  @:post 
  public function upload(body: { foo:String, theFile: FormFile } ):Response {
    return '';
  }
  
  @:post public function post(body: { foo:String, bar: Int }) {
    return haxe.Json.stringify(body);
  }  
  //@:params(horst in body)
  //@:post public function post(body: { foo:String, bar: Int }, horst:String) {
    //return haxe.Json.stringify(body);
  //}  
  
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