package;
import haxe.unit.TestCase;
import tink.web.helpers.QueryParserBase;

class QueryParserTest extends TestCase { 

  function testBase() {
    var q = new QueryParserBase('o[0][a]=1&o[0][b]=2&o[1][c]=1&o[1][d]=2');
    throw @:privateAccess q.exists;
  }
  
}