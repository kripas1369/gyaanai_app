# PadhAI: Bundled model (true offline) + Play Store

This doc answers: **how to ship AI inside the app**, **Play Store limits**, and how that differs from **Ollama on a laptop** or **Django hosting Gemma**.

---

## Pick one product shape (they are different)

| Approach | Internet for chat? | Who runs the model? | Play Store install size | Your server cost |
|----------|--------------------|----------------------|---------------------------|------------------|
| **A — Bundle GGUF in app (PAD)** | No | Phone CPU/GPU | Large (~1–2 GB total with asset pack) | **$0** for inference |
| **B — Django API hosts Gemma** | Yes | Your cloud GPU | Small app (~50–150 MB) | **You pay** GPU + bandwidth |
| **C — Dev: Ollama on PC** | No (USB/LAN to PC) | Developer laptop | N/A for end users | Dev only |

**You cannot** claim “100% offline for everyone” **and** rely on **Django-hosted Gemma** for answers — that path is **online** and costs you money.

**“Free app on Play Store”** only means users don’t pay you; it does **not** require a server. A **bundled model** avoids server inference cost entirely.

---

## Why not put a 1.5 GB model in the main APK?

- Google Play effectively caps **base** delivery at **~150 MB** for the main download experience.
- Large binaries use **Android App Bundle** + **Play Asset Delivery (PAD)** / **asset packs** (install-time, fast-follow, or on-demand) so the **code APK stays small** and the **model is a separate pack** (up to **2 GB** per install-time pack depending on configuration).

Users still tap **one Install**; Play installs **app + asset pack** together when you use **install-time** delivery.

---

## High-level implementation (Option A — true offline)

### Phase 1 — Model file (GGUF)

1. Choose a **small** instruct model suitable for tutoring, e.g. **Gemma 2 2B** in **GGUF** quantized (**Q4_K_M** or **Q4_0**), typically **~1.2–1.8 GB** depending on quant.
2. **License**: follow **Google Gemma** terms for **redistribution** inside an app (allowed under their license for many apps, but you must comply with their terms).
3. Source examples: community GGUF builds on Hugging Face (verify license and checksums).  
4. If you only have a non-GGUF checkpoint, convert with tooling from the **llama.cpp** / **GGUF** ecosystem (exact command depends on source format).

### Phase 2 — Flutter inference (replace Ollama HTTP)

Use a **native** on-device runner (no Ollama on phone):

- **`llm_llamacpp`** (pub.dev) — llama.cpp–based, streaming, multi-platform.
- **`flutter_llama`** — GGUF, Metal/Vulkan on some devices.
- **`llamadart`** — Dart-facing, multiple backends.

**Tasks:**

1. Add the chosen package; follow its **Android NDK / CMake** requirements.
2. Implement a **single** `generateStream` / `generate` API used by your chat UI.
3. **Remove or gate** `Dio` → `http://…:11434/api/chat` for **production** builds; keep Ollama for **dev** only if you want (`kDebugMode` / flavors).

### Phase 3 — Where the file lives on device

**Not** inside the APK as a normal `assets/` blob if it blows the size limit; use **PAD**:

1. In **Android Studio**, add an **asset pack** module (e.g. **install-time** delivery for “model always present”).
2. Put `model.gguf` (or split chunks if your pipeline requires) in that pack.
3. At runtime, resolve the **absolute path** to the asset (Android **Asset Pack** APIs / `AssetManager` + JNI path, depending on plugin). Many plugins want a **filesystem path** — copy from asset pack to `getApplicationSupportDirectory()` once, then load.

**Concrete Gradle / Play Console steps** change slightly each year — follow:

- `https://developer.android.com/guide/playcore/asset-delivery`
- Flutter: search “Flutter Play Asset Delivery” / community guides (often **platform channels** or **custom Gradle** to expose path).

### Phase 4 — iOS (if you ship App Store too)

- No Play PAD; use **smaller model**, **On-Demand Resources**, or **download once** to `Application Support`.  
- Or ship **iOS-only** smaller quant; **test on real devices** (memory limits).

### Phase 5 — Play Console

1. Build **Android App Bundle (AAB)** including the **asset pack** module.
2. Upload **one** release; Play associates **base + packs**.
3. Declare **large download** in store listing (users on slow networks expect it).

---

## Optional: Django in a “bundled model” world

- **Django** can still be used for **accounts**, **curriculum JSON**, **analytics**, **optional sync** — **not** for streaming chat tokens if you want **offline-first**.
- **Do not** host Gemma on Django **and** claim fully offline chat unless you **fallback** to server when online (hybrid).

---

## Config checklist (copy-paste tasks)

- [ ] **Freeze product**: “Offline chat = bundled GGUF only” OR “Online chat = Django API” (or hybrid rules).
- [ ] **Freeze model**: name + quant + expected size + license checked.
- [ ] **Spike**: one `flutter_llama` / `llm_llamacpp` demo loading a **small** GGUF from local path on a **mid-range Android** phone.
- [ ] **Android**: add **asset pack** module; place GGUF; confirm install-time delivery in internal testing track.
- [ ] **App**: copy model from pack → app storage path → **init engine** → **stream tokens** into existing chat bubble UI.
- [ ] **Remove** production dependency on **Ollama URL** (or hide behind **Developer options**).
- [ ] **Play**: privacy policy, data safety form, large-download warning.
- [ ] **Performance**: context length, threads, and battery; add “low memory” error if init fails.

---

## Why the current PadhAI code uses Ollama

The existing app uses **HTTP** to **Ollama** for fast iteration on a **PC**. That is **correct for development**. Shipping to Play Store with **true offline** requires the **native** stack above — it is a **separate engineering milestone**, not a config toggle.

---

## References

- Play Asset Delivery: https://developer.android.com/guide/playcore/asset-delivery  
- App bundle: https://developer.android.com/guide/app-bundle  
- Gemma terms: https://ai.google.dev/gemma/terms  
