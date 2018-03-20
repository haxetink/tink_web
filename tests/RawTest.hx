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
  
  public function statusCode() {
    return client.request(new OutgoingRequest(new OutgoingRequestHeader(POST, '/statusCode', []), ''))
      .next(function(res) return assert(res.header.statusCode == 201));
  }
}