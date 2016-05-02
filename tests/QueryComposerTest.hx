package;

import haxe.unit.TestCase;
import tink.web.QueryComposer;

class QueryComposerTest extends TestCase {

  function testSimple() {
    var map = QueryComposer.query({ foo: 'bar' }).toMap();
    assertEquals('bar', map['foo']);
  }
  
}