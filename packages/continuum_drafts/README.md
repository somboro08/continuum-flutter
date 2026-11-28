# continuum_drafts

Framework-neutral draft persistence and autosave for Continuum. The package does not depend on Flutter or a form library; applications connect their own form state to **DraftSession**.

## Basic usage

~~~dart
final repository = DraftRepository(store: store);
final session = DraftSession(
  repository: repository,
  formId: 'registration',
  schema: DraftSchema(version: 1),
  fields: {
    'name': DraftFieldDefinition(id: 'name'),
    'email': DraftFieldDefinition(
      id: 'email',
      sensitivity: DraftFieldSensitivity.personal,
    ),
    'password': DraftFieldDefinition(
      id: 'password',
      sensitivity: DraftFieldSensitivity.secret,
    ),
  },
);

final autosave = DraftAutosaveController()
  ..register(session);

// Restore before binding values to the UI.
await session.restore();

// Update from any form framework; nearby edits are coalesced.
await session.updateField('name', 'Ada');
await session.updateFields({
  'name': 'Ada Lovelace',
  'email': 'ada@example.com',
});

final result = await autosave.checkpointNow();
if (!result.isSuccessful) {
  // Inspect result.failed; each failure includes the form ID and stack trace.
}

await autosave.dispose(flushPending: true);
~~~

## Privacy

- Only **ordinary** fields are persisted by default.
- **personal** fields require an explicit allow-list in DraftPrivacyPolicy.
- **secret**, **oneTimeCode** and **payment** fields are always excluded.
- Fields must be explicitly declared before they can be persisted.
- Do not place passwords, OTPs, payment credentials or authentication tokens in draft values.
- The file storage adapter is not encrypted. Use a suitable secure-storage strategy for any data that requires encryption.

## Schema evolution

Every form declares a positive schema version. When a form changes, supply sequential DraftMigration functions for each supported version transition. Missing migrations and drafts created by newer schemas are reported as typed DraftExceptions; old data is not silently discarded.

## Expiration and submission

Pass a TTL to a session or repository save to expire old drafts. Expired records are deleted when loaded. Call session.afterSuccessfulSubmission() only after the server confirms success; by default it removes the persisted draft and clears in-memory values.

## Autosave and concurrency

DraftAutosaveController uses Continuum's CheckpointScheduler to debounce and coalesce edits. An edit arriving during an active write remains dirty and is persisted by a subsequent checkpoint. Checkpoint results report per-form failures. Dispose with flushPending: true when pending edits should be attempted before releasing the controller.

Draft persistence is best-effort. Save meaningful changes continuously; do not rely on a final lifecycle callback before process termination.
