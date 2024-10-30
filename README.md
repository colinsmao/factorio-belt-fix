Reverts 'smart' belt building behaviour to 1.1 off state, ie does not build undergrounds when building past an obstacle.

Cannot change the "build in a line" logic, since that isn't exposed to the modding interface. But personally, I was more annoyed by the random undergrounds appearing.

Works by detecting when (pairs of) undergrounds are built, while the player is holding transport-belt. In which case it replaces the undergrounds with belt. However, this has some issues:
- Currently, underground belt on_build_entity event firing is buggy: [forum bug report](https://forums.factorio.com/viewtopic.php?f=7&t=118559)
  - This means you cannot build backwards (against the direction of the belt) over obstacles, since the replacement belts will be in the wrong direction.
- Since this mod relies on the undergrounds being placed first, and then being replaced by regular belt, if the player has no underground belts in their inventory, there will be a 'Missing underground belts' alert, causing regular belts to fail to be placed.
