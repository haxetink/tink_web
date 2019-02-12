@:asserts
class TestRpc {
  public function new() {}
  @:variant('/?action=foo&bar=123', '{"bar":123}')
  @:variant('/?action=bar&foo=1', '{"foo":true}')
  @:variant('/baz?action=foo&bar=123', '{"bar":123}')
  @:variant('/baz?action=bar&foo=1', '{"foo":true}')
  @:variant('/baz/tink?action=foo&bar=123', '{"bar":123}')
  @:variant('/baz/tink?action=bar&foo=1', '{"foo":true}')
  public function rpc(url:String, result:String) {
    var r = new tink.web.routing.Router<Rpcesque>(new Rpcesque());
    return check(
      r.route(tink.web.routing.Context.ofRequest(get(url))),
      '$url should return $result', 
      function (s) {
        return s == result;
      }
    );
  }
}

class Rpcesque {
  public function new() {}
  @:get('/?action=foo') public function foo(query:{ bar:Int }) return query;
  @:get('/?action=bar') public function bar(query:{ foo:Bool }) return query;
  @:get('/baz?action=foo') public function bazFoo(query:{ bar:Int }) return query;
  @:get('/baz?action=bar') public function bazBar(query:{ foo:Bool }) return query;
  @:get('/baz/tink?action=foo') public function bazTinkFoo(query:{ bar:Int }) return query;
  @:get('/baz/tink?action=bar') public function bazTinkBar(query:{ foo:Bool }) return query;
}