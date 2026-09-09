# Quiet news and moving boats — 1.6.2

The news tray is silent. It accepts royal weddings, war declarations, peace, alliances, conquests, civil wars and revolutions. Ordinary marriages still update both spouses' families and personal histories, but no longer enter the global event stream. Routine personal actions, laws, technology changes, disasters and expiring agreements do not create news notices. The Chronicle remains available for wider history. A peace treaty supplies the headline instead of duplicating the accompanying war-ended event.

Royal weddings include rulers and their children. News cards still link to the actual people involved. The settings description states which events appear; world and battle audio remain independent of news.

Fishing boats previously traversed one tile over roughly 23 seconds. They now follow a bounded local water route at 0.65 tiles per second. Cargo travels at 1.1 and naval fleets at 0.9 tiles per second. Boats return along their connected route, and wakes follow their heading. Static fallback warships are omitted when actual transport missions exist. Existing short fishing routes are extended on load, without granting food or consuming simulation randomness.

Route planning happens once per town per year, with at most 192 visited nodes inside an eight-tile radius. Rendering interpolates the existing route and does no pathfinding. Long sea-route reconstruction is linear in path length. Very small ponds without a usable route do not spawn a moving fishing boat.

Validated with 273 living-world checks (including silent arrivals, major-event filtering, clickable participants, water-only routes, visible motion and save migration), 2,582 society checks (including ordinary and royal marriage behavior), and 287 power/save checks. Graphical before/after captures show boat movement over four seconds. The native Windows 1.6.2 executable launches and captures successfully.

The 12,000- and 20,000-person performance fixtures pass all 18 checks and preserve identical simulation outcomes; measured work-slice medians are 8.71 and 8.65 ms, maxima 15.48 and 15.20 ms on this PC. These are not phone measurements. This release has not received a new physical Android installation or touch/audio review.

The earlier 1,800-year exact-state continuation mismatch remains unresolved. Population and RNG continuation matched, but the whole-state comparison did not. No new endurance pass is claimed, and full distribution ZIP packaging remains gated.
