package tink.web.routing;

import haxe.io.Bytes;
import tink.http.Header;
import tink.http.Multipart;
import tink.http.Request;
import tink.http.StructuredBody;
import tink.io.Source;
import tink.querystring.Pairs;
import tink.streams.Stream;
import tink.url.Portion;
import tink.url.Query;
import tink.web.forms.FormField;

using StringTools;
using tink.CoreApi;

class Context {
  
  var request:IncomingRequest;
  var depth:Int;
  var parts:Array<Portion>;
  var params:Map<String, Portion>;
    
  public var header(get, never):IncomingRequestHeader;
    inline function get_header()
      return request.header;
      
  public var accepts(default, null):String->Bool;
  
      
  public var rawBody(get, never):Source;
    inline function get_rawBody():Source
      return switch this.request.body {
        case Plain(s): s;
        default: new Error(NotImplemented, 'not implemented');//TODO: implement
      }
      
  public function headers():Pairs<tink.http.Header.HeaderValue> {
    return [for (f in header.fields) new Named(toCamelCase(f.name), f.value)];
  }
      
  static function toCamelCase(header:HeaderName) {//TODO: should go some place else
    var header:String = header;
    var ret = new StringBuf(),  
        pos = 0,
        max = header.length;
       
    while (pos < max) {
      switch header.fastCodeAt(pos++) {
        case '-'.code:
          if (pos < max) 
            ret.add(header.charAt(pos++).toLowerCase());
        case v: 
          ret.addChar(v);
      }
    }
      
    return ret.toString();
  }
  
  public function parse():Promise<Array<Named<FormField>>>
    return switch this.request.body {
      case Parsed(parts): parts;
      case Plain(src):
        switch Multipart.check(this.request) {
          case Some(s):
            parseMultipart(s).next(function (a):Array<Named<FormField>> return a);
          case None:
            (src.all() >> function (bytes:Bytes):Array<Named<FormField>> return [for (part in (bytes.toString() : Query)) new Named(part.name, Value(part.value))]);
        }      
    }
      
  public var pathLength(get, never):Int;
    inline function get_pathLength()
      return this.parts.length - this.depth;
  
  public function getPrefix()
    return this.parts.slice(0, this.depth);
    
  public function getPath()
    return this.parts.slice(this.depth);     
  
  public function hasParam(name:String)
    return this.params.exists(name);
  
  public function part(index:Int):Stringly
    return this.parts[this.depth + index];
   
  public function param(name:String):Stringly
    return this.params[name];

  function new(accepts, request, depth, parts, params) {
    this.accepts = accepts;
    this.request = request;
    this.depth = depth;
    this.parts = parts;
    this.params = params;
  }
  
  public function sub(descend:Int):Context
    return new Context(this.accepts, this.request, this.depth + descend, this.parts, this.params);
  
  static public function ofRequest(request:IncomingRequest)
    return new Context(
      parseAcceptHeader(request.header),
      request, 
      0,
      request.header.uri.path.parts(), 
      request.header.uri.query
    );
    
  static public function authed<U, S:Session<U>>(request:IncomingRequest, getSession:IncomingRequestHeader->S) 
    return new AuthedContext<U, S>(
      parseAcceptHeader(request.header),
      request, 
      0,
      request.header.uri.path.parts(), 
      request.header.uri.query,
      getSession.bind(request.header)
    );
   
  static function parseAcceptHeader(h:Header)
    return switch h.get('accept') {
      case []: acceptsAll;
      case values:
        var accepted = [for (v in values) for (part in v.parse()) part.value => true];
        if (accepted['*/*']) acceptsAll;
        else function (t) return accepted.exists(t);
    }
    
  static function acceptsAll(s:String) return true;
  
  static function parseMultipart(s:Stream<MultipartChunk>):Promise<StructuredBody>  //TODO: this is pretty misplaced
    return Future.async(function (cb) {
      var ret:StructuredBody = [];
      
      (s.forEachAsync(function (cur:MultipartChunk) {
        
        var name = null,
            fileName = null,
            mimeType = null;
        
        switch cur.header.byName('content-disposition') {
          case Failure(e):
            cb(Failure(e));
            return Future.sync(false);
          case Success(_.getExtension() => xt):
            
            name = xt['name'];
            fileName = xt['filename'];
            
            if (name == null) {
              cb(Failure(new Error(UnprocessableEntity, 'Missing name for multi part chunk')));
              return Future.sync(false);              
            }
            
            if (fileName != null) 
              switch cur.header.contentType() {
                case Failure(e): 
                  cb(Failure(e));
                  return Future.sync(false);
                case Success(v):
                  mimeType = v.fullType;
              }
            
        }
        
        return cur.body.all().map(function (o) return switch o {
          case Success(bytes):
            ret.push(new Named(
              name, 
              File(tink.web.forms.FormFile.ofBlob(fileName, mimeType, bytes))
            ));
            true;
          case Failure(e):
            false;
        });
      }) >> function (n:Bool) return ret).handle(cb);
    });
  
}

class AuthedContext<U, S:Session<U>> extends Context {
  
  public var session(default, null):Lazy<S>;
  public var user(default, null):Lazy<Promise<Option<U>>>;
  
  public function new(accepts, request, depth, parts, params, session, ?user) {
    
    this.session = session;
    this.user = switch user {
      case null:
        session.map(function (s) return s.getUser());
      case v: v;
    }
    
    super(accepts, request, depth, parts, params);
  }
  
  override public function sub(descend:Int):AuthedContext<U, S>
    return new AuthedContext(accepts, request, depth + descend, parts, params, session, user);
}

abstract RequestReader<A>(Context->Promise<A>) from Context->Promise<A> {
  
  @:from static function ofStringReader<A>(read:String->Outcome<A, Error>):RequestReader<A>
    return 
      function (ctx:Context):Promise<A>
        return 
          ctx.rawBody.all() >> function (body:Bytes) return read(body.toString());
            
  @:from static function ofSafeStringReader<A>(read:String->A):RequestReader<A>
    return ofStringReader(function (s) return Success(read(s)));
    
}