package;

import tink.web.RoutingContext;

class Fake {
  
  public function new() {}
  
  //@:get public var yo(default, null):String = '"yo"';
  //
  //@:get public function complex(query: { foo: Array<{ ?x: String, ?y:Int, z:Float }> } ) {
    //return haxe.Json.stringify(query);
  //}
  //
  //@:get('/')
  //@:get('/$who')
  //public function hello(who:String = 'world') {
        //
    //return haxe.Json.stringify({
      //hello: who
    //});
  //}
  //
  //@:post public function post(body:{ foo:String, bar: Int }) {
    //return haxe.Json.stringify(body);
  //}
  //
  //@:sub('/sub/$a/$b')
  //public function sub(a, b, path:String) {
    //return new FakeSub(a, b);
  //}  
}

class FakeSub {
  
  var a:Int;
  var b:Float;
  
  public function new(a, b) {
    this.a = a;
    this.b = b;
  }
  
  @:get('/test/$blargh') public function foo(blargh:String, path:Array<String>, query:{ c:String, d:String }) {
    
    return haxe.Json.stringify({ 
      a: a,
      b: b,
      c: query.c,
      d: query.d,
      blargh: blargh,
      path: path,
    });
  }
}