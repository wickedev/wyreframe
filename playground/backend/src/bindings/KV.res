// Thin convenience wrappers over the Cloudflare KV namespace methods. The
// underlying typed binding lives at `Types.kvNamespace`.

open Types

type putOptions = {expirationTtl?: int}

let get = async (kv: kvNamespace, key: string): option<string> => {
  let v = await kv.get(key)
  v->Nullable.toOption
}

let put = async (kv: kvNamespace, key: string, value: string): unit =>
  await kv.put(key, value, {})

let putWithTtl = async (kv: kvNamespace, key: string, value: string, ttl: int): unit =>
  await kv.put(key, value, {expirationTtl: ttl})

let delete = async (kv: kvNamespace, key: string): unit => await kv.delete(key)
