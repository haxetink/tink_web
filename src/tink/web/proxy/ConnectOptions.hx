package tink.web.proxy;

import tink.http.Client;
import tink.http.Header;

typedef ConnectOptions = {>TestOptions,
  ?client:Client,
}

typedef TestOptions = {
  ?headers:Array<HeaderField>,
  ?augment:Processors,
}