# Content Publishing Reference

How to change card/reward data and get it to users **without an App Store release**.

Written for someone who doesn't use git daily. Every command is copy-paste.

---

## TL;DR

```bash
cd ~/Documents/Product/chur                             # 1. go to the project
# ...edit JSON in Xcode...
cd Scripts/ChurContentPublish
swift run ChurContentPublish --upload                   # 2. publish
cd ../..
git add -A && git commit -m "Update Amex Gold dining rate"   # 3. commit
git push origin main                                    # 4. push
```

**Steps 2 and 3 are one action.** Publishing without committing makes the live data and the repo disagree, and the next publish silently reverts your change.

---

## What is remote, and what still needs an app release

| Data | Files | Remote? |
|---|---|---|
| Cards | `Chur/Resources/json/cards/**` | ✅ Yes |
| Reward rates | `Chur/Resources/json/rewards/*.json` | ✅ Yes |
| Benefits | `Chur/Resources/json/benefits/**` | ❌ App release |
| Categories | `Chur/Resources/json/categories/*.json` | ❌ App release |
| Merchants | `Chur/Resources/json/merchants/*.json` | ❌ App release |
| Card images | `Chur/Resources/Assets.xcassets/Cards/` | ❌ App release |

So: **rates, fees and card details publish instantly. Everything else doesn't** — see `ROADMAP.md` §P1b.

A brand-new card can be published, but it will render **without artwork** until an app release adds the image.

---

## The everyday workflow

### 1. Open Terminal in the project

```bash
cd ~/Documents/Product/chur
```

Check you're in the right place and up to date:

```bash
git status
git pull origin main
```

### 2. Edit the JSON

Edit normally in Xcode — they're plain text files. Nothing special.

### 3. Publish

```bash
cd Scripts/ChurContentPublish
swift run ChurContentPublish --upload
```

Expected output:

```
✅ contentVersion 7 → /Users/pakho/Documents/Product/chur/dist
   cards:   175 cards, 82972 bytes
   rewards: 169 entries, 118325 bytes
   manifest: 530 bytes, base URL https://content.chur.app

Uploading to R2 bucket 'chur-content'…
   ✓ cards-7.json
   ✓ rewards-7.json
   ✓ manifest.json

✅ Published.
```

**Sanity check:** the byte counts should have moved if you changed something. If `rewards:` shows the same number as last time, your edit probably didn't save.

The version auto-increments. You never set it manually.

### 4. Commit and push

```bash
cd ../..
git add -A
git commit -m "Update Amex Gold dining rate to 4x"
git push origin main
```

---

## Verifying it worked

**Is the CDN serving it?**

```bash
curl -s https://content.chur.app/manifest.json | grep contentVersion
```

Should show the version the script just printed.

**Did the app get it?**

Run the app → **Profile tab** → **hammer icon** → the menu header shows `Content: v7 · now`.

If it shows an older version, tap **Refresh Remote Content**. The app otherwise only checks every 30 minutes.

Real users get it automatically on next launch or foreground — no action needed.

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

### The app doesn't show my change

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

### `manifest.json` is the file that matters

Uploading new bundles without a new `manifest.json` changes **nothing**. The manifest is what tells the app a version exists; the bundles are inert until it points at them. `--upload` always sends all three, so this only bites on manual uploads.

### `cd: no such file or directory: Scripts/ChurContentPublish`

You're already inside that folder. Either run `swift run ChurContentPublish --upload` directly, or `cd ../..` first.

### Warnings on every publish

```
⚠️  Reward entries with no matching card (1): sc-hk-cathay
⚠️  Cards with no reward data (7): ...
```

Both are known and harmless — see `ROADMAP.md`. They don't block publishing. `wf-autograph` is the only US card in that list and is worth filling in eventually.

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
swift run ChurContentPublish --version 12       # force a version number
swift run ChurContentPublish --min-app-version 1.2.0   # hide from older builds
```

`--min-app-version` is the escape hatch if a future payload needs an app change to read: older builds skip the update instead of breaking.
