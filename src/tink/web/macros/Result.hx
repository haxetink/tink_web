package tink.web.macros;

#if macro
import haxe.macro.Type;
import haxe.macro.Context;

using tink.CoreApi;
using tink.MacroApi;

class Result {

  var call:Lazy<CallResponse>;
  var type:Type;

  static final RAW_RESPONSE:Lazy<Type> = Context.getType.bind('tink.web.routing.Response');
  static final PARSED_RESPONSE:Lazy<Type> = Context.getType.bind('tink.web.Response');
  static final STREAM_RESPONSE:Lazy<Type> = Context.getType.bind('tink.streams.RealStream');

  public function new(type:Type, pos:Position) {
    this.type = type;
    this.call = function() return
      if (type.getID() == 'tink.core.Noise')
        RNoise;
      else if (type.unifiesWith(PARSED_RESPONSE)) {
        switch type.isSubTypeOf(PARSED_RESPONSE, pos) {
          case Success(TAbstract(_, [data])): ROpaque(OParsed(type, data));
          default: throw 'assert';
        }
      }
      else if (type.unifiesWith(RAW_RESPONSE))
        ROpaque(ORaw(type));
      else switch type.isSubTypeOf(STREAM_RESPONSE, pos) {
        case Success(TAbstract(_, [data])): REvents(data);
        default: RData(type);
      }
  }

  public inline function asSubTarget() return type;
  public inline function asCallResponse() return call.get();
}

enum CallResponse {
  RNoise;
  REvents(type:Type);
  RData(type:Type);
  ROpaque(res:OpaqueResponse);
}

enum OpaqueResponse {
  OParsed(response:Type, data:Type);
  ORaw(response:Type);
}
#end