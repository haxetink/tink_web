package tink.web;

import tink.url.Query;

@:genericBuild(tink.web.macros.Routing.buildRouter())
class Router<T> {
}

class RoutingContext<T> {
  public var path(default, null):Array<String>;
  public var query(default, null):Query;
  public var prefix(default, null):Array<String>;
  public var target(default, null):T;
  public var request(default, null):Request;
  
  var fallback:RoutingContext<T>->Response;
  
  public function new(target, request, fallback, depth:Int = 0) {
    this.target = target;
    this.request = request;
    this.query = request.header.uri.query;
    this.path = request.header.uri.path.parts();
    this.prefix = this.path.splice(0, depth);
    this.fallback = fallback;
  }  
}