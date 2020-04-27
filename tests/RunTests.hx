package;

import tink.testrunner.*;
import tink.unit.*;

class RunTests {
	static function main() {
		Runner.run(TestBatch.make([
			new RemoteEndpoints(),
			new ProxyTest(),
			new DispatchTest(),
			new RawTest(),
			new TestRpc(),
		])).handle(Runner.exit);
	}
}