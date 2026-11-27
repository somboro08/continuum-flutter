# Roadmap

## Foundation
- [x] Core module contract and dependency ordering
- [x] Flutter lifecycle adapter
- [x] Storage port and persistence policies
- [x] Feature-owned recovery snapshots
- [ ] Unit tests and CI validation
- [x] In-memory store for tests and examples
- [x] Namespaced storage wrapper
- [x] File-system storage adapter with encoded keys and serialized operations

## Next
- [ ] Lifecycle checkpoint policy (debounce, throttling, explicit checkpoints)
- [x] Dependency-free file storage adapter
- [ ] Encrypted storage adapter (opt-in, separate package)
- [ ] Draft/form recovery participant
- [ ] Navigation restoration adapter
- [ ] Operation journal and idempotent resume safeguards

## Later
- [ ] Offline queue and conflict strategies
- [ ] Background scheduling adapters
- [ ] Keyboard/focus experience helpers
- [ ] Examples, documentation and package publishing
