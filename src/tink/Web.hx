package tink;

#if macro
import haxe.macro.Expr;
using tink.MacroApi;
#end
class Web {
  static public macro function connect(e:Expr, ?options:ExprOf<tink.web.proxy.ConnectOptions>)
    return switch e {
      case macro ($url:$t), { expr: ENew(TPath(_) => t, [url])}:
        var options = switch options {
          case null | macro null: new Map();
          case { expr: EObjectDecl(fields) }:
            (macro @:pos(options.pos) ($options:tink.web.proxy.ConnectOptions)).typeof().sure();
            [for (f in fields) f.field => f.expr];
          case v:
            v.reject('anonymous object expected');
        }

        var client = switch options['client'] {
          case null: macro @:privateAccess tink.http.Fetch.getClient(Default, true);//not sure how adequate this is
          case v: v;
        }

        switch options['augment'] {
          case null:
          case v:
            client = macro @:pos(v.pos) $client.augment($v);
        }

        var endpoint = macro @:pos(url.pos) tink.web.proxy.Remote.RemoteEndpoint.ofString($url);

        switch options['headers'] {
          case null:
          case v:
            endpoint = macro @:pos(v.pos) endpoint.sub({ headers: $v });
        }

        macro @:pos(e.pos) new tink.web.proxy.Remote<$t>($client, $endpoint);
      default: e.pos.error('Expected (url:Type) or new Type(url)');
    }
}