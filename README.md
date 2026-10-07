# a2a-rails-demo — Rails 8 Echo Agent

A standalone Rails application showing how a normal Rails app can expose an [A2A Protocol v1.0](https://a2a-protocol.org/v1.0.0/) JSON-RPC Agent through the [a2a-rails Gem](https://github.com/cuichangquan/a2a-rails). **This is a separate repository**; it adds no example-specific runtime code to the Gem.

> **Local/demo only.** The app permits anonymous requests **only** in Rails development/test environments and refuses to boot in production/staging. Always bind the server to `127.0.0.1`. Do not expose this process to a LAN or the internet. See [production security review](https://github.com/cuichangquan/a2a-rails/blob/main/docs/guides/production-security.md).

## Requirements / release status

- Ruby **3.4.10** (.ruby-version), Rails **8.1.0**, Puma **6.x**.
- Git-pinned **unreleased** `a2a-rails` source commit **`fb99610e25d5c0a5cb04bb2865f83e3fb44aaabb`**.
- No database, Redis, Docker, credentials, or external AI provider.
- Public RubyGems **a2a-rails 0.1.0** does **not** include the direct Message mode or subsequent security work. The Gem has **not** been republished.

## Quick Start

```bash
git clone https://github.com/cuichangquan/a2a-rails-demo.git
cd a2a-rails-demo
bundle install
bundle exec rails server -b 127.0.0.1 -p 3000
```

In a second terminal:

```bash
curl -sS -H 'A2A-Version: 1.0' \
  http://127.0.0.1:3000/.well-known/agent-card.json
```

Expected: Agent name **Echo Agent**, skill **reply**, `supportedInterfaces` containing JSONRPC protocol **1.0**, endpoint `/a2a`.

### 1. SendMessage — default Task response

```bash
curl -sS -X POST http://127.0.0.1:3000/a2a \
  -H 'Content-Type: application/json' -H 'A2A-Version: 1.0' \
  --data '{"jsonrpc":"2.0","id":"task-example","method":"SendMessage","params":{"message":{"messageId":"demo-task-1","role":"ROLE_USER","parts":[{"text":"Hello"}]}}}'
```

Expected fields (Task ID/context ID omitted):

```json
{
  "result": {
    "task": {
      "status": {"state": "TASK_STATE_COMPLETED"},
      "artifacts": [{"parts": [{"text": "Echo: Hello"}]}]
    }
  }
}
```

### 2. SendMessage — opt-in direct Message response

The Echo Agent sets a response policy: incoming text starting with `direct:` produces a direct Message **without creating a Task**.

```bash
curl -sS -X POST http://127.0.0.1:3000/a2a \
  -H 'Content-Type: application/json' -H 'A2A-Version: 1.0' \
  --data '{"jsonrpc":"2.0","id":"direct-example","method":"SendMessage","params":{"message":{"messageId":"demo-direct-1","role":"ROLE_USER","parts":[{"text":"direct: Hello"}]}}}'
```

Expected fields:

```json
{
  "result": {
    "message": {
      "role": "ROLE_AGENT",
      "parts": [{"text": "Echo: direct: Hello"}]
    }
  }
}
```

### 3. Verify via real HTTP smoke

Leave the Rails server running, and in a second terminal:

```bash
bundle exec ruby bin/smoke
```

This checks Agent Card discovery, actual JSON-RPC protocol v1.0, a completed Task with a Text Artifact, GetTask, ListTasks, direct Message with **no Task persistence**, terminal CancelTask error (-32002), and unsupported protocol version rejection (-32009). The test refuses non-local target URLs.

The same smoke runs in [GitHub Actions](.github/workflows/smoke.yml) on each push/PR.

## Implementation files

| File | Description |
| --- | --- |
| [app/agents/echo_agent.rb](app/agents/echo_agent.rb) | Agent Card, Skill and host response policy |
| [app/services/echo/reply.rb](app/services/echo/reply.rb) | SDK-independent Handler business logic |
| [config/initializers/a2a_rails.rb](config/initializers/a2a_rails.rb) | Gem registration |
| [config/routes.rb](config/routes.rb) | Empty host routes; Gem mounts its own Engine |
| [bin/smoke](bin/smoke) | End-to-end HTTP smoke |
| [.github/workflows/smoke.yml](.github/workflows/smoke.yml) | CI test environment |

**No application-specific Echo behavior is added to the Gem.** Replace the Handler and Agent with your own service logic.

## Security and limitations

This minimal example has **no trusted identity verifier, business authorization, durable Task storage, distributed rate limit, or deployment security review**. The default MemoryStore is process-local. Demo uses a single Rails worker on a loopback interface and explicitly rejects non-development/test environments. The `direct:` selector is only a response policy, not an authorization decision.

No streaming, push notifications, continuation or successful in-flight cancellation are claimed. Follow [a2a-rails Issue #11](https://github.com/cuichangquan/a2a-rails/issues/11) before contemplating public deployment.

## License

MIT.
