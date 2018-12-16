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

  public function responseHeader() {
    return client.request(new OutgoingRequest(new OutgoingRequestHeader(POST, '/responseHeader', []), ''))
      .next(function(res) {
        asserts.assert(res.header.byName('tink').match(Success('web')));
        asserts.assert(res.header.byName('tink_web').match(Success('foobar')));
        return asserts.done();
      });
  }
  
  public function noise() {
    return client.request(new OutgoingRequest(new OutgoingRequestHeader(GET, '/noise', []), ''))
      .next(function(res) {
        asserts.assert(res.header.statusCode == 200);
        return res.body.all();
      })
      .next(function(chunk) {
        asserts.assert(chunk.length == 0);
        return asserts.done();
      });
    return asserts;
  }
  
  public function noiseWithError() {
    return client.request(new OutgoingRequest(new OutgoingRequestHeader(GET, '/noise?error=true', []), ''))
      .next(function(res) {
        asserts.assert(res.header.statusCode == 500);
        return res.body.all();
      })
      .next(function(chunk) {
        asserts.assert(chunk.length > 0);
        return asserts.done();
      });
    return asserts;
  }
}