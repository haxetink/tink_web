package;

import deepequal.DeepEqual.compare;
import tink.http.Response.OutgoingResponse;
import tink.http.clients.*;
import tink.http.containers.LocalContainer;
import tink.url.Host;
import tink.web.proxy.Remote;
import tink.unit.Assert.assert;

using tink.CoreApi;

class ProxyTest {

  public function new() {}
  
  public function proxy() {
    // var c = new LocalContainer();
    // var client = new LocalContainerClient(c);
    // var f = new Fake();
    
    // c.run(function (req) {
    //   return DispatchTest.exec(req).recover(OutgoingResponse.reportError);
    // });
    
    // var p = new tink.web.proxy.Remote<Fake>(client, new RemoteEndpoint(new Host('localhost', 80)));
    // var c:Fake.Complex = { foo: [ { z: 3, x: '5', y: 6 } ] };
    // return p.complex(c).map(function (o) return assert(compare(c, o.sure())));
    return assert(false, 'TODO');
  }
}