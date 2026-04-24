# Save Compatibility Scenarios

Core model first:

- a `Save` belongs to a user/profile
- a `Save` is associated with some `GameMeta`
- `GameMeta` describes the game identity/version/family relationship
- `GameHash` helps detect which installed game build the client is actually running

The hard part is that “what game is this save for?” is not always one stable answer. For moddable games and format-breaking updates, there are several distinct scenarios.

## Main Scenarios

1. Same game, same save format, different binary build.
- Example: bugfix patch, launcher rebuild, platform rebuild.
- Multiple hashes should map to one `GameMeta`.
- Saves should remain interchangeable.

2. Same game, new version, save format still compatible.
- Example: `1.2` can load `1.1` saves.
- Could be separate `GameMeta` entries in one family, but saves may still be valid across versions.
- Need a rule for “prefer latest compatible save” vs “exact version only”.

3. Same game, new version, save format breaks.
- Example: major update invalidates old saves.
- Must not present incompatible saves as valid for the current install.
- This is what `breaksSaveFormatFromPreviousVersion` is for.

4. Mod or total conversion based on a base game.
- Example: Skyrim modpack, Enderal, total conversion.
- Child `GameMeta` may inherit from a base game but diverge in compatibility.
- Need to know whether saves from base game are valid for child, child for base, or neither.

5. Mod variant with same executable hash but different content loadout.
- Very common problem.
- Hashing only the executable may not distinguish mod state.
- Saves may look “for Skyrim” but actually require a specific mod list.

6. Same logical game across platforms.
- Example: Windows/Linux/macOS builds, Steam/GOG.
- Save format may be compatible or not.
- Hashes differ, family may be same, but metadata may need platform/store dimensions if compatibility differs.

7. User has multiple installs that can open overlapping save sets.
- Example: vanilla Skyrim, lightly modded Skyrim, heavily modded Skyrim.
- Client may need ranking, not just yes/no matching.

## Important Edge Cases

1. False compatibility.
- Game launches, but save is subtly corrupted or partially degraded.
- Binary compatibility is not enough; some mods remove objects/scripts/data.

2. False incompatibility.
- Save is actually loadable, but metadata rules are too strict.
- Users lose access to valid saves.

3. Shared executable, different mod state.
- Two installs hash the same EXE but differ by plugins/modpack.
- Current model may collapse them incorrectly.

4. Save format break not tied to version order.
- A side branch or modpack version may break from base game, but not from its immediate parent.
- Linear “previous version” logic may be too weak.

5. Multiple parents in practice.
- A modpack may depend on base game plus a specific mod collection/version.
- Tree inheritance may not model this cleanly.

6. Save created with DLC/expansion enabled.
- Base game executable may load, but save really depends on DLC presence.
- Same issue as mods, just more official.

7. Hash collisions in identity strategy.
- Not cryptographic collisions necessarily, but identity collisions from hashing the wrong thing.
- EXE-only fingerprint is usually insufficient for moddable ecosystems.

8. Renamed or repackaged games.
- Different storefront/package, same actual game format.
- Need family-level normalization.

9. Imported legacy metadata mistakes.
- Old saves may be attached to a `GameMeta` that later turns out to be too broad or too narrow.
- Reassignment/migration paths matter.

10. Deleted or merged metadata.
- If a `GameMeta` is removed or merged, dependent saves and hashes need deterministic reassignment behavior.

## Likely Missing Dimensions In The Model

- platform/store
- DLC set
- mod list / modpack id
- load order signature
- game data/content manifest hash
- explicit compatibility rules beyond parent/previous-version booleans

## Practical Matching Strategies

1. Exact environment match.
- Best for moddable games.
- Match on richer fingerprint, not just EXE hash.

2. Compatible fallback.
- If no exact match, walk to compatible `GameMeta` in same family.

3. Family-only fallback.
- Dangerous for moddable games.
- Should probably be opt-in or low-confidence.

4. User override.
- Let advanced users view “probably compatible” or “all family saves”.

## Good Questions To Decide Next

1. Is `GameHash` meant to identify only the executable, or the whole game environment?
2. Do you want exact-match behavior first, or broad recoverability first?
3. Should modded installs be first-class `GameMeta` entries, or separate environment fingerprints attached to one `GameMeta`?
4. Is compatibility directional?
- Example: old save loads in new version, but new save does not load in old version.
5. Do you want confidence levels in matching instead of binary match/no-match?

## Main Conclusion

Executable-hash-to-game mapping is enough for simple games, but not enough for moddable games. The biggest edge case cluster is “same game binary identity, different content environment.”
