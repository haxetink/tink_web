package ;

import haxe.unit.*;

class Run {
  function new() {}
  static var tests:Array<TestCase> = [
    new DispatchTest(),
  ];
  static function main() {  
    //var route = new tink.web.Router<Run>();
    //route.route(new Run(), null);
    var r = new TestRunner();
    for (c in tests)
      r.add(c);
      
    if (!r.run())
      Sys.exit(500);
  }

}