# Phase 0c — DAVID_ACTION_REQUIRED · 5 min in browser

**Goal**: rename the OAuth consent screen so Leeya doesn't see "MusicaLeeya" / "Dj Amor" when she signs in.

## Steps (5 min total, browser only)

### 1. Open OAuth consent screen for project `musicaleeya`
https://console.cloud.google.com/apis/credentials/consent?project=musicaleeya

### 2. Click "EDIT APP" at the top

### 3. App information block
- **App name**: change from current value to `Leeya Studio`
- **User support email**: `dreamnovaultimate@gmail.com`
- **App logo**: upload one of these (any clean Leeya photo, 120×120 min, PNG/JPG <1MB):
  - `~/Desktop/leya-rings-from-david/public/photos/leeya-real-1.jpg`
  - `~/Desktop/Leeya Orian/IMG_*.png`
  - `~/Desktop/MUSICALEEYA/leeya_avatar.png`

### 4. App domain block (optional, can leave blank)
- Application home page: `https://leeya-os.vercel.app`
- Privacy policy: leave blank (or `https://leeya-os.vercel.app/privacy`)

### 5. Developer contact information
- `dreamnovaultimate@gmail.com`

### 6. **CRITICAL** — scroll down to "Test users" → click ADD USERS
Add Leeya's Google email here (the one she uses for `@Leeyakats` or `@MusicaLeeya` channel). Without this, she'll get "Google hasn't verified this app" warning when signing in.

If you're not sure which email she uses:
- Open https://www.youtube.com/account in HER browser, copy the email
- Or send her WhatsApp: "מתי הצלחת להגיע ל־@Leeyakats? עם איזה Gmail נכנסת?"

### 7. Click SAVE at the bottom

### 8. Verify scopes still match
Go to https://console.cloud.google.com/apis/credentials/consent/edit?project=musicaleeya — scroll to **Scopes** section. Should still show:
- `.../auth/youtube.upload` (sensitive)
- `.../auth/youtube` (sensitive)

If different scopes are listed, ping me — could break upload.

## Done — confirm to me with one of:
- ✅ "Done, GCP renamed"
- ⚠️ "Question on step X"

I'll start Swift coding either way ; this is non-blocking until E2E validation (Phase 5).

**No re-verification needed for cosmetic changes** as long as scopes don't change.
