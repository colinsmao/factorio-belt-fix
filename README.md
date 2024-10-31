Attempts to revert 'smart' belt building behaviour to 1.1 off state, specifically disabling the auto-building of undergrounds when building past an obstacle. Can also enable the building over of belts and undergrounds oriented in different directions.

Demo vid: [youtube](https://youtu.be/ukCe15XvwKo)

Cannot change the "build in a line" logic, since that isn't exposed to the modding interface. But personally, I was more annoyed by the random undergrounds appearing.

Issues:
- Underground replacement works by detecting when (pairs of) undergrounds are built, while the player is holding transport-belt, and replacing them with belt. However, this means that if the player has no underground belts in their inventory, there will be a 'Missing underground belts' alert, and the regular belts will also fail to be placed.
- Due to it being a script replacing undergrounds/belts, it does not play that well with the undo function. Some actions can be undone, but others are buggy. Ghostly undergrounds sometimes appear when undoing.
- Works properly in Factorio 2.0.11. Currently, Factorio 2.0.12 (and 13) have issues with smart belt placing in the base game ([forum link](https://forums.factorio.com/viewtopic.php?f=7&t=118421)).
<!-- - Since this relies on the undergrounds being placed first, the placement of intermediate belts is delayed until you have built past the obstacle. This mostly affects belts, with the replace-belts option turned on, since you usually cannot place belts over other obstacles anyways.
  - Overwritten belts in undesired orientations will not be replaced until an underground can be placed. And since undergrounds have length limits, this results in cases where the underground is never placed, and the belt building halts prematurely.
- Currently, underground belt `on_build_entity` event firing is buggy ([forum bug report](https://forums.factorio.com/viewtopic.php?f=7&t=118559)). There is no way to distinguish between building forward with belts and building backward with belts. -->
  <!-- - This means you cannot build backwards (against the direction of the belt) over obstacles, since the replacement belts will be in the wrong direction.
  - I also cannot find a way of getting the direction items in the player's cursor are facing, so I cannot use that to check direction either. -->
<!-- - Since this mod relies on the undergrounds being placed first, and then being replaced by regular belt, if the player has no underground belts in their inventory, there will be a 'Missing underground belts' alert, causing regular belts to fail to be placed. -->

