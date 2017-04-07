package ;

import haxe.unit.*;

class Run {
  function new() {}
  static var tests:Array<TestCase> = [
    new DispatchTest(),
    new ProxyTest(),
  ];
  static function main() {  
    
    var r = new TestRunner();
    for (c in tests)
      r.add(c);
      
    travix.Logger.exit(
      if (!r.run()) 500
      else 0
    );
  }
  
}