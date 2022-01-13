import tink.web.proxy.Remote;

@:asserts
class RemoteEndpoints {
  public function new() {}

  public function test() {
    function mk(v:Array<RemoteEndpoint>)
      return v;

    var example = ['example'][Std.random(0)];

    for (r in mk([
      'http://example.com/foo/bar%20bar?gl%26rgh=123%65',
      'http://$example.com/foo/bar%20bar?gl%26rgh=123%65',
      RemoteEndpoint.ofString('http://$example.com/foo/bar%20bar?gl%26rgh=123%65'),
    ])) {

      asserts.assert(Lambda.count(r.headers) == 0);
      switch Lambda.array(r.path) {
        case [foo, barbar]:
          asserts.assert(foo.raw == 'foo');
          asserts.assert(barbar.raw == 'bar%20bar');
          asserts.assert((barbar:String) == 'bar bar');
        case a: asserts.assert(a.length == 2);
      }

      switch Lambda.array(r.query) {
        case [{ name: n, value: v}]:
          asserts.assert(n.raw == 'gl%26rgh');
          asserts.assert((n:String) == 'gl&rgh');
          asserts.assert(v.raw == '123%65');
          asserts.assert((v:String) == '123e');
        case a: asserts.assert(a.length == 1);
      }

    }

    for (r in mk([
      'http://spaceballs:12345@example.com/foo/bar?glargh',
      'http://spaceballs:12345@$example.com/foo/bar?glargh',
      RemoteEndpoint.ofString('http://spaceballs:12345@$example.com/foo/bar?glargh'),
    ])) {
      asserts.assert(r.host == 'example.com');

      switch Lambda.array(r.headers) {
        case [h]:
          asserts.assert(h.name == AUTHORIZATION);
          asserts.assert(h.value == tink.http.Header.HeaderValue.basicAuth('spaceballs', '12345'));
        case a: asserts.assert(a.length == 1);
      }
    }

    for (r in mk([
      'http://spaceballs:12345@example.com/foo/bar?glargh=123#.json',
      'http://spaceballs:12345@$example.com/foo/bar?glargh=123#.json',
      RemoteEndpoint.ofString('http://spaceballs:12345@$example.com/foo/bar?glargh=${123}#.json'),
    ])) {
      asserts.assert(r.pathSuffix == '.json');
    }

    return asserts.done();
  }

  // got error: tests/RemoteEndpoints.hx:67: characters 29-35 : tink.web.proxy.RemoteEndpoint has no field scheme
  public function issue123() @:privateAccess {
    final endpoint:Dynamic = new RemoteEndpoint(new tink.url.Host("127.0.0.1", 8081));
    
    asserts.assert(endpoint.scheme == null);
    return asserts.done();
  }
}