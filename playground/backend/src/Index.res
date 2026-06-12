// Entry point. Assembles the Hono app with the same shape as the recovered
// bundle:
//
//   cors -> metricsMiddleware -> { OAuth, Sessions, Chat, Issues, Monitoring }
//   -> catch-all 404 { error: "NotFound", ... }
//
// Each route module exposes a `register: Hono.t<env> => Hono.t<env>` that
// chains its endpoints onto the passed app.

open Types

let catchAll = async (ctx: Hono.context<env>): Web.Response.t =>
  ctx->Hono.jsonWithStatus(
    {
      "error": "NotFound",
      "message": "The requested route does not exist",
      "statusCode": 404,
    },
    404,
  )

let createApp = (): Hono.t<env> => {
  let app = Hono.make()
  app
  ->Hono.use(Hono.Cors.cors())
  ->Monitoring.registerMiddleware
  ->OAuth.register
  ->Sessions.register
  ->Chat.register
  ->Issues.register
  ->Monitoring.register
  ->Hono.all("*", catchAll)
}

let app = createApp()

let default = app
