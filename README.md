# 🥦 FoodFat

> _Is it really healthy? Scan it and find out._

A Flutter app (Android + iOS) for **packed food & drinks** — scan the barcode (or
photograph the label) and instantly get:

- A **0–100 % health score** and **1–5 star rating**
- A plain-English **verdict** (`TRUST IT` / `OK IN MODERATION` / `BE CAREFUL` /
  `NOT GREAT` / `AVOID`)
- A line-by-line **"why this score"** breakdown
- **Ingredient red flags** — palm oil, vanaspati/trans fat, maida, glucose
  syrup, artificial colours & flavours, MSG, …
- **Additive risk** for every E / INS number (curated from EFSA re-evaluations,
  IARC notes, FSSAI/EU rules)
- **NOVA** processing level (1 = whole food … 4 = ultra-processed)
- **Nutri-Score-style** nutrition grade (A…E)
- A **"health-washing" watch** — when the pack says _"natural / healthy / no
  added sugar"_ but the ingredients tell a different story.

Think of it as the "foodfat" YouTubers' workflow, automated — no waiting
for someone else to make a video on the chocolate you just bought.

## How a scan works

```
            ┌─────────────────────────────┐
            │   Barcode? → Open Food      │   ← free, community database
            │   Facts (cached, instant)   │     (incl. many Indian brands)
            └──────────────┬──────────────┘
                           │
   not found / no barcode  ▼
            ┌─────────────────────────────┐
            │  Photos of the label →      │   ← AI vision falls back to
            │  Claude Vision (extracts    │     reading the pack directly
            │  ingredients + nutrition)   │
            └──────────────┬──────────────┘
                           ▼
            ┌─────────────────────────────┐
            │     Scoring engine          │   on-device:
            │  • NOVA processing penalty  │   transparent, deterministic,
            │  • Sugar / sat-fat / salt   │   every penalty + bonus is shown
            │    (Nutri-Score thresholds) │
            │  • Additive risk DB         │
            │  • Ingredient red-flags     │
            │  • Real fruit / fibre /     │
            │    protein bonuses          │
            └──────────────┬──────────────┘
                           ▼
                    Health report screen
```

## Setup

```bash
flutter pub get
flutter run                       # any connected device / simulator
```

### AI label reader (optional)

Barcode lookups are free and need no setup. To analyse products **not** in the
Open Food Facts database — by photographing the pack — open **Settings** in the
app and paste an Anthropic API key.

> Get a key at https://console.anthropic.com/settings/keys

You can pick the vision model (Haiku 4.5 / Sonnet 4.6 / Opus 4.7). Sonnet is
the default — good accuracy/cost balance.

> **MVP note:** in this version the API key is stored on the device and the
> vision call is made directly from the app. For a published consumer product
> you'd route this through your own backend and never ship the key.

## Project layout

```
lib/
├── main.dart                          app entry
├── theme.dart                         colours & typography
├── data/
│   ├── additives_db.dart              curated E/INS risk database
│   └── ingredient_flags.dart          palm-oil/maida/syrup/etc. keyword flags
├── models/
│   ├── product.dart                   normalised product + nutrition
│   └── health_report.dart             score / verdict / factors
├── services/
│   ├── open_food_facts_service.dart   barcode → product
│   ├── ai_vision_service.dart         photos → product via Claude
│   ├── scoring_engine.dart            the heart: produces HealthReport
│   ├── scan_service.dart              orchestrates barcode → AI fallback
│   ├── history_service.dart           local scan history
│   └── settings_service.dart          API key + model choice
├── widgets/
│   ├── score_gauge.dart               circular health-% gauge
│   ├── star_rating.dart               half-step star rating
│   └── flag_chip.dart                 colour-coded severity chips
└── screens/
    ├── home_screen.dart
    ├── scanner_screen.dart            mobile_scanner barcode camera
    ├── capture_screen.dart            collect 1–4 label photos
    ├── result_screen.dart             the full health report
    ├── history_screen.dart
    ├── settings_screen.dart
    └── scan_runner.dart               shared loading / error flow
```

## Data sources

The scoring engine is transparent — every penalty and bonus is shown on the
result screen with a one-line reason. The reasoning is built on top of:

- **Open Food Facts** (ODbL, https://world.openfoodfacts.org) — product
  database including categories, ingredients, additives, NOVA group and the
  official Nutri-Score grade when available.
- **Nutri-Score** thresholds for sugar / saturated fat / salt / energy vs.
  fibre / protein / fruit-veg-nuts content.
- **NOVA classification** for the processing-level penalty.
- A small curated **additive-risk** list (E/INS numbers) blending the EU's
  recent re-evaluations, IARC monographs and FSSAI rules.
- A hand-written set of **ingredient red-flags** for the things "foodfat"
  reviewers always call out (palm oil, vanaspati, maida, glucose-fructose
  syrup, artificial flavour / colour, MSG, named chemical preservatives, …).

This is general information, **not medical or dietary advice** — always read
the actual pack and consult a professional for anything that matters.

## Tests

```bash
flutter test
```

The test suite verifies the scoring engine produces sensible results for a
handful of representative products (a sugary cola, plain oats, a
"healthy-looking" but palm-oil-laden biscuit).
# foodfarmer
# foodfarmer
