import tink.http.Client;
import tink.web.proxy.Remote;

@:asserts
class FacadeTest {
  public function new() {

  }

  public function connect() {
    var p1 = tink.Web.connect(('http://example.com/':Fake)),
        p2 = tink.Web.connect(new Fake('http://example.com/')),
        p3 = new Remote<Fake>(null, RemoteEndpoint.ofString('http://example.com/'));

    asserts.assert(Type.getClass(p1) == Type.getClass(p2));
    asserts.assert(Type.getClass(p1) == Type.getClass(p3));

    function getEndpoint(r:RemoteBase<Fake>)
      return Std.string(@:privateAccess r.endpoint);

    asserts.assert(getEndpoint(p1) == getEndpoint(p2));
    asserts.assert(getEndpoint(p1) == getEndpoint(p3));

    var full = tink.Web.connect(('http://007:moneypenny@example.com/':Fake), {
      client: new FakeClient(),
      headers: [
        new HeaderField('x-foo', 'bar'),
      ],
      augment: {
        before: [out -> new OutgoingRequest(out.header.concat([new HeaderField('x-bar', 'foo')]), out.body)],
      }
    });

    full.count(123).handle(function (o) {
      asserts.assert(o.match(Failure({ message: 'fake' })));
      switch FakeClient.log {
        case [{ header: h }]:
          asserts.assert(h.byName('x-foo').match(Success('bar')));
          asserts.assert(h.byName('x-bar').match(Success('foo')));
          asserts.assert(h.byName(CONTENT_LENGTH).match(Success('0')));
          asserts.assert(h.byName(ACCEPT).match(Success('application/json')));
          asserts.assert(h.byName(AUTHORIZATION).match(Success(_)));

        case a: asserts.assert(a.length == 1);
      }
    });

    return asserts.done();
  }
}

private class FakeClient implements ClientObject {
  public function new() {}
  static public var log:Array<OutgoingRequest> = [];
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    log.push(req);
    return new Error('fake');
  }
}