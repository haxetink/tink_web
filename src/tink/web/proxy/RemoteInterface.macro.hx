package tink.web.proxy;

import tink.macro.BuildCache;
import haxe.macro.Context;

using tink.MacroApi;

class RemoteInterface<T> {
  public static function build() {
    return BuildCache.getType('tink.web.proxy.RemoteInterface', (ctx:BuildContext) -> {
      final name = ctx.name;
      final ct = ctx.type.toComplex();
      final routes = new tink.web.macros.RouteCollection(ctx.type, ['application/json'], ['application/json']);
      
      
      final def = macro class $name {}
      
      def.fields = [for (f in routes) {
        pos: f.field.pos,
        name: f.field.name,
        kind: FFun({
          args: [for (arg in f.signature.args) switch arg.kind {
            case AKSingle(_, ATUser(_) | ATContext): continue;
            case _: { name: arg.name, type: arg.type.toComplex(), opt: arg.optional };
          }],
          ret: switch f.kind {
            case KCall(c):
              final ct = switch f.signature.result.asCallResponse() {
                case RNoise:
                  macro:tink.core.Noise;
                case RData(t):
                  t.toComplex();
                case ROpaque(OParsed(res, _)):
                  res.toComplex();
                case ROpaque(ORaw(t)) if (Context.getType('tink.http.Response.IncomingResponse').unifiesWith(t)):
                  t.toComplex();
                case ROpaque(ORaw(_)):
                  macro:tink.http.Response.IncomingResponse;
              }
              macro:tink.core.Promise<$ct>;
              
            case KSub:
              final target = f.signature.result.asSubTarget().toComplex();
              macro:tink.web.proxy.RemoteInterface<$target>;
          },
        }),
      }];
      
      
      def.kind = TDClass(null, null, true); // interface
      def;
    });
  }
}