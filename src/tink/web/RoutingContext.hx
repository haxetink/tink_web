package tink.web;

import haxe.io.Bytes;
import tink.Stringly;
import tink.http.Multipart;
import tink.http.StructuredBody;
import tink.http.Request;
import tink.url.Query;
using tink.CoreApi;

class RoutingContext<User, Target> {
  public var fullPath(default, null):tink.url.Path;
  public var query(default, null):Query;
  public var path(default, null):Array<Stringly>;
  public var prefix(default, null):Array<Stringly>;
  public var target(default, null):Target;
  public var request(default, null):Request;
  public var bodyParts(default, null):Surprise<StructuredBody, Error>;
  public var session(default, null):Session<User>;
  public var fallback(default, null):RoutingContext<User, Target>->Response;
  
  public function new(session:Session<User>, target, request, fallback = null, depth:Int = 0, ?bodyParts) {
    if (fallback == null)
      fallback = notFound;
    
    this.session = session;
    this.target = target;
    this.request = request;
    
    this.bodyParts = switch bodyParts {
      case null: 
        Future.async(function (cb) {
          switch request.body {
            case Parsed(parts): cb(Success(parts));
            case Plain(src):
              switch Multipart.check(request) {
                case Some(s):
                  cb(Failure(new Error('multipart currently not supported on this server platform')));
                case None:
                  (src.all() >> function (bytes:Bytes):StructuredBody return [for (part in (bytes.toString() : Query)) new Named(part.name, Value(part.value))]).handle(cb);
              }
          }
        }, true);
      case v: v;
    }
    
    this.query = request.header.uri.query;
    this.fullPath = request.header.uri.path;
    this.path = cast fullPath.parts();
    this.prefix = this.path.splice(0, depth);
    this.fallback = fallback;
  }
  
  static function notFound<User, Target>(r:RoutingContext<User, Target>):Response 
    return new tink.core.Error(NotFound, 'Not Found: [${r.request.header.method}] ${r.request.header.uri}');
  
}
