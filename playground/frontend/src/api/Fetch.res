// Web Fetch API bindings.

type response

@val external fetch: (string, {..}) => promise<response> = "fetch"
@send external json: response => promise<JSON.t> = "json"
@send external text: response => promise<string> = "text"
@get external ok: response => bool = "ok"
@get external status: response => int = "status"
@get external statusText: response => string = "statusText"
@get external body: response => 'stream = "body"
@get external headers: response => {..} = "headers"
