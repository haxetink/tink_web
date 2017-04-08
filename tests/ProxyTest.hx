package;

import deepequal.DeepEqual;
import haxe.unit.TestCase;
import tink.http.Response.OutgoingResponse;
import tink.http.clients.*;
import tink.http.containers.LocalContainer;
import tink.url.Host;
import tink.web.proxy.Remote;

using tink.CoreApi;

class ProxyTest extends TestCase {

  function testProxy() {
    var c = new LocalContainer();
    var client = new LocalContainerClient(c);
    var f = new Fake();
    
    c.run(function (req) {
      return DispatchTest.exec(req).recover(OutgoingResponse.reportError);
    });
    
    var p = new tink.web.proxy.Remote<Fake>(client, new RemoteEndpoint(new Host('localhost', 80)));
    var c:Fake.Complex = { foo: [ { z: 3, x: '5', y: 6 } ] };
    p.complex(c).handle(function (o) assertEquals(Noise, DeepEqual.compare(c, o.sure()).sure()));
  }
}