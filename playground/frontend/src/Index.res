// App entry. Renders the route table; BrowserRouter is wired in main.tsx.

@react.component
let make = () =>
  <Router.Routes>
    <Router.Route path="/" element={<LandingPage />} />
    <Router.Route path="/play" element={<PlaygroundPage />} />
    <Router.Route path="/playground" element={<PlaygroundPage />} />
    <Router.Route path="/admin" element={<AdminPage />} />
  </Router.Routes>
