# Response

## Supported Return Types

The following types and their `Future`/`Promise` variants are supported:

- String
- Http Status Code (see `http-status`)
- Source (see `tink_io`)
- OutgoingResponse (see `tink_http`)
- Anything else will be serialized to json or querystring (See below)

## Meta

```haxe
@:produces('TODO')
```