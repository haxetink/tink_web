package tink.web.proxy;

import haxe.io.Bytes;
import tink.url.*;
import tink.querystring.*;
import tink.http.*;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;

using tink.io.Source;
using tink.CoreApi;

@:genericBuild(tink.web.macros.Proxify.remote())
class Remote<T> { }

private typedef RemoteEndpointData = {
  >Sub,
  host:Host, 
}

private typedef Sub = {
  ?headers: Headers, 
  ?path: PathFragments, 
  ?query: QueryParams,
}

abstract RemoteEndpoint(RemoteEndpointData) from RemoteEndpointData {
  
  public function new(host) {
    this = { host: host };
  }
  
  static function concat<E>(a:Array<E>, b:Array<E>) 
    return switch [a, b] {
      case [null, r] | [r, null]: r;
      default: a.concat(b);
    }
  
  public function sub(options:Sub):RemoteEndpoint
    return {
      host: this.host,
      headers: concat(this.headers, options.headers),
      query: concat(this.query, options.query),
      path: concat(this.path, options.path),
    }
    
  function uri()       
    return '/' + (switch this.path {
      case null: '';
      case v: Path.normalize(v.join('/'));
    }) + this.query;
  
  public function request<A>(client:Client, method, body, reader:ResponseReader<A>):Promise<A>
    return 
      client.request(
        new OutgoingRequest(
          new OutgoingRequestHeader(method, '//' + this.host + uri(), this.headers),//TODO: consider putting protocol here
          body
        )
      ).next(function (response) return reader.withHeader(response.header)(response.body));
      
  @:from public static inline function fromHost(host:Host):RemoteEndpoint
    return new RemoteEndpoint(host);
}

abstract ResponseReader<A>(ResponseHeader->RealSource->Promise<A>) from ResponseHeader->RealSource->Promise<A> {
  
  public function withHeader(header)
    return this.bind(header, _);
        
  @:from static function ofStringReader<A>(read:String->Outcome<A, Error>):ResponseReader<A>
    return 
      function (header:ResponseHeader, body:RealSource):Promise<A>
        return 
          body.all().next(function (chunk:Chunk) return
            if (header.statusCode >= 400)
              Failure(Error.withData(header.statusCode, header.reason, chunk.toString()));
            else
              read(chunk.toString())
          );
            
  @:from static function ofSafeStringReader<A>(read:String->A):ResponseReader<A>
    return ofStringReader(function (s) return Success(read(s)));
            
}

private typedef Headers = Array<HeaderField>;
private typedef PathFragments = Array<Portion>;

@:forward
abstract QueryParams(Array<NamedWith<Portion, Portion>>) to Array<NamedWith<Portion, Portion>> from Array<NamedWith<Portion, Portion>> {
  
  public inline function new() 
    this = [];
    
  public inline function add(name:Stringly, value:Stringly):QueryParams {
    this.push(new NamedWith((name:Portion), (value:Portion)));
    return this;
  }
    
  @:to public inline function flush():QueryParams
    return this;
    
  @:to public function toString() 
    return switch this {
      case null | []: '';
      default:
        var ret = Query.build();
        for (p in this)
          ret.add(p.name, p.value);
        '?$ret';
    }
}

@:forward
abstract HeaderParams(Headers) to Headers from Headers {
  
  public inline function new() 
    this = [];
    
  public inline function add(name:HeaderName, value:HeaderValue):HeaderParams {
    this.push(new HeaderField(name, value));
    return this;
  }
    
  @:to public inline function flush():HeaderParams
    return this;
    
  @:to public function toString() 
    return new Header(this).toString();
}

class RemoteBase<T> {
  
  var client:tink.http.Client;
  var endpoint:RemoteEndpoint;
  
  public function new(client, endpoint) {
    this.client = client;
    this.endpoint = endpoint;
  }

}