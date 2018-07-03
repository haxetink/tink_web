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
class RawTest {
  
  var container:LocalContainer;
  var client:Client;

  public function new() {
    container = new LocalContainer();
    client = new LocalContainerClient(container);
    container.run(function (req:IncomingRequest) {
      return DispatchTest.exec(req).recover(OutgoingResponse.reportError);
    });
  }
  
  @:variant(POST, 201)
  @:variant(GET, 307)
  public function statusCode(method, code) {
    return client.request(new OutgoingRequest(new OutgoingRequestHeader(method, '/statusCode', []), ''))
      .next(function(res) return assert(res.header.statusCode == code));
  }
}