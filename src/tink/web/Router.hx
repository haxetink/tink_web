package tink.web;

import tink.url.Query;

@:genericBuild(tink.web.macros.Routing.buildRouter())
class Router<T> {
}

class RoutingContext<T> {
  var __parts:Array<String>;
  var query:Query;
  var prefix:Array<String>;
  var __target:T;
  var request:Request;
  
  public function new(target, request, depth:Int = 0) {
    this.__target = target;
    this.request = request;
    this.query = request.header.uri.query;
    this.__parts = request.header.uri.path.parts();
    this.prefix = this.__parts.splice(0, depth);
  }  
}