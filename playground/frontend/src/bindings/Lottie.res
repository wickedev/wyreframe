// lottie-react binding for the empty-state animation.

@module("lottie-react") @react.component
external make: (
  ~animationData: 'a=?,
  ~path: string=?,
  ~loop: bool=?,
  ~autoplay: bool=?,
  ~className: string=?,
  ~style: ReactDOM.Style.t=?,
) => React.element = "default"
