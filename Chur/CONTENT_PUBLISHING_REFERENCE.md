# Content Publishing Reference

How to change card/reward data and get it to users **without an App Store release**.

Written for someone who doesn't use git daily. Every command is copy-paste.

---

## The one rule that explains everything else

**The publisher reads the files in your folder, right now. Not GitHub, not the CDN.**

`swift run ChurContentPublish --upload` looks at whatever is on your Mac at that moment, packages it, and makes it live for every user. It has no idea what's on GitHub. So:

- Edits you haven't saved → not published.
- Work that's on GitHub but not pulled → not published. Worse, publishing *overwrites* it live, because your older copy is what gets packaged.
- **Always `git pull` before you publish.** This is the step that bites, and it looks like a CDN bug when it does.

Everything below is that rule with the details filled in.

---

## Which job are you doing?

| I want to… | Go to |
|---|---|
| Change a rate, fee, perk, merchant or badge | [Job A: edit existing data](#job-a-edit-existing-data) |
| Add a brand-new card, artwork included | [Job B: add a card](#job-b-add-a-card) |
| Add or replace just a card image | [Job C: card art only](#job-c-card-art-only) |
| Add or replace a badge / bank / partner icon | [Job D: icon art only](#job-d-icon-art-only) |
| Add a brand-new badge, partner or issuer | [Job E: add a badge, partner or issuer](#job-e-add-a-badge-partner-or-issuer) |

Every one of them ends the same way — **publish, then commit** — and starts the same way: `git pull`.

Nothing here needs an App Store release. Since P1d the only file that does is `SeedDataRegions.json`.

### Where things live

Three places, and the split matters — **JSON in Xcode, artwork in Finder:**

| What | Where | Edit it in |
|---|---|---|
| All seed JSON | `Chur/Resources/json/…` | **Xcode** |
| Card images | `CardArt/<issuer>/<imageName>.png` | **Finder** |
| Badge, bank and partner icons | `IconArt/<group>/<iconName>.png` | **Finder** |

`CardArt/` and `IconArt/` sit at the repo root, next to `Chur/` — not inside it. They will **not** appear in Xcode's project navigator, on purpose: `Chur/` is a synchronized folder, so anything dropped in there gets compiled into the app and puts back the 27 MB that moving artwork to the CDN saved. Drop images in Finder.

```
chur/
├── CardArt/          ← card images (Finder)
│   ├── amex/  chase/  citi/  …
│   └── hk/amex-hk/  hk/citi-hk/  …
├── IconArt/          ← badge / bank / partner icons (Finder)
│   ├── badges/  banks/
│   └── partners/dining/  partners/hotels/  …
├── Chur/             ← code + JSON (Xcode)
└── Scripts/ChurContentPublish/
```

The subfolders inside both art directories are for you. Nothing reads them — only the **filename** matters, and it must exactly equal the name the JSON refers to (`imageName` for a card; `merchantIconName`, `iconName`, `logoImageName` or `icon` for everything else).

Three icons were broken for months because the art and the JSON disagreed by one character — `icon_allegient` against `icon_allegiant`. Nothing looked wrong, because a missing icon falls back to an emoji. The publish now lists any name it can't find; see [the icon warning](#warnings-on-every-publish).

---

## Job A: edit existing data

```bash
cd ~/Documents/Product/chur
git pull origin main                                    # 1. get the latest
# ...edit JSON in Xcode, and save (⌘S)...
cd Scripts/ChurContentPublish
swift run ChurContentPublish --upload                   # 2. publish
cd ../..
git add -A && git commit -m "Update Amex Gold dining rate"   # 3. commit
git push origin main                                    # 4. push
```

**Steps 2 and 3 are one action.** Publishing without committing makes the live data and the repo disagree, and the next publish silently reverts your change.

**Editing a category? Run the tests first.** `Chur/Resources/json/categories/*.json` is the one place where a content edit changes *prices* rather than labels — `cardFilter`, `excludeFromParent` and `categoryLinks` all feed the engine that decides which card wins. Open the project and press **⌘U** before you publish; the 33 pricing vectors are the only thing between a category edit and a wrong rate on every device. Everything else in the seed data is safe to edit freely.

## Job B: add a card

```bash
cd ~/Documents/Product/chur
git pull origin main
```

1. **JSON** — add the card under `Chur/Resources/json/cards/<region>/<issuer>/` in Xcode. Note the `imageName` you gave it.
2. **Art** — in Finder, save the PNG or JPEG as `CardArt/<issuer>/<imageName>.png`. The filename must match `imageName` exactly, or the card shows a grey placeholder forever.
3. **Publish** — `cd Scripts/ChurContentPublish && swift run ChurContentPublish --upload`. Only the new image uploads; the rest are skipped.
4. **Commit** — `cd ../..` then `git add -A && git commit -m "Add <card>" && git push origin main`. **Include `art-uploaded.json`** — `git add -A` catches it.

Check the publish output before it uploads:

```
⚠️  Cards whose imageName has no art (1): amex-hilton-silver
```

That warning means step 2's filename doesn't match step 1's `imageName`. It does not stop the publish — fix it and re-run.

## Job C: card art only

Replacing a card's picture, or filling in art for a card that's showing a placeholder.

1. Drop the file at `CardArt/<issuer>/<imageName>.png` in Finder, replacing the old one if there is one.
2. `cd Scripts/ChurContentPublish && swift run ChurContentPublish --upload`
3. `cd ../.. && git add -A && git commit -m "New art for <card>" && git push origin main`

No JSON changes, no app release. Image keys are content-addressed (`art/<imageName>-<sha8>.png`), so new bytes become a new key and devices fetch it on the next content version — nothing to cache-bust. The old key stays in R2, so a rollback still resolves.

## Job D: icon art only

Badge, bank and partner icons. Same shape as Job C, different folder.

1. Drop the file at `IconArt/<group>/<iconName>.png` in Finder, replacing the old one if there is one. Groups are `badges/`, `banks/`, `partners/<category>/` — **for you, not for the app.** Only the filename matters.
2. `cd Scripts/ChurContentPublish && swift run ChurContentPublish --upload`
3. `cd ../.. && git add -A && git commit -m "New art for <thing>" && git push origin main`

**The filename must equal the name in the JSON exactly**, and which field that is depends on what you're illustrating:

| Illustrating | Field that names it | Lives in |
|---|---|---|
| A bank / issuer | `logoImageName` | `control/SeedDataIssuers.json` |
| A badge | `icon` | `badges/SeedDatabadges.json` |
| An airline or hotel partner | `logoImageName` | `badges/SeedDataPartners.json` |
| A shop or brand | `merchantIconName` | `merchants/SeedDataMerchants_*.json` |
| A category | `iconName` | `categories/SeedDataCategories_*.json` |

The publish lists every name it couldn't find a file for, so you never have to guess:

```
⚠️  Icon names with no file in IconArt/ (22): icon_dbs, icon_fidelity, …
```

Drop a matching file in and the name disappears from that list. **A wrong filename is silent in the app** — a missing icon falls back to an emoji, which reads as a design choice rather than as breakage. Three icons were wrong for months for exactly that reason (`icon_allegient` against `icon_allegiant`). The list above is the only place it shows.

> **Don't drag a file into a folder that already has one of that name.** Finder makes a copy called `icon_delta 2.png` instead of replacing it, which is a *different* icon as far as everything here is concerned. The publish refuses those now; clear them with `git clean -f IconArt/`. Replace the file properly, or delete the old one first.

## Job E: add a badge, partner or issuer

Same two halves as adding a card — a JSON entry and a picture.

```bash
cd ~/Documents/Product/chur
git pull origin main
```

1. **JSON** — add the entry in Xcode, in the file from the table in Job D. Note the icon name you gave it.
2. **Art** — in Finder, save the image as `IconArt/<group>/<that exact name>.png`.
3. **Publish** — `cd Scripts/ChurContentPublish && swift run ChurContentPublish --upload`
4. **Commit** — `cd ../..` then `git add -A && git commit -m "Add <thing>" && git push origin main`

Two things to know before you start:

- **A badge also needs `detectionRules`** that reference real benefit ids, or it never unlocks for anyone. Check the ids against `Chur/Resources/json/benefits/`.
- **A transfer partner is referenced by id** from `SeedDataTransferPartners.json`. Adding the partner alone puts it in the directory; it appears in a program's list only once that program names it.

> Working on a branch rather than `main`? Replace `main` in every command above — see [Branches](#branches--when-the-commands-say-something-other-than-main). Check with `git branch --show-current`.

---

## What is remote, and what still needs an app release

| Data | Files | Remote? |
|---|---|---|
| Cards | `Chur/Resources/json/cards/**` | ✅ Yes |
| Reward rates | `Chur/Resources/json/rewards/*.json` | ✅ Yes |
| Benefits | `Chur/Resources/json/benefits/**` | ✅ Yes |
| Merchants | `Chur/Resources/json/merchants/SeedDataMerchants_*.json` | ✅ Yes |
| Map mappings | `Chur/Resources/json/merchants/SeedDataGenericMappings.json` | ✅ Yes |
| Card images | `CardArt/<issuer>/<imageName>.png` (repo root) | ✅ Yes |
| Categories | `Chur/Resources/json/categories/*.json` | ✅ Yes |
| Recommendations | `Chur/Resources/json/recommendations/**` | ✅ Yes |
| Badges, partners, transfer partners, coverage tables | `Chur/Resources/json/badges/*.json` | ✅ Yes |
| Issuers, reward programs, program upgrades | `Chur/Resources/json/control/SeedData{Issuers,Programs,ProgramUpgrades}.json` | ✅ Yes |
| Boost programs | `Chur/Resources/json/bankrelationshipprograms/boost_programs.json` | ✅ Yes |
| Badge / bank / partner icons | `IconArt/<group>/<iconName>.png` (repo root) | ✅ Yes |
| **Regions** | `Chur/Resources/json/control/SeedDataRegions.json` | ❌ App release — **on purpose** |

So since P1d: **everything publishes instantly except regions.**

Regions are the deliberate exception. The file gates onboarding and locale resolution, it changes approximately never, and a bad payload would leave a user with no region to pick — there is nothing to gain by making it remotely mutable. See `ROADMAP.md` §P1d.

> **Merchants are the one domain that writes to the user's database.** A `brandCategory` block synthesizes a `SpendingCategory`, which is a persisted model — so publishing a new brand inserts a row on every device, and removing one deactivates a row users may have selected. Read the retirement rules in `MERCHANT_SETUP_REFERENCE.md` before deleting a merchant entry.

**Why card art works the way it does.** It no longer ships inside the app — `Assets.xcassets/Cards` was deleted, taking 19 MB with it. Images are downloaded on first display and cached permanently, and the user's own cards are prefetched so a wallet never depends on a live connection. The trade: on a fresh install with no network, cards the user doesn't own show grey placeholders until they're online once. The files themselves stay in the repo at `CardArt/` — see [Where things live](#where-things-live).

---

## Reading the publish output

This is the screen to actually look at — it tells you whether the publish did what you meant, *before* users get it.

```
✅ contentVersion 18 → /Users/pakho/Documents/Product/chur/dist
   cards: 175 cards, 83005 bytes
   rewards: 169 entries, 118325 bytes
   benefits: 272 benefits, 195565 bytes
   merchants: 77 merchants, 37063 bytes
   merchantMappings: 4 rule groups, 27389 bytes
   cardArt: 171 images (17.0 MB of files), 36389 bytes
   iconArt: 151 icons (1.9 MB of files), 32000 bytes
   categories: 223 hand-authored categories, … bytes
   recommendations: 6 cards, … bytes
   … (18 domains in all)
   manifest: … bytes, base URL https://content.chur.app

Uploading to R2 bucket 'chur-content'…
   ✓ art unchanged (322 images already uploaded)
   ✓ cards-18.json
   … one line per domain …
   ✓ manifest.json

✅ Published.
```

Three things to check every time:

**1. Did the byte counts move?** If you edited rewards and `rewards:` shows the same number as last time, your edit didn't save. (A single character like `5.0` → `10.0` moves it by exactly one byte.)

**2. Do `cardArt:` and `iconArt:` say 171 and 151?** A count of `0` means the publisher couldn't find `CardArt/` or `IconArt/` — since 2026-08-14 that stops the publish outright, but an older empty index may still be live. Re-publish to replace it.

**3. Is the version one higher than last time?** It auto-increments and you never set it manually — with one exception. It counts up from `dist/manifest.json`, and `dist/` is gitignored, so on a machine that has never published (or after deleting `dist/`) it restarts at 1. Devices already on a higher version then ignore everything you publish. Check and override if it restarted:

```bash
curl -s https://content.chur.app/manifest.json | grep contentVersion   # says 17?
swift run ChurContentPublish --upload --version 18
```

Then commit — publishing and committing are one action, never one without the other.

**`--upload` verifies itself.** Since P1d it re-downloads everything it just published, checksums it, and applies the app's rules — so the run either ends with `✅ Live content is valid` or tells you the CDN disagrees. You no longer need to remember `--verify` after a publish; it is still there for answering "is production broken right now" at any other time.

---

## Verifying it worked

**Is the CDN serving it?**

```bash
swift run ChurContentPublish --verify
```

This is the real check, not the `curl`. It fetches the live manifest, downloads every bundle, verifies each checksum, and applies **the same rules the app applies** — so it tells you what a device would do with what you just published, without needing a device:

```
Verifying https://content.chur.app…

   contentVersion 17, minAppVersion 1.0.0
   generated 2026-08-14T06:12:04Z
   6 bundle(s)

   ✓ cards — 83005 bytes
   ✓ rewards — 118325 bytes
   ✓ benefits — 195565 bytes
   ✓ merchants — 37063 bytes
   ✓ merchantMappings — 27389 bytes
   ✓ cardArt — 36389 bytes
   ✓ iconArt — 31255 bytes
   … 12 more domains …
   ✓ cardArt images — 4 of 171 sampled, all resolve and match
   ✓ iconArt images — 4 of 151 sampled, all resolve and match

✅ Live content is valid — contentVersion 25.
```

The last two lines are the art spot-check. The bundles are JSON; the 322 images they index are separate objects, and until P1d nothing ever checked that one of them actually resolves — so an index could list a key that 404s and the verify would still print all ticks. It samples rather than downloading 17 MB, which catches a whole index pointing at keys that were never uploaded but not one individually missing image.

A failure names the exact domain and reason, and reminds you that one bad domain costs all six. It reads nothing but the CDN, so it works from any directory and cannot affect a publish.

The older one-liner still works if you only want the version number:

```bash
curl -s https://content.chur.app/manifest.json | grep contentVersion
```

**Did the app get it?**

Run the app → **Profile tab** → **hammer icon** → the menu header shows `Content: v18 · now`.

If it shows an older version, tap **Refresh Remote Content**. The app otherwise only checks every 30 minutes.

Real users get it automatically on next launch or foreground — no action needed. They can also **pull down on the wallet** to check immediately, which is the only content control they have and the one thing to tell anyone reporting stale data.

---

## Rolling back a bad publish

Old bundles are never deleted from R2, which is what makes this easy.

```bash
cd ~/Documents/Product/chur
# undo the JSON edit in Xcode, then:
cd Scripts/ChurContentPublish
swift run ChurContentPublish --upload
```

That publishes a *new* version containing the old values. Simplest and safest — no dashboard, no file surgery.

Then revert the code too, so the repo matches:

```bash
cd ../..
git revert HEAD          # undoes the last commit as a new commit
git push origin main
```

---

## Troubleshooting

### My local JSON edit doesn't show up in the simulator

**This one is not about publishing at all, and it wastes hours if you don't know it.**

Remote content **wins over the bundled JSON by design** — that is the entire point of P1a. So once any version has been published and cached, the app ignores your local edits to cards, rewards and benefits. Editing the file, rebuilding, even **Reload JSONs** all change nothing, because `CardDatabase.reloadFromBundle()` re-reads the same cached remote copy despite its name.

**Fix:** hammer menu → **Clear Content Cache**. It drops the cached bundles, reloads from your build, and re-syncs the wallet. Your data is untouched — this is not "Reset All Data".

**Check you're even running your latest code first.** The console prints a build stamp on every launch:

```
🧱 Chur build compiled 2026-08-13 14:32:10 · 2 minutes ago
```

"minutes ago" means the build contains what you just changed. "2 hours ago" means Xcode reused an old build and your edit isn't in it — rebuild before debugging anything else.

How to recognise it: the app shows values you can't find anywhere in the repo. During P1b an Amex card kept referencing a benefit id that had been renamed days earlier — the app was reading a `cards-N.json` published weeks before.

Rule of thumb: **editing JSON locally → Clear Content Cache. Testing a real publish → Refresh Remote Content.**

### The app doesn't show my change (after publishing)

Work through in this order:

**1. Is the CDN serving the new version?**
```bash
curl -s https://content.chur.app/manifest.json | grep contentVersion
```
Old number → the upload didn't land. Re-run with `--upload`.

**2. Did the edit actually save?**
Compare the `rewards:` / `cards:` byte counts against the previous run. Identical numbers usually mean an unsaved file. (A single-character change like `5.0` → `10.0` moves it by exactly one byte.)

**3. Did the app refresh?**
Hammer menu → **Refresh Remote Content**. The 30-minute gate means it won't re-check on every launch.

**4. Is the feature flag on?**
`Chur/App/Config.swift` → `remoteContentEnabled` must be `true`.

### I published, but it behaves like the old code / old data

You published from a folder that doesn't have the change. The publisher packages **your local files**, so a fix that exists on GitHub but hasn't been pulled — or lives on a branch you haven't checked out — simply isn't in the publish.

```bash
cd ~/Documents/Product/chur     # the repo root, not Scripts/ChurContentPublish
git branch --show-current       # on the branch you think you're on?
git pull origin main
```

The `cd` matters: `git pull` from inside `Scripts/ChurContentPublish` still works, but it's easy to run it in a different checkout entirely and believe you're up to date.

This happened on 2026-08-14: a publish ran from `main` before the card-art fix was merged, printed `cardArt: 0 images`, and re-published the same broken index that was being fixed.

### The status line says "validation failed"

```
Last: 08-13 22:05  failed  v0  validation failed: cardArt: expected a non-empty object…
```

**One bad domain kills the entire refresh, not just itself.** `RemoteContentService` validates every bundle before writing any of them, so a broken `cardArt` index means cards, rewards, benefits, merchants and mappings are all discarded too. The `v0` is the giveaway: the version never moved, so nothing was applied.

The fix is always on the publishing side — the app is correctly refusing bad content. Re-publish, and read what the script prints before uploading:

```
   cardArt: 171 images, 34210 bytes index (17 MB of PNGs)
```

`0 images` means the publisher couldn't find `CardArt/`. Since 2026-08-14 that fails the publish outright rather than uploading an empty index, but an older `dist/` may still be on the CDN — re-publish to replace it.

The same "one domain, whole refresh" rule applies to every other validation message: an empty `merchants` array, a `rewards` object with no keys, a card with a blank `id`.

### A card shows a grey placeholder instead of its picture

The card's `imageName` has no matching file in `CardArt/`. The publish says so:

```
⚠️  Cards whose imageName has no art (1): amex-hilton-silver
```

Fix the filename so it matches `imageName` exactly — see [Job C](#job-c-card-art-only). Case and hyphens count; the folder it sits in doesn't.

If *every* card shows a placeholder, this isn't the cause — that's a failed refresh, above.

**`art-uploaded.json` must be committed.** It is the only record of what's already in R2. Without it the script re-uploads all 171 images — harmless, but several minutes.

### An icon shows an emoji instead of a picture

The name in the JSON has no matching file in `IconArt/`. This is the icon twin of the grey card placeholder above, and it is **much harder to spot** — a card with no art looks broken, an icon with no art looks like a deliberate emoji.

Two places report it. The publish:

```
⚠️  Icon names with no file in IconArt/ (22): icon_dbs, icon_fidelity, …
```

and the Xcode console at launch:

```
Icon 'icon_dbs' resolves to nothing — referenced by issuer 'dbs'
```

Fix by adding the file — [Job D](#job-d-icon-art-only). Case, underscores and hyphens all count; the folder it sits in does not.

If *every* icon is missing rather than a few, that is not this. Either the app has not refreshed yet (the console says `art index not fetched yet`, and it fixes itself on the next refresh) or the refresh is failing — see [validation failed](#the-status-line-says-validation-failed).

### The publish refused: "Finder duplicate(s)"

```
❌ IconArt holds 3 Finder duplicate(s) — files macOS named "… 2" when copied.
```

You dragged an image into a folder that already had one by that name, and Finder made a copy called `icon_delta 2.png` rather than replacing it. That trailing ` 2` makes it a *different* icon everywhere in this pipeline, so it would publish as an entry nothing ever asks for.

```bash
git clean -f IconArt/      # or CardArt/, whichever the message named
```

Then replace the file properly — delete the old one first, or confirm the replace in Finder. 55 of these reached the CDN once before this check existed; they were harmless, and nobody could explain where they came from.

### The publish refused: "the app would reject this payload"

```
❌ cardArt: expected a non-empty object keyed by imageName — the app would reject this payload
```

**This is the guard working.** Since 2026-08-14 the publisher checks every bundle against the same rules the app applies, *before* the file is written to `dist/`. It means the payload you were about to upload would have been thrown away by every device — and because one bad domain aborts the whole refresh, it would have taken cards, rewards, benefits, merchants and mappings with it.

The message names the domain and what's wrong with it. Usual causes:

- **`cardArt: expected a non-empty object`** — `CardArt/` is missing or empty. Check you're in the right checkout and that the folder is there.
- **`cards: every entry needs a non-empty 'id'`** — a card JSON file has a blank or missing `id`.
- **`merchants: every entry needs a non-empty 'category'`** — a merchant entry is missing its category, which would synthesize a category with an empty id on every device.
- **`<domain>: no validation rule`** — a new `ContentDomain` was added without a matching rule. Add it in both `validatePayload` (publisher) and `RemoteContentService.validate` (app).

Nothing was written and nothing was uploaded, so fix the data and re-run.

### The publish refused: "ID lock violation"

```
❌ ID lock violation — publishing refused.

   benefits: resy_credit_120
      Benefit.id — CardSyncService deletes the benefit, and usageHistory
      cascades, so the user's redemption history is destroyed
```

**This is the guard working, not a bug.** An id that shipped to users has disappeared from the seed data — usually because you renamed something, since a rename is an addition plus a removal.

Two valid responses:

1. **You didn't mean to break it** — restore the id. Renaming is never safe for the five namespaces in `DataDictionary.md`; give the *new* thing a new id instead and leave the old one alone.
2. **You did mean to retire it** — keep the entry in the seed data but hide it (categories: `"visibility": "hidden"`; benefits: `"isActive": false`), then move the id from `active` to `retired` in `Scripts/ChurContentPublish/id-lock.json`. Commit both.

There is no override flag, deliberately. The check runs before anything is written or uploaded, so a violation costs you a re-run and nothing else.

New ids need no action — the script appends them and tells you to commit the lock file.

### `manifest.json` is the file that matters

Uploading new bundles without a new `manifest.json` changes **nothing**. The manifest is what tells the app a version exists; the bundles are inert until it points at them. `--upload` always sends all three, so this only bites on manual uploads.

### `cd: no such file or directory: Scripts/ChurContentPublish`

You're already inside that folder. Either run `swift run ChurContentPublish --upload` directly, or `cd ../..` first.

### Warnings on every publish

```
⚠️  Reward entries with no matching card (1): sc-hk-cathay
⚠️  Cards with no reward data (7): ...
⚠️  Benefits referenced by a card but not authored (8): resy_credit_120, ...
```

All three are known and harmless — see `ROADMAP.md`. They don't block publishing. `wf-autograph` is the only US card in the second list and is worth filling in eventually. The third means a card promises a perk that has no JSON file: the row simply never appears, so those are content gaps to fill, not errors.

```
⚠️  Icon names with no file in IconArt/ (11): icon_dbs, icon_fidelity, …
```

That one is worth acting on eventually even though it never blocks a publish. Those names appear in the seed JSON and have no artwork, so they render as an emoji or an empty slot — which reads as intentional rather than broken, and is why they went unnoticed for months. Drop a matching file into `IconArt/` to clear each one.

A **duplicate benefit id does** stop the publish, on purpose. Two files claiming one id means the winner depends on folder-enumeration order, and publishing would freeze that arbitrary choice into every client. Delete or rename one.

### A benefit I authored never appears in the app

`enumerateFolder` decodes each file with `try?`, so a file that doesn't match `_BenefitJSON` is skipped in silence — no crash, no log, just a missing perk. Ten benefits were invisible this way before P1b.

The launch validator now catches it. Look for these lines in the Xcode console:

```
ℹ️ SeedDataValidator: 272 benefits loaded
⚠️ SeedDataValidator: Card 'x': benefit 'y' did not load — no file with that id, or its JSON failed to decode
```

Compare the count against the file count (`find Chur/Resources/json/benefits -name '*.json' | wc -l`). A gap means files are failing to decode. Usual causes: a missing `value` (required, and must be a whole number — `12.95` fails), or a required field set to `null`.

---

## Branches — when the commands say something other than `main`

Normal work happens directly on `main`, and every command in this guide assumes that. Occasionally work happens on a **branch** — a parallel copy of the project, used for anything risky enough that you'd want `main` left untouched while it's in progress.

**Check which one you're on before pushing:**

```bash
git branch --show-current
```

If it prints anything other than `main`, substitute that name everywhere this guide says `main`:

```bash
git push origin claude/credit-card-app-growth-47raln
git pull origin claude/credit-card-app-growth-47raln
```

Pushing to the wrong branch isn't destructive — it just puts your work somewhere you didn't expect, and it's fixable.

**Two lines of history exist while a branch is open.** Switching between them swaps the files in your folder, so work committed on one branch appears to vanish when you switch to the other. It hasn't — it comes back when you switch back.

**Merging a branch back into `main`** combines them:

```bash
git checkout main
git merge <branch-name>
git push origin main
```

After that, `main` has everything and the guide's commands work verbatim again.

If git reports a **conflict** during the merge, it means the same file was edited on both sides and git can't decide which version wins. It's routine but fiddly the first time — worth getting help rather than guessing.

---

## Git cheat sheet

| Task | Command |
|---|---|
| Where am I? | `pwd` |
| What changed? | `git status` |
| See the actual edits | `git diff` |
| Save changes | `git add -A` then `git commit -m "message"` |
| Upload to GitHub | `git push origin main` |
| Download latest | `git pull origin main` |
| Which branch? | `git branch --show-current` |
| Switch branch | `git checkout <branch-name>` |
| Merge a branch into main | `git checkout main` then `git merge <branch-name>` |
| Undo last commit | `git revert HEAD` |
| Discard uncommitted edits to one file | `git checkout -- path/to/file` |

**`add` then `commit` then `push`** — commit saves locally, push uploads. Both are needed.

---

## One-time setup (already done — for reference or a new machine)

1. **Cloudflare** — account, `chur.app` nameservers pointed at Cloudflare, R2 bucket `chur-content`, custom domain `content.chur.app`.
2. **Wrangler login** — happens automatically on first `--upload`; opens a browser once. To redo: `npx wrangler login`.
3. **Xcode** — App Group `group.ChurFinancial.shared` under Signing & Capabilities. Requires a paid Apple Developer account; without it the entitlement shows red and the cache falls back to Application Support (fine for now, blocks the future widget).

---

## Command variants

```bash
swift run ChurContentPublish                    # write dist/ only, no upload
swift run ChurContentPublish --upload           # write and upload (normal)
swift run ChurContentPublish --verify           # check live content, change nothing
swift run ChurContentPublish --version 12       # force a version number
swift run ChurContentPublish --min-app-version 1.2.0   # hide from older builds
```

`--min-app-version` is the escape hatch if a future payload needs an app change to read: older builds skip the update instead of breaking.
