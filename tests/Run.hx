package ;

import haxe.unit.*;

import tink.web.Session;
import haxe.ds.Option;
using tink.CoreApi;

//class MySession implements Session {
  
  
  //public function getUser():Surprise<Option<{}>, Error> {
    //return null;
  //}
//}

class Run {
  function new() {}
  static var tests:Array<TestCase> = [
    new DispatchTest(),
    //new ProxyTest(),
    //new QueryParserTest(),
    //new QueryComposerTest(),
  ];
  static function main() {  
    
    //trace('done');
    //return;
    //var route = new tink.web.Router<Run>();
    //route.route(new Run(), null);
    var r = new TestRunner();
    for (c in tests)
      r.add(c);
      
    if (!r.run())
      Sys.exit(500);
  }

}