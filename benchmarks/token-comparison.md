# AME Token Benchmark — Measured Comparison

## Summary

AME syntax uses **1.62x fewer tokens** than A2UI v0.9 JSON on average across
five representative UI scenarios, as measured by the Gemini `gemini-2.0-flash`
tokenizer via the `countTokens` REST API. This confirms that AME's compact
line-oriented notation produces meaningfully smaller output than A2UI's
flat-component JSON format for equivalent UIs.

**GATE 1 Result: PASS** — A2UI/AME average ratio = 1.62x (threshold: ≥ 1.5x)

---

## Methodology

### What Was Measured

Token counts for five identical UIs, each written in three formats:

1. **AME** — line-oriented syntax per [syntax.md](../specification/v1.0/syntax.md)
2. **A2UI v0.9** — flat JSON component array per
   [A2UI v0.9 component reference](https://a2ui.org/reference/components/)
3. **Raw JSON** — naive nested JSON objects (baseline, not a competing spec)

### How Tokens Were Counted

All token counts were measured using the **Gemini REST API `countTokens`
endpoint** with model `gemini-2.0-flash`:

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:countTokens
```

Request body:
```json
{"contents": [{"parts": [{"text": "<test string>"}]}]}
```

Response field: `totalTokens` (integer)

No estimation, character counting, or heuristic approximation was used. Every
number in this document is a measured integer from the Gemini tokenizer.

### A2UI v0.9 Format Notes

The A2UI strings use the v0.9 format as documented at
[a2ui.org/reference/components/](https://a2ui.org/reference/components/),
including the `updateComponents` wrapper with `surfaceId` and flat `components`
array — this is what a real A2UI agent generates.

**Component parity gaps:** A2UI v0.9 does not have direct equivalents for
AME's `badge`, `progress`, or `spacer` primitives. Where AME uses `badge()`,
the A2UI equivalent uses a `Text` component with `variant: "caption"`. This
is the realistic approach a developer would take when A2UI lacks a dedicated
badge primitive.

A2UI's `Button` component requires a separate child `Text` component for its
label (the button references a text node by ID). This adds one extra component
per button compared to AME, where `btn("label", action)` is self-contained.
This structural overhead is a genuine cost of A2UI's design and is counted
accordingly.

Action arguments (tool parameters, URI values) are included in both AME and
A2UI strings to ensure equivalent functionality is being compared.

### Raw JSON Format Notes

The raw JSON format uses naive nested objects with `type`, `children`, `text`,
`style`, and `action` fields. This is a baseline representation — not a
competing specification — included to show where each format's overhead comes
from. Raw JSON lacks identifiers, streaming support, forward references, and
any specification structure.

### Reproducibility

The exact strings tokenized are included in the [Appendix](#appendix-exact-tokenized-strings)
below. Anyone with access to the Gemini `countTokens` API can reproduce
these results exactly.

### Tokenizer Scope

All measurements use the Gemini `gemini-2.0-flash` tokenizer via the
`countTokens` REST API. Other tokenizers (GPT-4o, Claude) use different
vocabulary tables and BPE merge rules. The 1.62x ratio is specific to the
Gemini tokenizer and may differ on other tokenizers. Community contributions
of cross-tokenizer benchmarks are welcome.

---

## Results

| UI Scenario | AME Tokens | A2UI v0.9 Tokens | Raw JSON Tokens | A2UI / AME | JSON / AME |
|-------------|-----------|-----------------|----------------|-----------|-----------|
| Weather Card (1 card, 5 fields) | 131 | 203 | 143 | 1.55x | 1.09x |
| Place Search (3 cards, 6 buttons) | 581 | 1,014 | 537 | 1.75x | 0.92x |
| Email Inbox (5 items, 3 badges) | 420 | 605 | 308 | 1.44x | 0.73x |
| Booking Form (4 inputs, 2 buttons) | 188 | 412 | 184 | 2.19x | 0.98x |
| Side-by-Side Comparison (2 cards, 6 rows) | 604 | 889 | 445 | 1.47x | 0.74x |
| **Total** | **1,924** | **3,123** | **1,617** | **1.62x** | **0.84x** |

### Key Observations

**AME vs A2UI v0.9 (the primary comparison):**

AME is 1.62x more compact than A2UI on average. The efficiency gain varies
by UI complexity:

- **Booking Form (2.19x):** The largest gap. A2UI's form components
  (`DateTimeInput`, `ChoicePicker`, `TextField`) require verbose JSON
  properties (`enableDate`, `enableTime`, `maxAllowedSelections`,
  `textFieldType`), data binding objects (`{"path": "/form/..."}"`), and each
  button needs a separate Text child component. AME's `input("date", "Date",
  date)` encodes the same information in a single compact line.

- **Place Search (1.75x):** Significant gap driven by button overhead. Each
  A2UI button requires two components (Button + child Text) vs AME's single
  `btn()` call. With 6 buttons across 3 cards, this adds 6 extra components
  (plus 6 extra `id` fields, 6 `component` declarations, and 6 `child`
  references). A2UI also requires an explicit `Column` inside each `Card`
  (A2UI Card has singular `child`, not a children array).

- **Weather Card (1.55x):** Moderate gap. The simpler the UI, the more the
  structural overhead (JSON boilerplate: `"id"`, `"component"`, etc.) is
  amortized by content. AME's line-oriented format has lower per-component
  overhead.

- **Email Inbox (1.44x):** The smallest gap. This UI has many similar
  repetitive elements with short content strings. A2UI's repetitive overhead
  (`"id"`, `"component"`, `"variant"`) accumulates but is partially offset by
  the lack of complex actions (no buttons in email items).

- **Comparison (1.47x):** Close to the email pattern. Repetitive key-value
  rows have similar overhead in both formats. A2UI's advantage from shorter
  component names (`Text` vs `txt`) is offset by its JSON boilerplate.

**AME vs Raw JSON (the baseline comparison):**

Raw nested JSON is 1.19x more compact than AME on average. This is expected
and by design — AME pays a ~19% token overhead for capabilities that raw JSON
lacks:

- **Identifiers** — every AME line has `identifier = ...`, consuming tokens
  for the name, equals sign, and whitespace. Raw JSON uses anonymous nesting.
- **Streaming** — identifiers enable forward references and progressive
  rendering. Raw JSON cannot stream (the entire nested structure must arrive
  before any node can be rendered).
- **Updatability** — identifiers allow individual nodes to be replaced by ID.
  Raw JSON requires regenerating the entire tree.

The 19% overhead is the cost of AME's streaming and addressability features.
For the scenarios where AME is used (LLM-generated streaming UI), this overhead
is justified by the dramatically improved user experience of progressive
rendering.

Notably, for the simplest UI (Weather Card), AME is actually more compact
than raw JSON (131 vs 143 tokens). AME's terse syntax (`txt("San Francisco",
title)`) beats JSON's verbose keys (`{"type":"txt","text":"San Francisco",
"style":"title"}`).

---

## Analysis

### Why AME Is More Compact Than A2UI

Three structural factors account for AME's token advantage over A2UI:

1. **No JSON boilerplate.** Every A2UI component requires `"id"`, `"component"`,
   and property keys in JSON syntax with quotes, colons, and commas. AME uses
   `identifier = component(args)` with no quoting on keywords.

2. **Self-contained interactive elements.** AME's `btn("Schedule", tool(...),
   primary)` is a single statement. A2UI requires two components: a `Button`
   referencing a child `Text` by ID, plus the child `Text` component itself.

3. **Positional arguments.** AME uses position to determine argument meaning:
   `txt("Hello", title)` vs A2UI's `{"text": "Hello", "variant": "h3"}`. Named
   JSON keys consume more tokens than positional ordering.

### Where A2UI Is Competitive

A2UI v0.9 is significantly more compact than v0.8 (which used deeply nested
wrappers like `{"component": {"Text": {"text": {"literalString": "..."}}}}}`).
The v0.9 format with flat props (`"text": "..."`) is a meaningful improvement.
For simple text-heavy UIs without actions, A2UI's overhead approaches AME's.

### Implications for Production Use

At the measured ratio of 1.62x, an application generating 10,000 UI responses
per day would save approximately 12,000 tokens per day using AME instead of
A2UI for an average-complexity UI. For the Place Search scenario (the most
representative of real assistant interactions), the savings per response are
1,014 - 581 = 433 tokens, or a 42.7% reduction.

These savings compound with Tier 0 rendering (see
[tier-zero.md](../specification/v1.0/tier-zero.md)), which eliminates UI
tokens entirely for the majority of tool-result interactions in
assistant-style apps.

---

## Appendix: Exact Tokenized Strings

The following are the exact strings that were passed to the `countTokens` API.
These can be used to reproduce the measurements.

### AME Strings

**AME Weather Card (131 tokens):**

```
root = card([weather_header, temp, condition, details])
weather_header = row([city, weather_icon], space_between)
city = txt("San Francisco", title)
weather_icon = icon("partly_cloudy_day", 28)
temp = txt("62°", display)
condition = txt("Partly Cloudy", body)
details = row([high_low, humidity], space_between)
high_low = txt("H:68°  L:55°", caption)
humidity = txt("Humidity: 72%", caption)
```

**AME Place Search (581 tokens):**

```
root = col([header, results])
header = txt("Italian Restaurants Nearby", headline)
results = list([p1, p2, p3])
p1 = card([p1_top, p1_addr, p1_btns])
p1_top = row([p1_name, p1_rating], space_between)
p1_name = txt("Luigi's", title)
p1_rating = badge("★4.5", info)
p1_addr = txt("119 Mulberry St, New York", caption)
p1_btns = row([p1_sched, p1_dir], 8)
p1_sched = btn("Schedule", tool(create_calendar_event, title="Dinner at Luigi's", location="119 Mulberry St"), primary)
p1_dir = btn("Directions", uri("geo:40.72,-73.99?q=Luigi's"), text)
p2 = card([p2_top, p2_addr, p2_btns])
p2_top = row([p2_name, p2_rating], space_between)
p2_name = txt("Joe's Pizza", title)
p2_rating = badge("★4.3", info)
p2_addr = txt("375 Canal St, New York", caption)
p2_btns = row([p2_sched, p2_dir], 8)
p2_sched = btn("Schedule", tool(create_calendar_event, title="Dinner at Joe's Pizza", location="375 Canal St"), primary)
p2_dir = btn("Directions", uri("geo:40.72,-74.00?q=Joe's Pizza"), text)
p3 = card([p3_top, p3_addr, p3_btns])
p3_top = row([p3_name, p3_rating], space_between)
p3_name = txt("Carbone", title)
p3_rating = badge("★4.7", info)
p3_addr = txt("181 Thompson St, New York", caption)
p3_btns = row([p3_sched, p3_dir], 8)
p3_sched = btn("Schedule", tool(create_calendar_event, title="Dinner at Carbone", location="181 Thompson St"), primary)
p3_dir = btn("Directions", uri("geo:40.73,-74.00?q=Carbone"), text)
```

**AME Email Inbox (420 tokens):**

```
root = col([inbox_header, email_list])
inbox_header = row([inbox_title, inbox_count], space_between)
inbox_title = txt("Inbox", headline)
inbox_count = badge("3 unread", info)
email_list = list([e1, e2, e3, e4, e5])
e1 = row([e1_info, e1_badge])
e1_info = col([e1_from, e1_subj])
e1_from = txt("Sarah Chen", title)
e1_subj = txt("Meeting tomorrow at 3pm", caption)
e1_badge = badge("New", success)
e2 = row([e2_info, e2_badge])
e2_info = col([e2_from, e2_subj])
e2_from = txt("Dev Team", title)
e2_subj = txt("Sprint review notes", caption)
e2_badge = badge("New", success)
e3 = row([e3_info, e3_badge])
e3_info = col([e3_from, e3_subj])
e3_from = txt("Alex Rivera", title)
e3_subj = txt("Updated design files", caption)
e3_badge = badge("New", success)
e4 = row([e4_info])
e4_info = col([e4_from, e4_subj])
e4_from = txt("Newsletter", body)
e4_subj = txt("Weekly digest - March 28", caption)
e5 = row([e5_info])
e5_info = col([e5_from, e5_subj])
e5_from = txt("AWS", body)
e5_subj = txt("Your monthly invoice is ready", caption)
```

**AME Booking Form (188 tokens):**

```
root = card([form_title, form_fields, form_actions])
form_title = txt("Book a Table", headline)
form_fields = col([date_field, time_field, guests_field, notes_field])
date_field = input("date", "Date", date)
time_field = input("time", "Time", time)
guests_field = input("guests", "Number of Guests", select, options=["1","2","3","4","5","6","7","8"])
notes_field = input("notes", "Special Requests", text)
form_actions = row([cancel_btn, confirm_btn], space_between)
cancel_btn = btn("Cancel", nav("home"), text)
confirm_btn = btn("Confirm Booking", submit(create_reservation, restaurant="Luigi's"), primary)
```

**AME Side-by-Side Comparison (604 tokens):**

```
root = col([comp_title, comp_row, comp_note])
comp_title = txt("Compare Plans", headline)
comp_row = row([plan_a, plan_b], 12)
plan_a = card([pa_name, pa_price, pa_details, pa_btn])
pa_name = txt("Basic Plan", title)
pa_price = txt("$15/month", display)
pa_details = col([pa_d1, pa_d2, pa_d3])
pa_d1 = row([pa_d1_k, pa_d1_v], space_between)
pa_d1_k = txt("Storage", caption)
pa_d1_v = txt("50 GB", body)
pa_d2 = row([pa_d2_k, pa_d2_v], space_between)
pa_d2_k = txt("Users", caption)
pa_d2_v = txt("1", body)
pa_d3 = row([pa_d3_k, pa_d3_v], space_between)
pa_d3_k = txt("Support", caption)
pa_d3_v = txt("Email only", body)
pa_btn = btn("Select Basic", tool(select_plan, plan="basic"), outline)
plan_b = card([pb_name, pb_price, pb_details, pb_badge, pb_btn])
pb_name = txt("Pro Plan", title)
pb_price = txt("$45/month", display)
pb_details = col([pb_d1, pb_d2, pb_d3])
pb_d1 = row([pb_d1_k, pb_d1_v], space_between)
pb_d1_k = txt("Storage", caption)
pb_d1_v = txt("500 GB", body)
pb_d2 = row([pb_d2_k, pb_d2_v], space_between)
pb_d2_k = txt("Users", caption)
pb_d2_v = txt("10", body)
pb_d3 = row([pb_d3_k, pb_d3_v], space_between)
pb_d3_k = txt("Support", caption)
pb_d3_v = txt("24/7 Priority", body)
pb_badge = badge("Recommended", success)
pb_btn = btn("Select Pro", tool(select_plan, plan="pro"), primary)
comp_note = txt("All plans include a 14-day free trial.", caption)
```

### A2UI v0.9 Strings

**A2UI Weather Card (203 tokens):**

```json
{"updateComponents":{"surfaceId":"weather","components":[{"id":"root","component":"Card","child":"content"},{"id":"content","component":"Column","children":["header","temp","cond","details"]},{"id":"header","component":"Row","children":["city","icon"],"justify":"spaceBetween"},{"id":"city","component":"Text","text":"San Francisco","variant":"h3"},{"id":"icon","component":"Icon","name":"cloud"},{"id":"temp","component":"Text","text":"62°","variant":"h1"},{"id":"cond","component":"Text","text":"Partly Cloudy"},{"id":"details","component":"Row","children":["hl","hum"],"justify":"spaceBetween"},{"id":"hl","component":"Text","text":"H:68°  L:55°","variant":"caption"},{"id":"hum","component":"Text","text":"Humidity: 72%","variant":"caption"}]}}
```

**A2UI Place Search (1,014 tokens):**

```json
{"updateComponents":{"surfaceId":"places","components":[{"id":"root","component":"Column","children":["header","results"]},{"id":"header","component":"Text","text":"Italian Restaurants Nearby","variant":"h2"},{"id":"results","component":"List","children":["p1","p2","p3"],"direction":"vertical"},{"id":"p1","component":"Card","child":"p1-content"},{"id":"p1-content","component":"Column","children":["p1-top","p1-addr","p1-btns"]},{"id":"p1-top","component":"Row","children":["p1-name","p1-rating"],"justify":"spaceBetween"},{"id":"p1-name","component":"Text","text":"Luigi's","variant":"h3"},{"id":"p1-rating","component":"Text","text":"★4.5","variant":"caption"},{"id":"p1-addr","component":"Text","text":"119 Mulberry St, New York","variant":"caption"},{"id":"p1-btns","component":"Row","children":["p1-sched","p1-dir"]},{"id":"p1-sched-text","component":"Text","text":"Schedule"},{"id":"p1-sched","component":"Button","child":"p1-sched-text","variant":"primary","action":{"event":{"name":"create_calendar_event","data":{"title":"Dinner at Luigi's","location":"119 Mulberry St"}}}},{"id":"p1-dir-text","component":"Text","text":"Directions"},{"id":"p1-dir","component":"Button","child":"p1-dir-text","action":{"event":{"name":"open_uri","data":{"uri":"geo:40.72,-73.99?q=Luigi's"}}}},{"id":"p2","component":"Card","child":"p2-content"},{"id":"p2-content","component":"Column","children":["p2-top","p2-addr","p2-btns"]},{"id":"p2-top","component":"Row","children":["p2-name","p2-rating"],"justify":"spaceBetween"},{"id":"p2-name","component":"Text","text":"Joe's Pizza","variant":"h3"},{"id":"p2-rating","component":"Text","text":"★4.3","variant":"caption"},{"id":"p2-addr","component":"Text","text":"375 Canal St, New York","variant":"caption"},{"id":"p2-btns","component":"Row","children":["p2-sched","p2-dir"]},{"id":"p2-sched-text","component":"Text","text":"Schedule"},{"id":"p2-sched","component":"Button","child":"p2-sched-text","variant":"primary","action":{"event":{"name":"create_calendar_event","data":{"title":"Dinner at Joe's Pizza","location":"375 Canal St"}}}},{"id":"p2-dir-text","component":"Text","text":"Directions"},{"id":"p2-dir","component":"Button","child":"p2-dir-text","action":{"event":{"name":"open_uri","data":{"uri":"geo:40.72,-74.00?q=Joe's Pizza"}}}},{"id":"p3","component":"Card","child":"p3-content"},{"id":"p3-content","component":"Column","children":["p3-top","p3-addr","p3-btns"]},{"id":"p3-top","component":"Row","children":["p3-name","p3-rating"],"justify":"spaceBetween"},{"id":"p3-name","component":"Text","text":"Carbone","variant":"h3"},{"id":"p3-rating","component":"Text","text":"★4.7","variant":"caption"},{"id":"p3-addr","component":"Text","text":"181 Thompson St, New York","variant":"caption"},{"id":"p3-btns","component":"Row","children":["p3-sched","p3-dir"]},{"id":"p3-sched-text","component":"Text","text":"Schedule"},{"id":"p3-sched","component":"Button","child":"p3-sched-text","variant":"primary","action":{"event":{"name":"create_calendar_event","data":{"title":"Dinner at Carbone","location":"181 Thompson St"}}}},{"id":"p3-dir-text","component":"Text","text":"Directions"},{"id":"p3-dir","component":"Button","child":"p3-dir-text","action":{"event":{"name":"open_uri","data":{"uri":"geo:40.73,-74.00?q=Carbone"}}}}]}}
```

**A2UI Email Inbox (605 tokens):**

```json
{"updateComponents":{"surfaceId":"email","components":[{"id":"root","component":"Column","children":["inbox-header","email-list"]},{"id":"inbox-header","component":"Row","children":["inbox-title","inbox-count"],"justify":"spaceBetween"},{"id":"inbox-title","component":"Text","text":"Inbox","variant":"h2"},{"id":"inbox-count","component":"Text","text":"3 unread","variant":"caption"},{"id":"email-list","component":"List","children":["e1","e2","e3","e4","e5"],"direction":"vertical"},{"id":"e1","component":"Row","children":["e1-info","e1-badge"]},{"id":"e1-info","component":"Column","children":["e1-from","e1-subj"]},{"id":"e1-from","component":"Text","text":"Sarah Chen","variant":"h3"},{"id":"e1-subj","component":"Text","text":"Meeting tomorrow at 3pm","variant":"caption"},{"id":"e1-badge","component":"Text","text":"New","variant":"caption"},{"id":"e2","component":"Row","children":["e2-info","e2-badge"]},{"id":"e2-info","component":"Column","children":["e2-from","e2-subj"]},{"id":"e2-from","component":"Text","text":"Dev Team","variant":"h3"},{"id":"e2-subj","component":"Text","text":"Sprint review notes","variant":"caption"},{"id":"e2-badge","component":"Text","text":"New","variant":"caption"},{"id":"e3","component":"Row","children":["e3-info","e3-badge"]},{"id":"e3-info","component":"Column","children":["e3-from","e3-subj"]},{"id":"e3-from","component":"Text","text":"Alex Rivera","variant":"h3"},{"id":"e3-subj","component":"Text","text":"Updated design files","variant":"caption"},{"id":"e3-badge","component":"Text","text":"New","variant":"caption"},{"id":"e4","component":"Row","children":["e4-info"]},{"id":"e4-info","component":"Column","children":["e4-from","e4-subj"]},{"id":"e4-from","component":"Text","text":"Newsletter"},{"id":"e4-subj","component":"Text","text":"Weekly digest - March 28","variant":"caption"},{"id":"e5","component":"Row","children":["e5-info"]},{"id":"e5-info","component":"Column","children":["e5-from","e5-subj"]},{"id":"e5-from","component":"Text","text":"AWS"},{"id":"e5-subj","component":"Text","text":"Your monthly invoice is ready","variant":"caption"}]}}
```

**A2UI Booking Form (412 tokens):**

```json
{"updateComponents":{"surfaceId":"booking","components":[{"id":"root","component":"Card","child":"form-content"},{"id":"form-content","component":"Column","children":["form-title","form-fields","form-actions"]},{"id":"form-title","component":"Text","text":"Book a Table","variant":"h2"},{"id":"form-fields","component":"Column","children":["date-field","time-field","guests-field","notes-field"]},{"id":"date-field","component":"DateTimeInput","value":{"path":"/form/date"},"enableDate":true,"enableTime":false},{"id":"time-field","component":"DateTimeInput","value":{"path":"/form/time"},"enableDate":false,"enableTime":true},{"id":"guests-field","component":"ChoicePicker","options":[{"label":"1","value":"1"},{"label":"2","value":"2"},{"label":"3","value":"3"},{"label":"4","value":"4"},{"label":"5","value":"5"},{"label":"6","value":"6"},{"label":"7","value":"7"},{"label":"8","value":"8"}],"selections":{"path":"/form/guests"},"maxAllowedSelections":1},{"id":"notes-field","component":"TextField","label":"Special Requests","value":{"path":"/form/notes"},"textFieldType":"longText"},{"id":"form-actions","component":"Row","children":["cancel-btn","confirm-btn"],"justify":"spaceBetween"},{"id":"cancel-text","component":"Text","text":"Cancel"},{"id":"cancel-btn","component":"Button","child":"cancel-text","action":{"event":{"name":"navigate","data":{"route":"home"}}}},{"id":"confirm-text","component":"Text","text":"Confirm Booking"},{"id":"confirm-btn","component":"Button","child":"confirm-text","variant":"primary","action":{"event":{"name":"create_reservation","data":{"restaurant":"Luigi's"}}}}]}}
```

**A2UI Side-by-Side Comparison (889 tokens):**

```json
{"updateComponents":{"surfaceId":"compare","components":[{"id":"root","component":"Column","children":["comp-title","comp-row","comp-note"]},{"id":"comp-title","component":"Text","text":"Compare Plans","variant":"h2"},{"id":"comp-row","component":"Row","children":["plan-a","plan-b"]},{"id":"plan-a","component":"Card","child":"pa-content"},{"id":"pa-content","component":"Column","children":["pa-name","pa-price","pa-details","pa-btn"]},{"id":"pa-name","component":"Text","text":"Basic Plan","variant":"h3"},{"id":"pa-price","component":"Text","text":"$15/month","variant":"h1"},{"id":"pa-details","component":"Column","children":["pa-d1","pa-d2","pa-d3"]},{"id":"pa-d1","component":"Row","children":["pa-d1-k","pa-d1-v"],"justify":"spaceBetween"},{"id":"pa-d1-k","component":"Text","text":"Storage","variant":"caption"},{"id":"pa-d1-v","component":"Text","text":"50 GB"},{"id":"pa-d2","component":"Row","children":["pa-d2-k","pa-d2-v"],"justify":"spaceBetween"},{"id":"pa-d2-k","component":"Text","text":"Users","variant":"caption"},{"id":"pa-d2-v","component":"Text","text":"1"},{"id":"pa-d3","component":"Row","children":["pa-d3-k","pa-d3-v"],"justify":"spaceBetween"},{"id":"pa-d3-k","component":"Text","text":"Support","variant":"caption"},{"id":"pa-d3-v","component":"Text","text":"Email only"},{"id":"pa-btn-text","component":"Text","text":"Select Basic"},{"id":"pa-btn","component":"Button","child":"pa-btn-text","action":{"event":{"name":"select_plan","data":{"plan":"basic"}}}},{"id":"plan-b","component":"Card","child":"pb-content"},{"id":"pb-content","component":"Column","children":["pb-name","pb-price","pb-details","pb-badge","pb-btn"]},{"id":"pb-name","component":"Text","text":"Pro Plan","variant":"h3"},{"id":"pb-price","component":"Text","text":"$45/month","variant":"h1"},{"id":"pb-details","component":"Column","children":["pb-d1","pb-d2","pb-d3"]},{"id":"pb-d1","component":"Row","children":["pb-d1-k","pb-d1-v"],"justify":"spaceBetween"},{"id":"pb-d1-k","component":"Text","text":"Storage","variant":"caption"},{"id":"pb-d1-v","component":"Text","text":"500 GB"},{"id":"pb-d2","component":"Row","children":["pb-d2-k","pb-d2-v"],"justify":"spaceBetween"},{"id":"pb-d2-k","component":"Text","text":"Users","variant":"caption"},{"id":"pb-d2-v","component":"Text","text":"10"},{"id":"pb-d3","component":"Row","children":["pb-d3-k","pb-d3-v"],"justify":"spaceBetween"},{"id":"pb-d3-k","component":"Text","text":"Support","variant":"caption"},{"id":"pb-d3-v","component":"Text","text":"24/7 Priority"},{"id":"pb-badge","component":"Text","text":"Recommended","variant":"caption"},{"id":"pb-btn-text","component":"Text","text":"Select Pro"},{"id":"pb-btn","component":"Button","child":"pb-btn-text","variant":"primary","action":{"event":{"name":"select_plan","data":{"plan":"pro"}}}},{"id":"comp-note","component":"Text","text":"All plans include a 14-day free trial.","variant":"caption"}]}}
```

### Raw JSON Strings

**Raw JSON Weather Card (143 tokens):**

```json
{"type":"card","children":[{"type":"row","justify":"spaceBetween","children":[{"type":"txt","text":"San Francisco","style":"title"},{"type":"icon","name":"partly_cloudy_day","size":28}]},{"type":"txt","text":"62°","style":"display"},{"type":"txt","text":"Partly Cloudy","style":"body"},{"type":"row","justify":"spaceBetween","children":[{"type":"txt","text":"H:68°  L:55°","style":"caption"},{"type":"txt","text":"Humidity: 72%","style":"caption"}]}]}
```

**Raw JSON Place Search (537 tokens):**

```json
{"type":"col","children":[{"type":"txt","text":"Italian Restaurants Nearby","style":"headline"},{"type":"list","children":[{"type":"card","children":[{"type":"row","justify":"spaceBetween","children":[{"type":"txt","text":"Luigi's","style":"title"},{"type":"badge","text":"★4.5","variant":"info"}]},{"type":"txt","text":"119 Mulberry St, New York","style":"caption"},{"type":"row","gap":8,"children":[{"type":"btn","text":"Schedule","style":"primary","action":{"type":"tool","name":"create_calendar_event","args":{"title":"Dinner at Luigi's","location":"119 Mulberry St"}}},{"type":"btn","text":"Directions","style":"text","action":{"type":"uri","value":"geo:40.72,-73.99?q=Luigi's"}}]}]},{"type":"card","children":[{"type":"row","justify":"spaceBetween","children":[{"type":"txt","text":"Joe's Pizza","style":"title"},{"type":"badge","text":"★4.3","variant":"info"}]},{"type":"txt","text":"375 Canal St, New York","style":"caption"},{"type":"row","gap":8,"children":[{"type":"btn","text":"Schedule","style":"primary","action":{"type":"tool","name":"create_calendar_event","args":{"title":"Dinner at Joe's Pizza","location":"375 Canal St"}}},{"type":"btn","text":"Directions","style":"text","action":{"type":"uri","value":"geo:40.72,-74.00?q=Joe's Pizza"}}]}]},{"type":"card","children":[{"type":"row","justify":"spaceBetween","children":[{"type":"txt","text":"Carbone","style":"title"},{"type":"badge","text":"★4.7","variant":"info"}]},{"type":"txt","text":"181 Thompson St, New York","style":"caption"},{"type":"row","gap":8,"children":[{"type":"btn","text":"Schedule","style":"primary","action":{"type":"tool","name":"create_calendar_event","args":{"title":"Dinner at Carbone","location":"181 Thompson St"}}},{"type":"btn","text":"Directions","style":"text","action":{"type":"uri","value":"geo:40.73,-74.00?q=Carbone"}}]}]}]}]}
```

**Raw JSON Email Inbox (308 tokens):**

```json
{"type":"col","children":[{"type":"row","justify":"spaceBetween","children":[{"type":"txt","text":"Inbox","style":"headline"},{"type":"badge","text":"3 unread","variant":"info"}]},{"type":"list","children":[{"type":"row","children":[{"type":"col","children":[{"type":"txt","text":"Sarah Chen","style":"title"},{"type":"txt","text":"Meeting tomorrow at 3pm","style":"caption"}]},{"type":"badge","text":"New","variant":"success"}]},{"type":"row","children":[{"type":"col","children":[{"type":"txt","text":"Dev Team","style":"title"},{"type":"txt","text":"Sprint review notes","style":"caption"}]},{"type":"badge","text":"New","variant":"success"}]},{"type":"row","children":[{"type":"col","children":[{"type":"txt","text":"Alex Rivera","style":"title"},{"type":"txt","text":"Updated design files","style":"caption"}]},{"type":"badge","text":"New","variant":"success"}]},{"type":"row","children":[{"type":"col","children":[{"type":"txt","text":"Newsletter","style":"body"},{"type":"txt","text":"Weekly digest - March 28","style":"caption"}]}]},{"type":"row","children":[{"type":"col","children":[{"type":"txt","text":"AWS","style":"body"},{"type":"txt","text":"Your monthly invoice is ready","style":"caption"}]}]}]}]}
```

**Raw JSON Booking Form (184 tokens):**

```json
{"type":"card","children":[{"type":"txt","text":"Book a Table","style":"headline"},{"type":"col","children":[{"type":"input","id":"date","label":"Date","inputType":"date"},{"type":"input","id":"time","label":"Time","inputType":"time"},{"type":"input","id":"guests","label":"Number of Guests","inputType":"select","options":["1","2","3","4","5","6","7","8"]},{"type":"input","id":"notes","label":"Special Requests","inputType":"text"}]},{"type":"row","justify":"spaceBetween","children":[{"type":"btn","text":"Cancel","style":"text","action":{"type":"nav","route":"home"}},{"type":"btn","text":"Confirm Booking","style":"primary","action":{"type":"submit","tool":"create_reservation","args":{"restaurant":"Luigi's"}}}]}]}
```

**Raw JSON Side-by-Side Comparison (445 tokens):**

```json
{"type":"col","children":[{"type":"txt","text":"Compare Plans","style":"headline"},{"type":"row","gap":12,"children":[{"type":"card","children":[{"type":"txt","text":"Basic Plan","style":"title"},{"type":"txt","text":"$15/month","style":"display"},{"type":"col","children":[{"type":"row","justify":"spaceBetween","children":[{"type":"txt","text":"Storage","style":"caption"},{"type":"txt","text":"50 GB","style":"body"}]},{"type":"row","justify":"spaceBetween","children":[{"type":"txt","text":"Users","style":"caption"},{"type":"txt","text":"1","style":"body"}]},{"type":"row","justify":"spaceBetween","children":[{"type":"txt","text":"Support","style":"caption"},{"type":"txt","text":"Email only","style":"body"}]}]},{"type":"btn","text":"Select Basic","style":"outline","action":{"type":"tool","name":"select_plan","args":{"plan":"basic"}}}]},{"type":"card","children":[{"type":"txt","text":"Pro Plan","style":"title"},{"type":"txt","text":"$45/month","style":"display"},{"type":"col","children":[{"type":"row","justify":"spaceBetween","children":[{"type":"txt","text":"Storage","style":"caption"},{"type":"txt","text":"500 GB","style":"body"}]},{"type":"row","justify":"spaceBetween","children":[{"type":"txt","text":"Users","style":"caption"},{"type":"txt","text":"10","style":"body"}]},{"type":"row","justify":"spaceBetween","children":[{"type":"txt","text":"Support","style":"caption"},{"type":"txt","text":"24/7 Priority","style":"body"}]}]},{"type":"badge","text":"Recommended","variant":"success"},{"type":"btn","text":"Select Pro","style":"primary","action":{"type":"tool","name":"select_plan","args":{"plan":"pro"}}}]}]},{"type":"txt","text":"All plans include a 14-day free trial.","style":"caption"}]}
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-05 | Initial benchmark — 5 scenarios, 3 formats, measured via Gemini countTokens |
