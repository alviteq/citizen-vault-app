# OwnKeep 5.0 feature restoration register

This register compares the earlier OwnKeep 5.0 product capabilities with the
current vault-first UI. It distinguishes missing functionality from features
whose models and repositories still exist but are no longer reachable or fully
presented.

Status:

- **Regressed** — previously visible/usable and removed by the UI rewrite.
- **Disconnected** — implementation remains, but normal navigation does not
  expose it clearly.
- **Partial** — reachable, but an important part of the workflow is incomplete.
- **Present** — available and connected; retain during restoration.

## P0 — Restore document intelligence and organization

| Capability | Current status | Required restoration |
| --- | --- | --- |
| Full OCR/extracted text | **Regressed** | Restore the per-document **OCR text** section with page separation, copy, search-within-document, and clear “no text found”/OCR failure states. |
| Extracted fields | **Partial** | Fields are displayed, but editing/reconfirmation, provenance, confidence and evidence highlighting need to remain available after initial review. |
| Tags on document detail | **Regressed** | Restore visible tag chips and add/edit/remove actions on Document Detail. Keep existing normalized encrypted tag repository and library tag filter. |
| Document categories | **Partial** | Replace the UI-only incomplete mapping. Employment, Legal, Certificates, Family, Photos and Notes currently map to no document types and therefore return empty results. Define durable category-to-type mapping and counts. |
| Document type editing | **Partial** | Allow changing a wrongly classified type from Document Detail and re-index search without rerunning import. |
| Reminders on document detail | **Regressed** | Restore active reminder list, add reminder, expiry-offset presets, custom date/time, edit, snooze, complete and delete. |
| Linked records | **Regressed** | Restore **Linked to** on Document Detail and allow linking/unlinking People, Things, Places and organisations. |
| Processing/integrity detail | **Regressed** | Restore status, integrity result, OCR history and safe retry/reprocess actions. Never expose internal paths. |
| File metadata | **Partial** | Show actual MIME/type, encrypted size, added/updated dates and page count where known; the current UI only shows broad “PDF/Image”. |

## P0 — Reconnect People, Things and Places

The encrypted graph and screens still exist, including `EntityDirectoryScreen`,
`LifeNavigatorScreen`, entity templates, relationships, claims and events. They
are not discoverable enough in the current mobile shell.

| Capability | Current status | Required restoration |
| --- | --- | --- |
| People directory | **Disconnected** | Add Home/Records entry points and a browse page with People, Family and Pets. Preserve Add → Person. |
| Things directory | **Disconnected** | Add a grouped Things view for Vehicles, Properties, Devices, Appliances, Policies, Accounts, Subscriptions, Warranties and Other. |
| Places directory | **Disconnected** | Add Places/Properties browse, search and detail entry points. |
| Person profile | **Partial** | Restore linked documents, important dates, relationships, contact attributes, timeline and reminders in one profile. |
| Vehicle profile | **Partial** | Restore documents, insurance, registration, service history, expenses, upcoming dates and linked owners. |
| Property profile | **Partial** | Restore deeds, tax, utilities, insurance, receipts, photos, appliances, people and history. |
| Generic entity detail | **Partial** | Every entity type needs a useful summary, linked records, attributes, relationships, events and archive state. |
| Relationships | **Disconnected** | Make person↔person, person↔thing and place↔thing relationships editable in consumer language. |
| Automatic linking suggestions | **Partial** | During review, suggest existing entities from extracted names, registration numbers, addresses, policy holders and issuers; require confirmation. |

## P1 — Search, browse and discovery

| Capability | Current status | Required restoration |
| --- | --- | --- |
| Global OwnKeep search | **Disconnected** | Home search should open the existing graph-aware search and return Documents, People, Things, Places, extracted values, reminders, tasks and events. |
| Record search | **Present** | Keep encrypted FTS document search and ensure OCR text, confirmed fields, filename, category and tags are indexed. |
| Browse People/Things/Places | **Disconnected** | Add a secondary **Browse** destination from Home rather than adding more bottom tabs. |
| Category counts | **Missing** | Show real counts and hide/disable empty categories without falsely implying records are absent. |
| Tag management | **Partial** | Add a tag manager: rename, merge, delete unused tags and show record counts. |
| Recent searches | **Missing** | Store locally in the encrypted database, support clear-history and never sync. |
| Search result deep links | **Partial** | Every result must open its document, entity, reminder, task or timeline event directly. |

## P1 — Timeline, attention and useful automation

