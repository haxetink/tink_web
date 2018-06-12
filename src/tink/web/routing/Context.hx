package tink.web.routing;

import haxe.io.Bytes;
import tink.Chunk;
import tink.http.Header;
import tink.http.Request;
import tink.http.StructuredBody;
import tink.querystring.Pairs;
import tink.streams.Stream;
import tink.url.Portion;
import tink.url.Query;
import tink.web.forms.FormField;

using tink.io.Source;
using StringTools;
using tink.CoreApi;

abstract Path(Array<Portion>) from Array<Portion> to Array<Portion> {
  @:to public function toString():String
    return '/'+[for (p in this) (p:String)].join('/');
}

class Context {
  
  var request:IncomingRequest;
  
  public var depth(default, null):Int;
  public var parent(default, null):Context;

  var parts:Array<Portion>;
  var params:Map<String, Portion>;
    
  public var header(get, never):IncomingRequestHeader;
    inline function get_header()
      return request.header;
      
  public var accepts(default, null):String->Bool;
  
  
  public function allRaw():Promise<Chunk>
    return rawBody.all();
    
  public var rawBody(get, never):RealSource;
    inline function get_rawBody():RealSource
      return switch this.request.body {
        case Plain(s): s;
        default: new Error(NotImplemented, 'not implemented');//TODO: implement
      }
      
  public function headers():Pairs<tink.http.Header.HeaderValue> {
    return [for (f in header) new Named(toCamelCase(f.name), f.value)];
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
        function parseForm()
          return 
            src.all().next(
              function (chunk):Array<Named<FormField>> return [for (part in (chunk.toString() : Query)) new Named(part.name, Value(part.value))]);
        #if tink_multipart
        switch tink.multipart.Multipart.check(this.request) {
          case Some(result):
            return Future.async(function(cb:Callback<Outcome<Array<Named<FormField>>, Error>>) {
              var contentType = result.a;
              var body = result.b.idealize(function(e) {
                cb.invoke(Failure(e));
                return Source.EMPTY;
              });
              var parser:tink.multipart.Parser = // TODO: make this configurable
                #if busboy
                  new tink.multipart.parsers.BusboyParser(contentType.toString());
                #else
                  new tink.multipart.parsers.TinkParser(contentType.extensions['boundary']);
                #end
              parser.parse(body).collect().handle(cb);
            });
          case None:
            parseForm();
        }    
        #else
          parseForm();
        #end  
    }
      
  public var pathLength(get, never):Int;
    inline function get_pathLength()
      return this.parts.length - this.depth;
  
  public function getPrefix():Path
    return this.parts.slice(0, this.depth);
    
  public function getPath():Path
    return this.parts.slice(this.depth);     
  
  public function hasParam(name:String)
    return this.params.exists(name);
  
  public function part(index:Int):Stringly
    return if(this.depth + index >= this.parts.length) '' else this.parts[this.depth + index];
   
  public function param(name:String):Stringly
    return this.params[name];

  function new(parent, accepts, request, depth, parts, params) {
    this.parent = parent;
    this.accepts = accepts;
    this.request = request;
    this.depth = depth;
    this.parts = parts;
    this.params = params;
  }
  
  public function sub(descend:Int):Context 
    return new Context(this, this.accepts, this.request, this.depth + descend, this.parts, this.params);
  
  static public function ofRequest(request:IncomingRequest)
    return new Context(
      null,
      parseAcceptHeader(request.header),
      request, 
      0,
      request.header.url.path.parts(), 
      request.header.url.query
    );
    
  static public function authed<U, S:Session<U>>(request:IncomingRequest, getSession:IncomingRequestHeader->S) 
    return new AuthedContext<U, S>(
      null,
      parseAcceptHeader(request.header),
      request, 
      0,
      request.header.url.path.parts(), 
      request.header.url.query,
      getSession.bind(request.header)
    );
   
  static function parseAcceptHeader(h:Header)
    return switch h.get(ACCEPT) {
      case []: acceptsAll;
      case values:
        var accepted = [for (v in values) for (part in v.parse()) part.value => true];
        if (accepted['*/*']) acceptsAll;
        else function (t) return accepted.exists(t);
    }
    
  static function acceptsAll(s:String) return true;
  
}

@:allow(tink.web.routing)
class AuthedContext<U, S:Session<U>> extends Context {
  
  public var session(default, null):Lazy<S>;
  public var user(default, null):Lazy<Promise<Option<U>>>;
  
  function new(parent, accepts, request, depth, parts, params, session, ?user) {
    
    this.session = session;
    this.user = switch user {
      case null:
        session.map(function (s) return s.getUser());
      case v: v;
    }
    
    super(parent, accepts, request, depth, parts, params);
  }
  
  override public function sub(descend:Int):AuthedContext<U, S> {
    return new AuthedContext(this, accepts, request, depth + descend, parts, params, session, user);
  }
}

abstract RequestReader<A>(Context->Promise<A>) from Context->Promise<A> {
  
  @:from static function ofStringReader<A>(read:String->Outcome<A, Error>):RequestReader<A>
    return 
      function (ctx:Context):Promise<A>
        return 
          ctx.allRaw().next(function (body) return read(body.toString()));
            
  @:from static function ofSafeStringReader<A>(read:String->A):RequestReader<A>
    return ofStringReader(function (s) return Success(read(s)));
    
}
