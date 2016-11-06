package;

import tink.web.Response;
//import tink.web.RoutingContext;
//import tink.web.UploadedFile;

@:restrict(true)
class Fake {
  
  public function new() {}
  
  @:restrict(false) @:get public function noaccess() return 'nope';

  //@:get public var yo(default, null):String = '"yo"';
  
  //@:get public function complex(query: { foo: Array<{ ?x: String, ?y:Int, z:Float }> } ) {
    //return haxe.Json.stringify(query);
  //}
  
  @:get('/$who')
  public function hello(?who:String = 'world') {        
    return haxe.Json.stringify({
      hello: who
    });
  }
  
  //@:post public function upload(body: { foo:String, theFile: UploadedFile } ):Response {
    //return '';
  //}
  
  @:params(horst in body)
  @:post public function post(body: { foo:String, bar: Int }, horst:String) {
    return haxe.Json.stringify(body);
  }  
  
  //@:restrict(user.id == a)  
  @:sub('/sub/$a/$b')
  //public function sub(a, b, path:String) {
  public function sub(a, b) {
    return new FakeSub(a, b);
  }  
}

@:restrict(@:privateAccess this.target.b > user.id)
class FakeSub {
  
  var a:Int;
  var b:Float;
  
  public function new(a, b) {
    this.a = a;
    this.b = b;
  }
  
  //@:restrict(user.admin)
  //@:get('/test/$blargh') 
  //public function foo(blargh:String, path:Array<String>, query: { c:String, d:String } ) {  
    //return haxe.Json.stringify({ 
      //a: a,
      //b: b,
      //c: query.c,
      //d: query.d,
      //blargh: blargh,
      //path: path,
    //});
  //}
  //
  @:get public function whatever() 
    return 'whatever';
    
}