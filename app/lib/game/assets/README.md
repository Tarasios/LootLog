# lib/game/assets/

Asset-key registry for the game layer. Every visual goes through an asset key
of the form `category.subject.variant.state`, rendered by `GameSprite`; a key
with no art renders as its text/ASCII card. The image files themselves live in
`app/assets/game/` per `docs/art-assets.md` (§9 lists every key an artist can
fill).

| File | Pure? | What |
|------|-------|------|
| `asset_key.dart` | yes | `AssetKey`: parse/validate, fallback chain, `snakeSegment`, `displayName`. |
| `asset_catalog.dart` | yes | `GameAssetKeys`: the vocabulary (buildings by tier, materials, chests, regions, heroes, gear, bosses, currency, UI panels, homestead, dungeon). |
| `asset_registry.dart` | yes | `AssetRegistry`: key -> file lookup along the fallback chain; `bundled` (legacy dungeon filenames) and `discover` (key-named files from the asset manifest). |
| `text_sprite.dart` | yes | `textSpriteFor(key)`: the text-mode tier — ASCII emblem, title, badge. |
| `game_asset_scope.dart` | Flutter | `loadGameAssetRegistry`, `gameAssetRegistryProvider`, `AdventureSpriteScope`. |

## Key convention

- Four dot-separated segments, each lower snake_case starting with a letter:
  `building.lumberyard.t2.idle`, `chest.gold.open.idle`,
  `region.subscription_swamp.banner.idle`.
- `category` — what kind of thing (`building`, `chest`, `material`, `region`,
  `hero`, `gear`, `boss`, `currency`, `ui`, `homestead`, `dungeon`).
- `subject` — which one (`lumberyard`, `gold`, `ore`, `old_roads`).
- `variant` — which look (`t1`..`t5`, `closed`/`open`, `icon`, `banner`,
  `default`).
- `state` — what it is doing (`idle` is always the fallback; `constructing`,
  `enraged`, `defeated`, ...). A state must not itself end in `_<N>f`.

Lookup walks `key -> variant at idle -> default variant at this state ->
default.idle`; it never crosses subject or category. Nothing on the chain ⇒
the text card.

## Using it from a screen

```dart
// Wrap a screen shown in both tiers once, near its root:
AdventureSpriteScope(child: GuildHallScreen(...));

// Then anywhere below it:
GameSprite.fromKey(GameAssetKeys.building(BuildingType.forge, 3));
GameSprite.fromKey(GameAssetKeys.chest(ChestType.gold, open: true), scale: 3);
GameSprite.fromKey(GameAssetKeys.heroPortrait,
    label: member.name,
    customSpriteSha256: member.customSpriteSha256, // wins when decodable
    baseSize: kPortraitBaseSize,
    resolver: AssetSpriteResolver(customBlobs: blobs));

// Or carry the key in a read-model:
const SpriteRef.key(GameAssetKeys.dungeonCoin);
```

Render order: custom blob > registered pixel art (FilterQuality.none, integer
scale) > text card. In the text tier (`AdventureTier.text` from the scope or
`GameSprite.tier`) every sprite renders its text card and nothing is decoded.
Without a scope a sprite assumes the pixel tier and `AssetRegistry.bundled`
(the dungeon's pixel screens only appear in the pixel tier). Legacy
`SpriteRef.asset(filename)` refs still work and keep their grey initials
placeholder.
