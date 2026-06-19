# storage_models

Domain models persisted to MongoDB. Each model:

- Extends `MongoModel<T>` (hard delete) or `MongoFlagDeleteModel<T>` (soft delete
  via a `deleted` flag).
- Implements `toPropertiesMap()`, a `fromMap` factory, and `updateProperties()`.
- Exposes a static `MongoStorageModel<T> storage` describing its collection.

Register each model's `storage` in the `collectionModels` list in
`routes/v1/[collection].dart` to automatically expose CRUD at
`/v1/{collectionId}`.

## Lamb Champs models to build (Phase 1)

| Model             | Collection           | Notes                                              |
| ----------------- | -------------------- | -------------------------------------------------- |
| `UserModel`       | `users`              | email = Firebase join key; role; assigned groups   |
| `AnimalModel`     | `animals`            | Excel import/export; upsert on `_id`               |
| `GroupModel`      | `groups`             | judges, super judges, `top_x_advance`              |
| `CriteriaModel`   | `judging_criteria`   | dynamic categories, sub-attributes, weights        |
| `ResultModel`     | `judging_results`    | one doc per animal per judge; weighted total       |
| `RoundConfigModel`| `round_config`       | current round, advancement state                   |
| `LeaderboardModel`| `leaderboards`       | cloud-computed per round/group averages + ranks    |
