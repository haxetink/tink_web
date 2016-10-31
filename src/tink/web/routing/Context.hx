package tink.web.routing;

import tink.http.Request;
import tink.url.Portion;

private typedef ContextData = { 
  var request:IncomingRequest;
  var depth:Int;
  var parts:Array<Portion>;
  var params:Map<String, Portion>;
}

abstract Context(ContextData) {
  
  public var header(get, never):IncomingRequestHeader;
    inline function get_header()
      return this.request.header;
      
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

  inline function new(request, depth, parts, params) 
    this = {
      request: request,
      depth: depth,
      parts: parts, 
      params: params,
    }
  
  public function sub(descend:Int)
    return new Context(this.request, this.depth + descend, this.parts, this.params);
  
  @:from static function ofRequest(request:IncomingRequest)
    return new Context(request, 0, request.header.uri.path.parts(), request.header.uri.query);
}