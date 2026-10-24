# MCP documentation — verified against Kong (official)

Last checked against Kong developer docs (entity model, aggregate tutorial, on-prem guide). Use this to trust local guides: **[AI-GATEWAY-MCP.md](AI-GATEWAY-MCP.md)**, **[MCP-KONNECT-UI.md](MCP-KONNECT-UI.md)**, **[MCP-ENTERPRISE-REGISTRY.md](MCP-ENTERPRISE-REGISTRY.md)**.

Official sources:

- [Kong AI Gateway 2.0: How to Create MCP Servers (YouTube)](https://www.youtube.com/watch?v=_azfxIliMgI) — UI walkthrough for upstream server + listener (aligns with aggregation docs; not conversion-listener Petstore)
- [AI MCP Server entity](https://developer.konghq.com/ai-gateway/entities/ai-mcp-server/)
- [Aggregate MCP tools](https://developer.konghq.com/ai-gateway/aggregate-mcp-tools/)
- [Map RESTful API to MCP tools](https://developer.konghq.com/ai-gateway/map-api-to-mcp-tools/)
- [Configure AI Gateway on-prem](https://developer.konghq.com/ai-gateway/configure-on-prem/)

---

## Five server modes (verified)

| Type | Official purpose | Local docs match? |
| --- | --- | --- |
| `passthrough-listener` | Proxy MCP to existing MCP server; no REST conversion | Yes |
| `conversion-listener` | REST → tools + client MCP endpoint on route path | Yes — [petstore example](examples/petstore-mcp-server-2.1.yaml) |
| `conversion-only` | REST → tools; **must** pair with `listener` for client traffic | Yes |
| `listener` | Aggregates `conversion-only` and/or `upstream-server` by `sources` | Yes |
| `upstream-server` | Register native MCP for listener; fetch tool list | Yes |

Kong lists **five modes** under `type` on the AI MCP Server entity ([server modes](https://developer.konghq.com/ai-gateway/entities/ai-mcp-server/#server-modes)).

---

## Listener `sources` (verified)

Official ([Tool aggregation](https://developer.konghq.com/ai-gateway/entities/ai-mcp-server/#tool-aggregation-with-upstream-server)):

> Set the listener's top-level **`sources`** field to the immutable **`name`** of each **`upstream-server`** (or **`conversion-only`**) AI MCP Server.

| In `sources` | Allowed per Kong |
| --- | --- |
| `conversion-only` | **Yes** |
| `upstream-server` | **Yes** |
| `passthrough-listener` | **No** (not listed; only the two types above) |
| `conversion-listener` | **No** |

Official aggregate tutorial ([Aggregate MCP tools](https://developer.konghq.com/ai-gateway/aggregate-mcp-tools/)):

1. Create **`conversion-only`** per REST API (`cards-mcp`, `petstore-mcp`).
2. Create **`listener`** with `sources: [cards-mcp, petstore-mcp]` and path `/mcp-aggregation`.
3. Client calls **`http://localhost:8000/mcp-aggregation`** only.

```yaml
# From Kong aggregate tutorial (abbreviated)
type: listener
config:
  route:
    paths:
      - /mcp-aggregation
sources:
  - cards-mcp
  - petstore-mcp
```

**Local claim verified:** multiple **passthrough** routes ≠ aggregation; merge requires **listener + sources**, not passthrough in sources.

---

## Passthrough vs upstream-server (verified)

| | Official behavior | Local docs |
| --- | --- | --- |
| **Passthrough listener** | Proxies MCP traffic to upstream MCP; client uses **this** route ([entity](https://developer.konghq.com/ai-gateway/entities/ai-mcp-server/#server-modes)) | Match |
| **Upstream server** | Registers MCP for **listener**; tool list fetch + routing; pairs with **listener** | Match |
| **Auth on passthrough / listener / conversion-listener** | `access.auth_strategies` supported | Match |
| **Auth on upstream-server** | No `access.auth_strategies`; use `config.server.tools_list_auth` for tool list fetch | Match |
| **Auth on conversion-only** | No top-level `access` (inbound auth on **listener**) | Match |

---

## Tool naming on merge (verified)

Official: if two sources expose the same tool name, listener may **prepend the service name** (e.g. `weather-service/get-forecast`). Optional `config.server.preserve_upstream_tool_names: true` if names cannot collide.

Local docs mention prefixing — **match**.

Parameter prefix for REST tools: `{in}_{name}` (e.g. `path_petId`) — official entity doc — **match** with [Map REST to MCP](https://developer.konghq.com/ai-gateway/map-api-to-mcp-tools/).

---

## No separate “MCP Registry” product (verified)

Konnect UI path: **AI Gateway → MCP Servers → New MCP Server** (types above). **Catalog** can list MCP servers org-wide ([entity — Manage](https://developer.konghq.com/ai-gateway/entities/ai-mcp-server/#manage-ai-mcp-servers)); aggregation endpoint is still **`listener`**, not Catalog.

Local **[MCP-KONNECT-UI.md](MCP-KONNECT-UI.md)** — **match**.

---

## On-prem / OpenShift (verified)

Official [Configure AI Gateway on-prem](https://developer.konghq.com/ai-gateway/configure-on-prem/):

| Entity mode | Self-hosted Kong via decK |
| --- | --- |
| **AI MCP Server** generally | Routes + **`ai-mcp-proxy`** (`deck file ai2kong`) |
| **`upstream-server`** | **No self-hosted equivalent** — plugin `mode` does not support it the same way |

Implications:

| Pattern | Konnect / AI Gateway 2.x entity CP | decK-only self-hosted |
| --- | --- | --- |
| Conversion listener (Petstore) | Yes | Yes (ai2kong) |
| conversion-only + listener (REST merge) | Yes | Yes (ai2kong) |
| Passthrough listener | Yes | Yes (ai2kong) |
| upstream-server + listener (native MCP merge) | Yes | **Limited — verify; official says no full upstream-server equivalent** |

Local **[MCP-ENTERPRISE-REGISTRY.md](MCP-ENTERPRISE-REGISTRY.md)** on-prem table — **match**.

---

## Minor nuance (official detail)

**`conversion-only`** entities in the aggregate tutorial may include `config.route.paths` (e.g. Deck of Cards `/api/deck`) for gateway routing internals. **Clients still use the `listener` path** for aggregated REST tools (`/mcp-aggregation`), not each conversion-only path.

**`conversion-only`** used **without** a listener does not give agents a merged endpoint — Kong requires **listener** for aggregation ([conversion-only must be used with listener](https://developer.konghq.com/ai-gateway/entities/ai-mcp-server/#server-modes)).

---

## Summary

| Topic | Verdict |
| --- | --- |
| Five types + Conversion listener Petstore lab | **Correct** |
| Listener merge = only `conversion-only` + `upstream-server` in `sources` | **Correct** |
| Passthrough × N ≠ one merged catalog | **Correct** |
| Passthrough vs upstream-server roles | **Correct** |
| No MCP Registry menu | **Correct** |
| On-prem: REST patterns via ai2kong; upstream-server aggregation caveat | **Correct** |

Re-verify after major Kong releases: run through [Aggregate MCP tools](https://developer.konghq.com/ai-gateway/aggregate-mcp-tools/) and compare `sources` / mode enums in [AI MCP Server reference](https://developer.konghq.com/ai-gateway/entities/ai-mcp-server/).
