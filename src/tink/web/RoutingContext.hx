package tink.web;

import haxe.io.Bytes;
import tink.http.Multipart;
import tink.http.StructuredBody;
import tink.http.Request;
import tink.url.Query;
using tink.CoreApi;
using StringTools;

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
                  var parts = [];
                  var err = null;
                  s.forEachAsync(function(chunk) {
                    inline function escapeQuotes(v:String) return v.startsWith('"') && v.endsWith('"') ? v.substring(1, v.length - 1) : v;
                    switch chunk.header.byName('content-disposition') {
                      case Success(_.parse() => parsed):
                        var ext = parsed[0].extensions;
                        var name = ext['name'];
                        var filename = ext['filename'];
                        return chunk.body.all().map(function(o) switch o {
                          case Success(bytes):
                            switch chunk.header.byName('content-type') {
                              case Success(mime): parts.push(new NamedWith(name, File(new TempFile(filename, mime, bytes.length, bytes))));
                              case Failure(_): parts.push(new NamedWith(name, Value(bytes.toString())));
                            }
                            return true;
                          case Failure(e): 
                            err = e;
                            return false;
                        });
                      case Failure(e):
                        err = e;
                        return Future.sync(false);
                    }
                  }).handle(function(o) switch o {
                    case Success(true): cb(Success(parts));
                    case Success(false): cb(Failure(err));
                    case Failure(e): cb(Failure(e));
                  });
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

class TempFile {
  public var fileName(default, null):String;
  public var mimeType(default, null):String;
  public var size(default, null):Int;
  var bytes:Bytes;
  
  public function new(fileName, mimeType, size, bytes) {
    this.fileName = fileName;
    this.mimeType = mimeType;
    this.size = size;
    this.bytes = bytes;
  }
  
  public function read():tink.io.Source
    return bytes;
  public function saveTo(path:String):Surprise<Noise, Error>
    return Future.sync(Failure(new Error('not implemented')));
}