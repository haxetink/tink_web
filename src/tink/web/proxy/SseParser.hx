package tink.web.proxy;

import tink.streams.RealStream;
import tink.io.Source;
import tink.http.Sse;

using tink.CoreApi;

class SseParser {
  static public function parse<T>(body:RealSource, parser:String->Outcome<T, Error>):RealStream<T> {
    return SseStream.decode(body).map((e:Sse) -> Promise.lift(switch e.event {
      case 'error': new Error(e.data);
      default: parser(e.data);
    }));
  }
}