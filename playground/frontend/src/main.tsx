import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { TooltipProvider } from "@radix-ui/react-tooltip";
import { make as App } from "./Index.mjs";
import "./styles.css";

const root = document.querySelector("#root");
if (!root) {
  console.error('Root element not found. Make sure your HTML has a <div id="root"></div>');
} else {
  createRoot(root).render(
    <StrictMode>
      {/* App-wide Radix Tooltip provider (deployed used delayDuration 400 / skipDelayDuration 300). */}
      <TooltipProvider delayDuration={400} skipDelayDuration={300}>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </TooltipProvider>
    </StrictMode>,
  );
}
