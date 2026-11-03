# Beacon

Beacon is a private movement journal with family location sharing, live maps,
and trip-based movement heatmaps.

## Maps

The Map tab uses OpenStreetMap tiles through `flutter_map`; no API key or
billing account is required. The app displays OpenStreetMap attribution in the
map controls. The public `tile.openstreetmap.org` service is intended for
reasonable interactive use, not bulk downloads or guaranteed high-volume
production traffic. For a large launch, choose a tile provider with a service
plan or host tiles yourself.

The Map tab's Live mode shows your current fix and recent locations shared by
accepted family members. Heatmap mode uses saved trip GPS points and can be
filtered to the last week, month, or all recorded trips. Location sharing and
updates remain foreground-only.
