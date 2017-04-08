package;

import tink.testrunner.*;
import tink.unit.*;

class RunTests {
	static function main() {
		Runner.run(TestBatch.make([
			// new ProxyTest(),
			new DispatchTest(),
		])).handle(Runner.exit);
	}
}