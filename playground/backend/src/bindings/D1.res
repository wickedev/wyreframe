// Cloudflare D1 binding wrappers. Underlying typed handles live in
// `Types.d1Database` / `Types.d1PreparedStatement`.

open Types

@send external bind: (d1PreparedStatement, @variadic array<JSON.t>) => d1PreparedStatement = "bind"
@send external first: d1PreparedStatement => promise<Nullable.t<'row>> = "first"
@send external all: d1PreparedStatement => promise<d1Result<'row>> = "all"
@send external run: d1PreparedStatement => promise<d1Result<'row>> = "run"

let prepare = (db: d1Database, sql: string): d1PreparedStatement => db.prepare(sql)
