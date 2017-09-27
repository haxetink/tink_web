package tink.web;

import tink.http.Message;
import tink.http.Response;

typedef TypedResponse<T> = Message<ResponseHeader, T>;

@:forward
abstract Response<T>(TypedResponse<T>) {
	public inline function new(header, body)
		this = new Message(header, body);
	
	@:to
	public inline function getData():T
		return this.body;
}