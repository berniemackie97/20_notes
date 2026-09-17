# Server Schema Compatibility (`conquer.sql`)

Server-side schema facts verified from the workspace backup:

- source: `conquer.sql`
- relevant retail table: `cq_user`
- relevant retail membership tables: `cq_family_attr`, `cq_synattr`
- optional extension table: `map_ground_items`

## `cq_user` evidence

Verified from the `CREATE TABLE cq_user` block in `conquer.sql`:

- present columns consumed by the managed server:
  - `account_id`
  - `name`
  - `mate`
  - `lookface`
  - `hair`
  - `recordmap_id`
  - `recordx`
  - `recordy`
  - `level`
  - `profession`
  - `first_prof`
  - `old_prof`
  - `metempsychosis`
  - `mete_lev`
  - `strength`
  - `Speed`
  - `health`
  - `soul`
  - `additional_point`
  - `life`
  - `mana`
  - `money`
  - `money_saved`
  - `coin_money`
  - `emoney`
  - `emoney2`
  - `exp`
  - `pk`
  - `selected_title`
  - `virtue`
  - `professor_points`
  - `study_points`
  - `enlight_points`
  - `god_status`
  - `time_of_life`
  - `auto_allot`
  - `exp_multiply`
  - `exp_expires`
  - `last_login`
  - `last_logout`
  - `lock_key`
  - `home_id`
  - `auto_exercise`
  - `donation`
  - `nobility`
  - `flower_r`
  - `flower_w`
  - `flower_lily`
  - `flower_tulip`
  - `syndicate_id`
- absent columns that older server mappings assumed:
  - `stamina`
  - `vip`
  - `family_id`
  - `family_rank`
  - `family_joining_date`
  - `syn_rank`
  - `syn_position`
  - `syn_join_date`

## `cq_family_attr` and `cq_synattr` evidence

Verified from the `CREATE TABLE` blocks in `conquer.sql`:

- `cq_family_attr`
  - `id`
  - `family_id`
  - `money`
  - `rank`
  - `join_date`
- `cq_synattr`
  - `id`
  - `syn_id`
  - `rank`
  - `proffer`
  - `proffer_total`
  - `emoney`
  - `emoney_total`
  - `join_date`

These are the retail-backed sources for family and syndicate membership state. `cq_user` only carries `syndicate_id`; it does not carry the rest of the membership metadata.

## Managed server consequence

- `CqUserEntity` is the direct EF mapping for `cq_user`.
- `CqUserEntity` now maps only real `cq_user` columns. No `[NotMapped]` compatibility placeholders remain in the table entity.
- `CqUserCharacterRepository` projects family membership from `cq_family_attr` and syndicate membership from `cq_synattr` when building the domain `Character`.
- `FamilyPosition`/`SyndicatePosition` currently alias the stored membership `rank` value, because the retail membership tables expose a single office/rank scalar and no separate position column.
- `stamina` and `vip` are not persisted by the current retail schema. The managed server leaves them at domain defaults until an explicit extension schema is introduced and wired deliberately.

## `map_ground_items` evidence

Verified from the workspace backup:

- `conquer.sql` contains no `CREATE TABLE map_ground_items`.
- retail-compatible startup/login must therefore not assume that ground-item persistence exists.

Managed server consequence:

- retail/default runtime now uses an in-memory map-item repository selected at startup via `GameServer:MapItems:PersistenceMode = InMemory`.
- no runtime probing or exception-driven table detection remains in the production path.
- `map_ground_items` is now an explicit extension-only persistence mode (`MapGroundItemsTable`), not something the retail/default path silently depends on.

## Optional extension script

If persistent ground-item storage is desired on top of the retail schema, use:

- `50_server/OpenConquer5517v3/db/optional_map_ground_items.sql`

This extension is optional and is **not** required for login/bootstrap parity.
