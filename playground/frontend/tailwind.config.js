/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{res,mjs,ts,tsx}"],
  theme: {
    extend: {
      // shadcn/ui design tokens. The original CSS bundle used the same
      // background/foreground variable naming convention; keep parity so
      // existing component snippets continue to work.
      colors: {
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        card: "hsl(var(--card))",
        popover: "hsl(var(--popover))",
        primary: "hsl(var(--primary))",
        secondary: "hsl(var(--secondary))",
        muted: "hsl(var(--muted))",
        accent: "hsl(var(--accent))",
        destructive: "hsl(var(--destructive))",
        success: "hsl(var(--success))",
        warning: "hsl(var(--warning))",
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
      },
    },
  },
  plugins: [],
};
