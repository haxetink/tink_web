# Response

## Supported Return Types

The following types and their [`Future`](https://haxetink.github.io/tink_core/#/types/future)/[`Promise`](https://haxetink.github.io/tink_core/#/types/promise) variants are supported:

- `String`
- `OutgoingResponse` (see `tink_http`)
- `Source` (see `tink_io`)
- `HttpStatusCode` (see [`http-status`](https://github.com/kevinresol/http-status))
- Anything else will be serialized to json or querystring (See below)

## Meta

!> This section is incomplete, contribute using the button at the bottom of the page

```haxe
@:produces('TODO')
```