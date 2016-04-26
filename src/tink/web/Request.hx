package tink.web;

import tink.http.Request;

@:forward
abstract Request(IncomingRequest) from IncomingRequest to IncomingRequest {
  
}