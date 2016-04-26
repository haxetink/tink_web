package;

import tink.web.RoutingContext;

class Fake {
  
  public function new() {}
  
  @:get public var yo(default, null):String = '"yo"';
  
  @:get('/')
  @:get('/$who')
  public function hello(who:String = 'world') {
        
    return haxe.Json.stringify({
      hello: who
    });
  }
  
  @:sub('/sub/$a/$b')
  public function sub(a, b, path:String) {
    return new FakeSub(a, b);
  }
  
}

class FakeSub {
  
  var a:Int;
  var b:Float;
  
  public function new(a, b) {
    this.a = a;
    this.b = b;
  }
  
  @:get('/test/$blargh') public function foo(blargh:String, path:Array<String>) {
    
    return haxe.Json.stringify({ 
      a: a,
      b: b,
      blargh: blargh,
      path: path,
    });
  }
}