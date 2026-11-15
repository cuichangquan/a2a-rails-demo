# a2a-rails-demo — Rails 8 Echo and report Agent

A standalone Rails application showing how a normal Rails app can expose an [A2A Protocol v1.0](https://a2a-protocol.org/v1.0.0/) JSON-RPC Agent through the [a2a-rails Gem](https://github.com/cuichangquan/a2a-rails). **This is a separate repository**; it adds no example-specific runtime code to the Gem.

> **Local/demo only.** The app permits anonymous requests **only** in Rails development/test environments and refuses to boot in production/staging. Always bind the server to `127.0.0.1`. Do not expose this process to a LAN or the internet. See [production security review](https://github.com/cuichangquan/a2a-rails/blob/main/docs/guides/production-security.md).

## Requirements / release status

- Ruby **3.4.10** (.ruby-version), Rails **8.1.4**, Puma **6.x**.
- This change targets the **unpublished `a2a-rails 0.4.0` candidate**. `Gemfile` keeps the published baseline; `Gemfile.candidate` selects the explicitly pinned source revision for the report feature. Candidate validation does not fetch a nonexistent RubyGems 0.4.0 release. The last published baseline is 0.3.0; its text Echo remains the minimal example.
- No database, Redis, Docker, credentials, or external AI provider.
- This local-only demo uses the default process-local MemoryStore; optional ActiveRecord/ActiveJob features are not configured.

The candidate retains the default inbound Server mode; this demo does not
configure the outbound Client. The Gemfile also selects patched `net-imap
~> 0.5.15` for the consuming Rails host; check your resolved dependency graph
and security advisories independently.

## Quick Start

```bash
git clone https://github.com/cuichangquan/a2a-rails-demo.git
cd a2a-rails-demo

# Use the reviewed candidate checkout and its pinned dependency before installing.
export BUNDLE_GEMFILE=Gemfile.candidate
bundle install
bundle exec rails server -b 127.0.0.1 -p 3000
```

In a second terminal:

```bash
curl -sS -H 'A2A-Version: 1.0' \
  http://127.0.0.1:3000/.well-known/agent-card.json
```

Expected: Agent name **Echo Agent**, skills **reply** and **report**, `supportedInterfaces` containing JSONRPC protocol **1.0**, endpoint `/a2a`.

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

### 3. Structured report — Data Part to a Rails Service

The `report` Skill accepts one Data Part with an object containing integer `year`
(2000..2100), `month` (1..12), and positive `department_id`; no extra fields.
This is a small **synthetic** sales report, not real company data. It has no LLM,
external service, database or Job dependency. It runs synchronously in MemoryStore.

```bash
curl -sS -X POST http://127.0.0.1:3000/a2a \
  -H 'Content-Type: application/json' -H 'A2A-Version: 1.0' \
  --data '{"jsonrpc":"2.0","id":"report-example","method":"SendMessage","params":{"message":{"messageId":"report-1","role":"ROLE_USER","parts":[{"data":{"year":2026,"month":10,"department_id":123}}]}}}'
```

Expected completed Task, with this object at `result.task.artifacts[0].parts[0].data`:

```json
{"year":2026,"month":10,"department_id":123,"sales_count":3,"total_amount":35000,"currency":"JPY"}
```

The fixture has three matching sales (12,000 + 18,000 + 5,000 JPY) and separate
nonmatching month, department and year rows. No matching sales is a successful
report with zero count and total. Replacing `month: 10` with `month: 13` produces
`TASK_STATE_REJECTED` and no report Artifact, because the business conditions are
invalid. Protocol acceptance and successful business completion are separate.

Keep `BUNDLE_GEMFILE=Gemfile.candidate` in both terminals and for all candidate test commands.

The existing Router selects `report` when a Data Part is present and `reply`
otherwise. This is Skill selection, not authorization. The Gem checks the selected
Skill's declared input mode before calling its Handler. `report` declares
`input_modes: ["application/json"]`; omitting a Data Part's `mediaType` means
`application/json`. Explicit incompatible media types and mixed text/Data input
are not supported by this candidate. The report Handler also requires exactly
one Data Part; it does not merge several condition objects. `direct:` remains a
text Echo-only response choice, so reports always return a Task.

The application boundary is small:

1. A2A protocol parsing and Skill selection produce an ordinary Ruby message.
2. `Reports::Generate` reads `message[:parts][0][:data]`, preserving its string keys.
3. `Reports::SalesSummary.call(criteria:)` filters the fixed rows and returns a Hash.
4. The Gem maps that Hash to a Data Artifact and persists the Task in MemoryStore.

The same business service can be called without A2A:

```bash
bundle exec rails runner 'p Reports::SalesSummary.call(criteria: {"year" => 2026, "month" => 10, "department_id" => 123})'
```

Direct invocation returns the same Hash (or raises `InvalidConditions`). A2A adds
transport, protocol/Skill validation, Task identity/history and an Artifact.
The Handler translates that domain error into a safe `RejectedTask`; it does not
expose arbitrary input or internal exception details. Neither path adds business
authorization, durable accounting or an exactly-once execution guarantee.

### 4. Verify via real HTTP smoke

Leave the Rails server running, and in a second terminal:

```bash
bundle exec ruby bin/smoke
```

This checks Agent Card discovery, actual JSON-RPC protocol v1.0, a completed Task with a Text Artifact, GetTask, ListTasks, direct Message with **no Task persistence**, terminal CancelTask error (-32002), and unsupported protocol version rejection (-32009). It also checks the report Skill, exact aggregate result, retained conditions and Artifact after GetTask, and the rejected invalid-month case. The test refuses non-local target URLs.

Run the SDK-independent business tests separately:

```bash
bundle exec ruby test/sales_summary_test.rb
```

The same smoke is the Server CI check in [GitHub Actions](.github/workflows/smoke.yml).
Its two bounded jobs keep the published 0.3.0 Echo regression (`Gemfile`,
`bin/smoke --echo-only`) separate from the pinned candidate's Echo + report
checks (`Gemfile.candidate`, `bin/smoke`). Each job has an eight-minute ceiling.
The independent [Rails Client demo](https://github.com/cuichangquan/a2a-rails-client-demo)
uses the existing isolated test-only TLS bridge for real Client-to-Server report
validation. It preserves the shipped Client's HTTPS, origin and destination
restrictions. Direct Client connections to this localhost HTTP demo remain
unsupported; the Server curl example does not bypass or configure the Client.

Local business tests establish filtering/validation only. Local `bin/smoke`
establishes actual Server HTTP; the separate Client TLS harness establishes the
cross-process candidate integration. Check the candidate's recorded SHA and actual
CI results; historical 0.3.0 passes are not evidence for the new report feature.
Formal Gem publication is separate. After publication, both demos must pin the
published release and repeat the same checks before claiming released-Gem support.

The candidate is identified by its exact Git SHA, not by a published version
number. Its source still carries the 0.3.0 version constant until release
preparation; the source-identity check distinguishes it from RubyGems 0.3.0.

## Implementation files

| File | Description |
| --- | --- |
| [app/agents/echo_agent.rb](app/agents/echo_agent.rb) | Agent Card, Skill and host response policy |
| [app/services/echo/reply.rb](app/services/echo/reply.rb) | Minimal Echo Handler |
| [app/services/reports/sales_summary.rb](app/services/reports/sales_summary.rb) | SDK-independent fixture, validation and aggregation |
| [app/services/reports/generate.rb](app/services/reports/generate.rb) | Data-message adapter and safe domain rejection |
| [test/sales_summary_test.rb](test/sales_summary_test.rb) | Normal business filtering and validation checks |
| [config/initializers/a2a_rails.rb](config/initializers/a2a_rails.rb) | Gem registration |
| [config/routes.rb](config/routes.rb) | Empty host routes; Gem mounts its own Engine |
| [bin/smoke](bin/smoke) | End-to-end HTTP smoke |
| [.github/workflows/smoke.yml](.github/workflows/smoke.yml) | CI test environment |

**No application-specific Echo behavior is added to the Gem.** Replace the Handler and Agent with your own service logic.

## Security and limitations

This minimal example has **no trusted identity verifier, business authorization, durable Task storage, distributed rate limit, or deployment security review**. The default MemoryStore is process-local. Demo uses a single Rails worker on a loopback interface and explicitly rejects non-development/test environments. The `direct:` selector is only a response policy, not an authorization decision.

Data input is object-only; the report is a normal A2A application example, not an AP2 extension. No streaming, push notifications, continuation or successful in-flight cancellation are claimed. Follow [a2a-rails Issue #11](https://github.com/cuichangquan/a2a-rails/issues/11) before contemplating public deployment.

## License

MIT.