| Capability | Current status | Required restoration |
| --- | --- | --- |
| Global timeline | **Disconnected** | Expose from Home as **Activity/Timeline** and keep it secondary to the vault. |
| Entity history | **Partial** | Filter timeline by person/vehicle/property/place and show linked documents, renewals, payments and service events. |
| Needs Attention | **Partial** | Present Expiring, Review, Tasks, Reminders, Missing Evidence and Integrity in plain consumer language. |
| Tasks | **Disconnected** | Reconnect task list and entity/document deep links. |
| Smart suggestions | **Partial** | Surface reminder, linking, category and event suggestions contextually in Inbox/Review instead of only in advanced screens. |
| Ask OwnKeep | **Disconnected** | Add a Home entry and retain evidence/source links while avoiding internal graph terminology in normal UI. |

## P1 — Capture and review completeness

| Capability | Current status | Required restoration |
| --- | --- | --- |
| Multi-page scan | **Partial** | Verify capture, crop, rotate, reorder, delete/retake, enhancement and final multi-page output on hardware. |
| Immediate secure-save feedback | **Partial** | Clearly separate **Encrypted and saved** from later OCR/classification processing. |
| Review preview | **Partial** | Show page/image preview beside extracted fields and allow zoom to verify values. |
| Review linking | **Partial** | Add confirmed **Link to** selection and create-new entity without leaving the review. |
| Review category/tags | **Missing** | Confirm category and initial tags before completing review. |
| OCR language per document | **Partial** | Keep global default, but allow retrying an individual document with another supported language/script. |
| Reprocess document | **Missing** | Add safe local re-run for OCR/classification while preserving original and confirmed history. |

## P2 — Home and records presentation

| Capability | Current status | Required restoration |
| --- | --- | --- |
| Vault summary | **Partial** | Show record count, real category count, attention count and last successful backup date. |
| Recent records | **Present** | Retain document-first Home presentation and deep links. |
| Upcoming reminders | **Present/Partial** | Keep upcoming list and add View all, snooze and completion actions. |
| Record thumbnails | **Partial** | Generate and cache bounded encrypted previews for images and PDF first pages; use stable loading/error placeholders. |
| List/grid preference | **Present** | Retain encrypted preference and instant update. |
| Sort/filter parity | **Partial** | Add Recent, filename, imported date, expiry, category, tags and type with correct empty states. |

## P2 — Backup, settings and trust indicators

| Capability | Current status | Required restoration |
| --- | --- | --- |
| Last backup state | **Missing** | Persist successful verified backup date and object count in encrypted settings and display on Home/Settings. |
| Recovery setup completion | **Partial** | Add an explicit post-create recovery acknowledgement/checklist. |
| OCR settings | **Present** | Retain independent interface and OCR language settings with capability labels. |
| Storage/trash | **Present** | Retain measured storage, safe temporary cleanup, archive and recoverable trash. |
| Permanent deletion | **Missing** | Add explicit destructive purge after retention checks, including reminder/search/graph cleanup and object reference verification. |

## Restoration sequence

### Phase 14 — Document Detail parity

Restore tags, complete OCR text, reminders, full metadata, integrity/history and
type editing. This is the highest-value regression because users already have
documents but cannot see or manage all intelligence attached to them.

### Phase 15 — Categories and tag system

Move categories into durable domain mapping, complete every category, add
counts, category/type editing and a tag manager with rename/merge/delete.

### Phase 16 — People, Things and Places

Reconnect browse/navigation, complete entity profiles and expose linked
documents, attributes, relationships, reminders and history.

### Phase 17 — Document-to-entity linking

Restore manual links and add review-time linking suggestions with confirmation,
stable identifiers and searchable bidirectional navigation.

### Phase 18 — Global search and timeline

Connect Home search to graph-aware results and expose secondary Activity,
Attention, Tasks and Ask OwnKeep entry points.

### Phase 19 — Capture/review intelligence

Complete multi-page scanning QA, page preview, per-document OCR retry,
category/tags/link confirmation and safe reprocessing.

### Phase 20 — Home summaries and lifecycle polish

Add backup status, accurate category counts, thumbnail caching, permanent
deletion with retention checks and final cross-feature integration tests.

## Non-regression rule

The vault-first navigation remains:

`Home | Records | + Add | Inbox | Settings`

People, Things, Places, Timeline and Ask OwnKeep return as linked organization
and discovery layers. They must not replace the document-first product identity,
and restoring them must not weaken encryption, offline operation, recovery or
the fail-closed export boundaries.
