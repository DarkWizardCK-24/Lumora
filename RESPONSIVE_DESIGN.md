# Responsive design

Layout decisions use **available logical width**, never device names (`core/utils/responsive.dart`).

| Layout | Width | Shell |
|---|---|---|
| Compact | < 600 | App bar + **bottom navigation** (Home · Learning · Planner · Insights · More). Less-used pages live under *More*. Quick-add is a bottom sheet. |
| Medium | 600–899 | Collapsed icon sidebar with tooltips + top bar. |
| Expanded | ≥ 900 | Full sidebar (collapsible, state persisted) + top bar (breadcrumb, global search, quick-add, sync status, notifications, profile). |

## Rules used throughout

- `AdaptiveGrid` sizes columns from the container width (`minTile`), with no fixed heights, so cards never clip.
- `PageBody` scrolls and caps content width on very wide screens; `PageHeader` and filter bars use `Wrap`.
- Long text uses `Expanded`/`Flexible` + ellipsis; stat values use `FittedBox`.
- Forms (`showForm`) are **bottom sheets** on phones (keyboard-inset aware, scrollable) and dialogs on wide screens.
- Empty states scroll instead of overflowing when their box is short.
- Calendar: month grid on wide screens with titled chips; dots + agenda on phones.
- Notes: master–detail on wide screens, list → full-screen editor on phones.
- Charts and tables are never reused unchanged on phones (e.g. lists replace `DataTable`).
- Mobile home order: start session → today's plan → KPI cards → next action → deadlines → progress → streak → charts.

## Verification

`test/responsive_test.dart` renders all 13 routes at 320, 360, 390, 430, 600, 768, 1024, 1366 and 1920 px wide, at 1× and 2× text scale, with an empty and a populated database, and fails on any layout exception. Landscape phones fall in the 600–900 band and are covered by the 600/768 widths.
