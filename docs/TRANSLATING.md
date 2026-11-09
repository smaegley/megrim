# Translating Megrim

Thank you for helping! Megrim is translated by volunteers in a browser, on
[Hosted Weblate](https://hosted.weblate.org/projects/megrim/). You don't need to know Git or
Flutter.

## How it works

- Every piece of text in the app, including the **PDF report** people take to their doctor, is one
  message in Weblate. Each comes with a short note explaining where it appears and what it
  means. Please read it: short words like "Normal" or "Unable" depend on context.
- Weblate opens a pull request with your work. It's reviewed and merged, and goes out with the
  next release.
- A language is **switched on in the app** once it reaches the bar below. Until then your work is
  safe in Weblate, and people see English. You can't break the app by translating part of it.
- Megrim follows the phone's language (on Android 13+ and iOS you can also pick a language for
  Megrim alone in the system settings). If the phone's language isn't available, Megrim is in
  English.

## The bar for a language to ship

- Every message marked **[medical]** or **[legal]**, and everything in the PDF report and the
  notifications, is translated **and approved by a second person**.
- At least 90% of all other messages are translated.

Missing messages show in English until someone translates them. New features add new messages
over time; the release checklist gives translators a few days before each release to catch up.

## Guidelines

- **[medical] and [legal] messages** are where a loose translation can do real harm: symptom
  names, medication classes, the medication-overuse notice, and the "personal diary, not a
  medical device" disclaimer. Translate them carefully and literally, and leave them for a second
  person to approve. If you're unsure of the medical term, leave a comment instead of guessing.
- **Use the glossary** (shown beside each message) for terms that must stay consistent: migraine,
  aura, attack, preventive, relief, check-in, migraine day, clear day.
- **Machine translation** suggestions are available in Weblate. Treat them as a starting point:
  every message must be read and saved by a person.
- **Placeholders** like `{count}` or `{date}` must stay exactly as they are, though you can move
  them within the sentence.
- **Plurals:** messages with `{count, plural, …}` have one form per plural category of your
  language. Weblate shows the forms your language needs.
- **"Megrim"** is the app's name. Don't translate it.
- Keep the tone of the English: calm, plain and factual. Megrim records and counts; it never
  diagnoses or tells people what to do.

## What isn't translated

- Things users type themselves: their own triggers, symptoms, medication names and notes.
- The exported data file (JSON / CSV). It stays in English, so it works between phones set to
  different languages.
- The documentation on GitHub (README, privacy policy, methods).

The English text is the version that counts for the disclaimer and the privacy wording; the app
says so in About.

## Asking for a new language

Open an issue on [GitHub](https://github.com/smaegley/megrim/issues) (label `localization`), or
start the language in Weblate directly if you'll translate it yourself.

## Credits

Translators are credited in the app's About screen, under the name they choose in Weblate.
