// React Router v6 bindings.

module Routes = {
  @module("react-router-dom") @react.component
  external make: (~children: React.element) => React.element = "Routes"
}

module Route = {
  @module("react-router-dom") @react.component
  external make: (~path: string, ~element: React.element, ~children: React.element=?) => React.element = "Route"
}

module Link = {
  @module("react-router-dom") @react.component
  external make: (
    ~to: string,
    ~className: string=?,
    ~children: React.element,
    ~replace: bool=?,
    ~target: string=?,
    ~rel: string=?,
  ) => React.element = "Link"
}

module NavLink = {
  @module("react-router-dom") @react.component
  external make: (
    ~to: string,
    ~className: string=?,
    ~children: React.element,
  ) => React.element = "NavLink"
}

@module("react-router-dom") external useNavigate: unit => (string => unit) = "useNavigate"

// Same `useNavigate` function, typed to pass router location state as the
// optional second argument (e.g. `navigate("/playground", {state})`).
type navigateOptions<'a> = {state: 'a}
@module("react-router-dom")
external useNavigateWithState: unit => (string, navigateOptions<'a>) => unit = "useNavigate"

@module("react-router-dom")
external useLocation: unit => {"pathname": string, "search": string, "state": Nullable.t<'a>} =
  "useLocation"
@module("react-router-dom") external useParams: unit => Dict.t<string> = "useParams"
@module("react-router-dom") external useSearchParams: unit => ('a, 'b) = "useSearchParams"
