# Distributed Message-Bus Research for DataEngine, ExecEngine, and Trader (SYM-6)

## Goal

Evaluate how to run `DataEngine`, `ExecutionEngine`, and `Trader` as separate processes while preserving current behavior guarantees (message ordering, deterministic processing where needed, and operational safety).

## Scope and Non-Goals

### In scope

- Cross-process communication for:
  - Data flow to and from `DataEngine`
  - Command/event flow to and from `ExecutionEngine`
  - Strategy and control flow in `Trader`
- Transport and protocol options
- Reliability, ordering, idempotency, and observability design
- A phased migration path with validation gates

### Out of scope

- Multi-region active-active design
- Replacing all internal in-process message handling immediately
- Full redesign of model/event schemas in this ticket

## Current Architecture Constraints (Observed)

The current implementation and docs indicate a single-node runtime boundary and mostly in-process messaging:

- The architecture guide defines the system boundary as a single Nautilus node (single trader instance).
- `MessageBus` supports `send/request/response/publish` in process, with endpoint handler dispatch in memory.
- `DataEngine` and `ExecutionEngine` register local endpoints (`DataEngine.*`, `ExecEngine.*`) directly on the in-process bus.
- `LiveDataEngine`, `LiveRiskEngine`, and `LiveExecutionEngine` already isolate work behind async queues, which provides a natural seam for externalization.
- `MessageBusConfig` already supports a Redis-backed external stream path (`database`, `external_streams`), and `TradingNode` can subscribe to external streams and republish internally.

Implication: there is already partial infrastructure for external publish/consume, but endpoint-style request/response and strict component ownership are still designed around a single process.

## Option Comparison

### Option A: Redis Streams-first extension (incremental from current config)

Use existing Redis message-bus backing and extend it from topic-level pub/sub toward component command/reply contracts.

Pros:

- Reuses existing `MessageBusConfig` and Redis backing concepts.
- Lowest immediate implementation delta inside Nautilus.
- Familiar operations path for teams already using Redis in live deployments.

Cons:

- Request/reply and consumer-group semantics become app-managed complexity.
- Harder to enforce strict per-key ordering and replay guarantees across all flows.
- Backpressure and lag recovery need additional discipline as traffic grows.

Best fit:

- Fastest path to a pilot.
- Moderate throughput / single-cluster deployments.

### Option B: NATS JetStream + service subjects (recommended)

Adopt NATS for low-latency messaging plus JetStream for durable streams/replay; map component APIs to subject namespaces.

Pros:

- Very low latency and simple operational model for service-style messaging.
- Native request/reply and queue groups reduce custom infrastructure code.
- Durable replay and retention through JetStream.
- Good fit for command/event/data hybrid traffic.

Cons:

- New broker/runtime dependency.
- Requires serialization contract standardization.
- Requires explicit dedupe/idempotency policy for at-least-once delivery.

Best fit:

- Real-time trading workloads where latency and operational simplicity both matter.
- Progressive migration from local bus to distributed bus.

### Option C: Kafka + stream-centric architecture

Treat all component interactions as durable event streams, with RPC-like control paths layered as needed.

Pros:

- Excellent durability and replay tooling.
- Mature partitioning and consumer-group scaling model.
- Strong ecosystem for audit and historical reconstruction.

Cons:

- Higher operational and cognitive overhead for request/reply flows.
- Typically higher end-to-end latency than NATS for control-plane interactions.
- More ceremony for small command-style messages.

Best fit:

- High-throughput, event-sourcing-heavy environments with strong replay/audit requirements.

## Recommendation

Use **Option B (NATS JetStream)** as the primary target architecture, with one pragmatic caveat:

- If a near-term pilot must minimize implementation risk, use Option A (Redis extension) as a short-lived stepping stone only for Phase 1/2.
- Keep protocol contracts transport-agnostic so Redis pilot artifacts can move to NATS without redesigning message schemas.

Rationale:

- This workload mixes command, event, and data flows.
- `Trader` and `ExecutionEngine` interactions require request/reply and low latency.
- `DataEngine` flows benefit from durable replay but do not require Kafka-level ecosystem complexity for initial distributed rollout.

## Proposed Target Architecture

### Process topology

- Process 1: `Trader` domain process
  - Strategies, portfolio interactions, orchestration
  - Publishes commands and consumes events/data from remote engines
- Process 2: `DataEngine` process
  - Owns data client subscriptions, market data normalization, and data fan-out
- Process 3: `ExecutionEngine` process
  - Owns execution client routing, order lifecycle handling, and reconciliation

### Message contract model

Use a unified envelope for all inter-process messages:

- `message_type`: command | event | data | response
- `schema_version`
- `message_id`
- `correlation_id` (for request/reply)
- `causation_id` (optional chain tracing)
- `producer_component`
- `ts_event_ns`
- `partition_key` (for ordering domain, such as `instrument_id` or `client_order_id`)
- `payload` (serialized domain object)

