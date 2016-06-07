package tink.web;

import haxe.io.Bytes;
import tink.http.Multipart;
import tink.http.StructuredBody;
import tink.http.Request;
import tink.url.Query;
using tink.CoreApi;

class RoutingContext<T> {
  public var fullPath(default, null):tink.url.Path;
  public var query(default, null):Query;
  public var path(default, null):Array<String>;
  public var prefix(default, null):Array<String>;
  public var target(default, null):T;
  public var request(default, null):Request;
  public var bodyParts(default, null):Surprise<StructuredBody, Error>;
  
  public var fallback(default, null):RoutingContext<T>->Response;
  
  public function new(target, request, fallback = null, depth:Int = 0, ?bodyParts) {
    if (fallback == null)
      fallback = notFound;
    
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
    this.path = fullPath.parts();
    this.prefix = this.path.splice(0, depth);
    this.fallback = fallback;
  }
  
  static function notFound<T>(r:RoutingContext<T>):Response 
    return new tink.core.Error(NotFound, 'Not Found');
  
}