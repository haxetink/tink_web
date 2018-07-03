class Helpers {
  static public function get(url, ?headers)
    return req(url, GET, headers);
  
  static public function req(url:String, ?method = tink.http.Method.GET, ?headers, ?body:IdealSource) {
    if (headers == null)
      headers = [new HeaderField('accept', 'application/json')];
      
    if (body == null)
      body = Source.EMPTY;
    return new IncomingRequest('1.2.3.4', new IncomingRequestHeader(method, url, '1.1', headers), Plain(body));
  }  

  static public function check(p:Promise<OutgoingResponse>, message:String, test:String->Bool) {
    return p.next(function (o) return switch o.header.statusCode {
      case 200:
        o.body.all().next(function (b) return switch test.bind(b.toString()).catchExceptions() {
          case Failure(e): e;
          case Success(passed): new Assertion(passed, message);
        });
      case v: new Assertion(false, 'Request failed because ${o.header.reason} (${o.header.statusCode.toInt()})');
    });
  }
  
}