package tink.web.macros;

import haxe.macro.Type;
import haxe.macro.Context;

using tink.CoreApi;
using tink.MacroApi;

class RouteResult {
  
  var call:Lazy<CallResponse>;
  var type:Type;
  
  static var RAW_RESPONSE:Lazy<Type> = Context.getType.bind('tink.web.routing.Response');
  static var PARSED_RESPONSE:Lazy<Type> = Context.getType.bind('tink.web.Response');
  
  public function new(type:Type) {
    this.type = type;
    this.call = function() return
      if (type.getID() == 'tink.core.Noise')
        RNoise;
      else if (type.unifiesWith(PARSED_RESPONSE)) {
        switch type.isSubTypeOf(PARSED_RESPONSE, type.getPosition().sure()) {
          case Success(TAbstract(_, [data])): ROpaque(OParsed(type, data));
          default: throw 'assert';
        }
      }
      else if (type.unifiesWith(RAW_RESPONSE))
        ROpaque(ORaw(type));
      else
        RData(type);
  }
  
  public inline function asSubTarget() return type;
  public inline function asCallResponse() return call.get();
}

enum CallResponse {
  RNoise;
  RData(type:Type);
  ROpaque(res:OpaqueResponse);
}

enum OpaqueResponse {
  OParsed(response:Type, data:Type);
  ORaw(response:Type);
}