package;

import deepequal.DeepEqual.compare;
import tink.http.Request;
import tink.http.Response;
import tink.http.Client;
import tink.http.Container;
import tink.http.clients.*;
import tink.http.containers.*;
import tink.url.Host;
import tink.web.proxy.Remote;
import tink.unit.Assert.assert;

using tink.CoreApi;

@:asserts
class ProxyTest {
  
  var container:LocalContainer;
  var client:Client;
  var fake:Fake;
  var proxy:Remote<Fake>;

  public function new() {
    container = new LocalContainer();
    client = new LocalContainerClient(container);
    fake = new Fake();
    container.run(function (req:IncomingRequest) {
      trace(req.header);
      return DispatchTest.exec(req).recover(OutgoingResponse.reportError);
    });
    proxy = new Remote<Fake>(client, new RemoteEndpoint(new Host('localhost', 80)));
  }
  
  public function complex() {
    var c:Fake.Complex = { foo: [ { z: 3, x: '5', y: 6 } ] };
    return proxy.complex(c).map(function (o) return assert(compare(c, o.sure())));
  }
  
  public function typed() {
    return proxy.typed()
      .next(function (o) {
        asserts.assert(o.header.contentType().sure().fullType == 'application/json');
        asserts.assert(o.body.message == 'This is typed!');
        return asserts.done();
      });
  }
  
  // TODO: failing
  // public function header() {
  //   var accept = 'application/json';
  //   return proxy.headers({accept: accept}).map(function (o) return assert(o.sure() == accept));
  // }
}