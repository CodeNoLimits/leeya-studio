# Leeya Studio · v1.0

> **קצר:** סרטון ארוך → 5 shorts באנגלית עם תרגום + עליה אוטומטית ל־YouTube. בלי טרמינל. בלי בלאגן.

## להפעיל בפעם הראשונה (5 דקות)

1. **חלצי את ה־zip** ל־Desktop. תקבלי תיקייה בשם `Leeya-Studio-v1.0`.
2. בתוך התיקייה, **קליק ימני** (control-click) על `הפעלה ראשונה — Open First Time.command` → **Open**.
3. אם macOS שואלת "Apple cannot verify…" — לחצי **Open** שוב.
4. נפתחת חלון תיכף. תהיי על step 1: **Sign in with Google**. דפדפן יפתח לבד. תכניסי את הסיסמה של ה־Google שלך (זאת של ערוץ YouTube).
5. בסוף, תחזרי לאפליקציה. תכניסי את **מפתח Gemini**:
   - או לחצי "Use David's key" → דוד שולח כל פעם
   - או צרי חינם ב־aistudio.google.com/app/apikey
6. **ElevenLabs** = אופציונלי. אם רוצה את הקול שלך, לחצי "Use David's key (קול שלך משובט)". אם לא — דלגי.
7. לחצי **התחילי**.

## להמיר וידאו (כל פעם, 15-30 דקות)

1. **גררי וידאו ארוך** (mp4/mov, עד 5GB) על האפליקציה.
2. לחצי **חתוך והעלה**.
3. תראי התקדמות בזמן אמת. תוכלי לסגור את ה־Mac ולחזור — היא תמשיך.
4. בסוף — קישורים ישירים לסרטונים שעלו ל־YouTube כ־**Unlisted**. תפרסמי ידנית כשתרצי דרך YouTube Studio.

## אם משהו לא עובד

| תופעה | פתרון |
|---|---|
| App not opening — "Cannot be verified" | קליק ימני על האפליקציה → **Open** (פעם אחת בלבד) |
| Sign-in failed | סגרי את הדפדפן, לחצי **Sign in with Google** שוב |
| Cut & Upload נתקע | סגרי את האפליקציה, פתחי שוב, לחצי **חתוך והעלה** — היא ממשיכה מאיפה שעצרה |
| Gemini error 429 | מכסת חינם בגוגל מתאפסת בכל יום ב־10:00. נסי שוב מחר בבוקר |
| Erreur "GEMINI_API_KEY" | בתפריט "⚙" למעלה → "Reset onboarding" → תכניסי את המפתח שוב |

## פרטים טכניים (אם דוד שואל)

- **Pipeline**: leecut v2.0.0 (Hebrew → English, 5 shorts × 9:16, ElevenLabs voice clone)
- **Embedded**: Python 3.11.13 + ffmpeg 8.1 + whisper.cpp tiny (~145 MB total)
- **Storage**: `~/Library/Application Support/LeeyaStudio/` (videos, tokens, manifest)
- **Keychain service**: `com.dreamnova.leeyastudio` (Gemini, ElevenLabs, voice ID, YouTube token path)

---

**v0.2 בקרוב** : Facebook + Instagram + TikTok auto-post · format מרובע 1:1 · שפות נוספות (FR/RU/ES) · Voice prompts בעברית.

By David Amor · DreamNova · ב״ה · Mai 2026
