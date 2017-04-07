package tink.web.macros;

import tink.http.Method;
import haxe.ds.Option;
import haxe.macro.Type;
import haxe.macro.Expr;
import tink.url.Portion;
using tink.CoreApi;

typedef Route = {
  public var field(default, null):ClassField;
  public var kind(default, null):RouteKind;
  public var signature(default, null):RouteSignature;
  public var consumes(default, null):Array<MimeType>;
  public var produces(default, null):Array<MimeType>;
}

typedef RouteSignature = Array<RouteArg>;

typedef RouteArg = {
  var name(default, null):String;
  var type(default, null):Type;
  var optional(default, null):Bool;
  var kind(default, null):RouteArgKind;
}

enum ParamLocation {
  PQuery;
  PBody;
  PHeader;
}

enum ParamKind {
  PSeparate;
  PCompound;
}

enum RouteArgKind {
  
  AContext;
  ACapture;//note that this may come from path *or* query string
  
  AParam(type:Type, loc:ParamLocation, kind:ParamKind);
  
  AUser(type:Type);
  
  ASession(type:Type);
}

enum RouteKind {
  KSub(s:SubRoute);
  KCall(c:Call);
}

typedef SubRoute = {
  var variants(default, null):Array<Variant>;
  var target(default, null):Type;
}

typedef Variant = { 
  var path(default, null):RoutePath;
}

typedef Call = {
  var variants(default, null):Array<CallVariant>;
  var response(default, null):RouteResponse;
}

typedef CallVariant = {>Variant,
  var method(default, null):Option<Method>;
}

enum RouteResponse {
  RData(type:Type);
  ROpaque(type:Type);
}

typedef RoutePath = {
  var pos(default, null):Position;
  var parts(default, null):Array<RoutePathPart>;
  var query(default, null):Map<String, RoutePathPart>;
  var rest(default, null):RoutePathRest;
  var deviation:{
    var surplus(default, null):Array<String>;
    var missing(default, null):Array<String>;
  };
}

enum RoutePathRest {
  RIgnore;
  RCapture(name:String);
  RNotAllowed;
}

enum RoutePathPart {
  PConst(s:Portion);
  PCapture(name:String);
}

enum Body {
  BParsed(parsed:Array<Field>);
  BRaw(type:Type);
  BNone;
}