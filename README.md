# a2a-rails-demo — Echo, report and same-Task continuation

A standalone Rails host for [a2a-rails](https://github.com/cuichangquan/a2a-rails),
using A2A v1.0 JSON-RPC. This Server installs **published RubyGems 0.5.1**,
not a Git/path candidate. [release.json](release.json) records the exact version
and package SHA-256 verified by `bin/verify_release` and CI. The public package
matches the final core CI artifact; prior candidate evidence remains in Git history.

> **Local/demo only.** Anonymous requests are allowed only in development/test.
> Production/staging boot is refused. Bind only to `127.0.0.1`, never LAN/internet.
> This is not a production authorization or durable workflow example.

## Quick Start

Ruby 3.4.13, Rails 8.1.4.1 and Bundler are required. No database, queue, LLM,
external service or new cloud resource is needed.

```sh
git clone https://github.com/cuichangquan/a2a-rails-demo.git
cd a2a-rails-demo
bundle install
bundle exec ruby bin/verify_release
bundle exec rails server -b 127.0.0.1 -p 3000
```

The default synchronous MemoryStore is process-local. **Restarting the Server
loses waiting Tasks.** This demo does not claim restart/worker durability;
ActiveRecord/ActiveJob guarantees and upgrade tests belong to the Gem.

## Familiar examples remain

```sh
# Minimal Echo, Get/List, direct Message and terminal cancellation checks:
bundle exec ruby bin/smoke
# One-shot full report, invalid month, and the same Echo checks:
bundle exec ruby bin/smoke --report
# All above plus question/answer, repeated questions and waiting cancellation:
bundle exec ruby bin/smoke --continuation
```

The smallest individual request is unchanged:

```sh
curl -sS http://127.0.0.1:3000/a2a \
  -H 'Content-Type: application/json' -H 'A2A-Version: 1.0' \
  --data '{"jsonrpc":"2.0","id":"echo","method":"SendMessage","params":{"message":{"messageId":"echo-1","role":"ROLE_USER","parts":[{"text":"Hello"}]}}}'
```

SendMessage with text returns an Echo Task. Text beginning `direct:` returns
only a Message and never creates a Task. A Data Part selects the `report` Skill.
Complete criteria `{"year":2026,"month":10,"department_id":123}` still finish in
one call, returning **3 sales / JPY 35,000**. Month 13 still yields
`TASK_STATE_REJECTED`, no Artifact, even if other fields are missing.

## Ask, answer, finish the same Task

```sh
curl -sS http://127.0.0.1:3000/a2a \
  -H 'Content-Type: application/json' -H 'A2A-Version: 1.0' \
  --data '{"jsonrpc":"2.0","id":"start","method":"SendMessage","params":{"message":{"messageId":"report-start-1","role":"ROLE_USER","parts":[{"data":{"year":2026,"month":10}}]}}}'
```

Save `result.task.id`. State is `TASK_STATE_INPUT_REQUIRED`, not completion.
`status.message.parts` contains `Please provide: department_id.` and Data
`{"missing_fields":["department_id"]}`. GetTask and ListTasks retain this state.
Use a fresh messageId for a genuinely new answer, and substitute the saved ID:

```sh
curl -sS http://127.0.0.1:3000/a2a \
  -H 'Content-Type: application/json' -H 'A2A-Version: 1.0' \
  --data '{"jsonrpc":"2.0","id":"answer","method":"SendMessage","params":{"message":{"messageId":"report-answer-1","taskId":"SAVED_TASK_ID","role":"ROLE_USER","parts":[{"data":{"department_id":123}}]}}}'
```

The **same** Task/context completes. The app combines original year/month with
the department answer; the Gem returns to the original report Skill, not the
Router. GetTask with `{"id":"SAVED_TASK_ID","historyLength":0}` returns the report
without response history. Response-history suppression does not delete stored
inputs needed for continuation.

- Send only `{"year":2026}`, then answer `{"month":10}`: the same Task asks again
  for department. A final department answer completes it.
- CancelTask while waiting: the Task becomes canceled. Later answers are refused.
- A **new** answer after completion is refused with UnsupportedOperation (-32004),
  never silently made a new Task.
- New answers are sent once. After an ambiguous transport failure inspect Task
  state and the Gem's resend contract; do not blindly resubmit with a new ID.

## What the application owns

`Reports::Generate.call(message:, context:)` uses Gem-owned `InputRequired`, not
SDK classes. `message` is this turn's input; `context[:history]` includes current
and previous messages. The app filters user inputs (not agent questions), accepts
exactly one object Data Part per input, validates allowed fields and combines them
in order. Later answers can explicitly replace earlier valid report fields.
Invalid supplied values are rejected before asking about absent fields.

```ruby
return A2A::Rails::InputRequired.new("Please provide: department_id.",
  data: { "missing_fields" => ["department_id"] })
```

The Gem does not merge JSON or decide business authorization. The example is
anonymous with synthetic rows, not sensitive business data. Its allowed fields
are year (integer 2000..2100), month (integer 1..12), department_id (positive
integer), with no extras. String keys are retained. Input mixed text/Data and
non-object Data are not added. Questions may have text plus Data output Parts.
The report Skill declares both JSON and text output, JSON-only input.

`Reports::SalesSummary.call(criteria:)` remains SDK-independent, callable
without A2A, and returns a normal Hash. The explicit InputRequired result avoids
interpreting business Hash keys as Task state.

## Verification and boundaries

```sh
bundle exec ruby test/sales_summary_test.rb
bundle exec ruby test/conditions_test.rb
bundle exec ruby test/generate_test.rb
bundle exec ruby test/log_filter_test.rb
bundle exec ruby bin/verify_release
```

[CI](.github/workflows/smoke.yml) verifies the public RubyGems source, version and cached package SHA-256, patched
host dependencies, business/Handler tests, real HTTP Echo and continuation, and
production boot refusal. The independent [Client demo](https://github.com/cuichangquan/a2a-rails-client-demo)
pins a specific Server commit and matching released Gem for isolated real TLS tests.
See the Client workflow for its exact current pin and verification result.
No Client HTTPS, destination or certificate protections are weakened in runtime.
Rails parameter logging filters the whole SendMessage `message`, including
original inputs and answers. Questions/errors use fixed demo explanations.

These demos have no durable storage, queue, trusted identity verifier, business
authorization, distributed rate limit, exactly-once business execution guarantee,
or deployment approval. No SSE, push, AUTH_REQUIRED, OAuth, AP2 extension or
public internet service is added. See the Gem's SDK-boundary and continuation
design/upgrade guides for core contracts. A passing demo is not full A2A
conformance certification.

## Published-package verification and pin maintenance

`bin/verify_release` performs local checks only: RubyGems source (not Git/path),
version 0.5.1, installed cached `.gem` SHA-256, Rails 8.1.4.1 and existing json /
net-imap bounds, and the temporary regexp_parser pin. The exact public checksum is:

```
c0848ea37d772dabc628b6e2b3be88187f5aeebea6d5107a3d5f81108085acb1
```

If the install cache is absent, reinstall the bundle before verification; the
checker does not fetch or silently bypass the checksum. Client CI pins this
Server's full commit SHA. A squash merge creates a different main SHA, so verify
the pinned commit remains fetchable and its tree matches main before deleting
its branch. If that cannot be retained, update Client's pin to the merged commit
and rerun TLS. This follow-up does not authorize merge, tag or deployment.

MIT.
