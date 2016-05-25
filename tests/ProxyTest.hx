package;
import haxe.unit.TestCase;
import tink.web.Proxy;

class ProxyTest extends TestCase {

  function testProxy() {
    var p = new Proxy<Fake>(null, 'localhost');
    
    p.complex({ foo: [{ z: 3 }] });
    //trace(p);
    //p.complex(
    
    //p.
  }
}