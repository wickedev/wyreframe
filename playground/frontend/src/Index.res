// App entry. Renders the route table; BrowserRouter is wired in main.tsx.
// Routes mirror the deployed bundle: "/", "/playground", "/playground/:sessionId",
// "/admin", and a "*" not-found catch-all. PlaygroundPage/AdminPage are wrapped
// in Suspense (lazy in the original deployment).

module RouteLoadingFallback = {
  @react.component
  let make = () =>
    <div className="h-screen flex items-center justify-center">
      <div className="text-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4" />
        <p className="text-muted-foreground"> {React.string("Loading...")} </p>
      </div>
    </div>
}

module NotFound = {
  @react.component
  let make = () => {
    let navigate = Router.useNavigate()
    <div className="h-screen flex items-center justify-center bg-background">
      <div className="text-center max-w-md px-4">
        <h1 className="text-6xl font-bold text-foreground mb-4"> {React.string("404")} </h1>
        <h2 className="text-2xl font-semibold text-foreground mb-4">
          {React.string("Page Not Found")}
        </h2>
        <p className="text-muted-foreground mb-8">
          {React.string("The page you're looking for doesn't exist or has been moved.")}
        </p>
        <button
          className="bg-primary text-primary-foreground hover:bg-primary/90 rounded-md px-6 py-3 font-medium transition-colors"
          onClick={_ => navigate("/")}>
          {React.string("Return Home")}
        </button>
      </div>
    </div>
  }
}

@react.component
let make = () =>
  <Router.Routes>
    <Router.Route path="/" element={<LandingPage />} />
    <Router.Route
      path="/playground"
      element={<React.Suspense fallback={<RouteLoadingFallback />}> <PlaygroundPage /> </React.Suspense>}
    />
    <Router.Route
      path="/playground/:sessionId"
      element={<React.Suspense fallback={<RouteLoadingFallback />}> <PlaygroundPage /> </React.Suspense>}
    />
    <Router.Route
      path="/admin"
      element={<React.Suspense fallback={<RouteLoadingFallback />}> <AdminPage /> </React.Suspense>}
    />
    <Router.Route path="*" element={<NotFound />} />
  </Router.Routes>