### Suggested subject/topic namespaces

- `cmd.data_engine.*`
- `cmd.exec_engine.*`
- `cmd.trader.*`
- `evt.data_engine.*`
- `evt.exec_engine.*`
- `evt.trader.*`
- `data.market.*`
- `rep.data_engine.*`
- `rep.exec_engine.*`
- `health.*`

### Ordering and delivery rules

- Delivery model: **at least once**.
- Ordering guarantee:
  - Preserve in-order handling per `partition_key` (not global ordering).
  - Use stable partition routing for key domains:
    - Market-data updates by `instrument_id`
    - Execution updates by `client_order_id` / `venue_order_id`
- Deduplication:
  - Consumers keep short-lived dedupe cache by `message_id`.
  - Stateful consumers apply idempotent upsert semantics where possible.

### Failure handling

- Broker unavailable:
  - Component enters degraded state and emits health/error events.
  - Critical command flows fail fast with explicit operator-visible error.
- Consumer lag:
  - Export lag metrics and trigger alert thresholds.
  - Apply bounded replay windows and dead-letter handling for poison messages.
- Component restart:
  - Recover subscriptions, replay from last durable offset/checkpoint, and rebuild local state where needed.

## Mapping from Current APIs to Distributed Contracts

### DataEngine

- Existing local endpoints:
  - `DataEngine.execute`
  - `DataEngine.process`
  - `DataEngine.request`
  - `DataEngine.response`
  - `DataEngine.process_historical`
- Distributed mapping:
  - `cmd.data_engine.execute`
  - `evt.data_engine.processed` or `data.market.*`
  - `cmd.data_engine.request` + `rep.data_engine.response`

### ExecutionEngine

- Existing local endpoints:
  - `ExecEngine.execute`
  - `ExecEngine.process`
  - plus live reconciliation endpoints
- Distributed mapping:
  - `cmd.exec_engine.execute`
  - `evt.exec_engine.order.*`
  - `rep.exec_engine.query.*` for request/reply style reports

### Trader

- Keep strategy-facing API stable.
- Replace local endpoint assumptions with transport adapter calls:
  - local mode: in-process `MessageBus`
  - distributed mode: broker transport adapter

## Rollout Plan

### Phase 0: Contract definition and adapter interfaces

- Freeze initial envelope schema (`v1`).
- Define transport adapter interface:
  - `publish(topic, msg)`
  - `request(topic, msg, timeout)`
  - `subscribe(topic, handler, group)`
- Add compatibility tests for in-process and distributed adapters.

### Phase 1: DataEngine externalization

- Move `DataEngine` to a separate process first.
- Keep `Trader` + `ExecutionEngine` colocated.
- Validate data latency, ordering, and replay behavior under reconnect/restart.

### Phase 2: ExecutionEngine externalization

- Split `ExecutionEngine` into its own process.
- Introduce strict idempotency checks for order/event processing.
- Validate reconciliation and external order-claim behavior after restarts.

### Phase 3: Trader-only control plane and hardening

- Finalize `Trader` as orchestration process.
- Add production guardrails:
  - heartbeat and liveness topics
  - SLOs for publish-to-handle latency
  - dead-letter queues/streams
  - runbooks for replay and recovery

## Validation Strategy

### Functional validation

- Command round-trip:
  - `Trader -> ExecEngine -> response/event` correlation is preserved.
- Data flow:
  - `DataEngine` outputs are consumed by `Trader` subscribers with expected ordering by key.
- Restart behavior:
  - kill/restart one process at a time and verify no unrecoverable divergence.

### Reliability validation

- Duplicate delivery simulation:
  - verify idempotent handling and no duplicate business side effects.
- Lag injection:
  - verify backpressure visibility and recovery within SLO bounds.
- Broker outage drill:
  - verify safe degradation and explicit operator signals.

### Performance validation

- Measure p50/p95/p99 latency for:
  - command-to-handle
  - request-to-response
  - market data fan-out
- Track throughput and queue/consumer lag under representative load.

## Risks and Mitigations

- Risk: contract drift across Python/Rust boundaries.
  - Mitigation: versioned schemas, compatibility tests, and explicit decoder error metrics.
- Risk: hidden coupling to in-process ordering assumptions.
  - Mitigation: identify/order by explicit keys and enforce consumer serialization per key.
- Risk: operational burden from new broker infrastructure.
  - Mitigation: phased rollout, infra templates, and operational runbooks before full cutover.

## Decision Summary

- Recommended target: **NATS JetStream** transport with transport-agnostic contract adapters.
- Incremental fallback: Redis-stream-based pilot only if schedule pressure is high.
- Rollout order: **DataEngine first**, then **ExecutionEngine**, then full trader-orchestrated distributed mode.
