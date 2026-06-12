// Resolves the backend base URL. In production we hit the same origin
// (`wyreframe.studio` routes `/api/*` to the worker). In local dev
// `vite.config.ts` proxies `/api/*` to localhost:8787, so the empty base
// works there too.

let apiBase = ""

let url = (path: string): string => apiBase ++ path
