#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["emoji", "markdown-it-py", "mdit-py-plugins", "phonenumbers", "pytest"]
# ///
"""Golden tests for bin/tts-clean: input text -> what the voice is given.

Run: tests/test_tts_clean.py  (or: uv run --script tests/test_tts_clean.py -k url)
"""

from __future__ import annotations

import importlib.machinery
import importlib.util
import sys
from pathlib import Path

import pytest

BIN = Path(__file__).resolve().parent.parent / "bin" / "tts-clean"
_loader = importlib.machinery.SourceFileLoader("tts_clean", str(BIN))
_spec = importlib.util.spec_from_loader("tts_clean", _loader)
assert _spec is not None
tts_clean = importlib.util.module_from_spec(_spec)
sys.modules["tts_clean"] = tts_clean
_loader.exec_module(tts_clean)


def en(text: str, **kwargs: bool) -> str:
    return tts_clean.clean(text, "en", **kwargs)


def de(text: str, **kwargs: bool) -> str:
    return tts_clean.clean(text, "de", **kwargs)


@pytest.mark.parametrize(
    ("text", "spoken"),
    [
        ("See https://example.org/a/b?x=1 for details.", "See web address example dot org for details."),
        ("See https://www.example.org.", "See web address example dot org."),
        ("Visit example.org/docs now.", "Visit web address example dot org now."),
        ("Use www.example.org today.", "Use web address example dot org today."),
        ("Connect to ssh://git@host.example:2222/repo.git first.", "Connect to SSH address host dot example first."),
        ("Clone git@github.com:owner/repo.git now.", "Clone SSH address github dot com now."),
        ("Get ftp://files.example.org/x.zip here.", "Get FTP address files dot example dot org here."),
        ("Read [the docs](https://example.org) today.", "Read the docs today."),
        ("Read <https://example.org/x> today.", "Read web address example dot org today."),
        ("See https://en.wikipedia.org/wiki/Foo_(bar) now.", "See web address en dot wikipedia dot org now."),
    ],
)
def test_url_en(text: str, spoken: str) -> None:
    assert en(text) == spoken


def test_url_de() -> None:
    assert de("Der Artikel https://de.wikipedia.org/wiki/Projekt_Gutenberg ist gut.") == (
        "Der Artikel Web Adresse de Punkt wikipedia Punkt org ist gut."
    )


@pytest.mark.parametrize("name", ["README.md", "file.py", "tool.sh", "node.js", "archive.zip"])
def test_filenames_are_not_domains(name: str) -> None:
    assert "address" not in en(f"Open {name} now.")


@pytest.mark.parametrize(
    ("text", "spoken"),
    [
        ("Edit /home/user/.config/app/config.ini now.", "Edit file config dot ini now."),
        ("Check ../some/file.txt now.", "Check file file dot txt now."),
        ("Run ~/bin/tts-speak now.", "Run path tts speak now."),
        ("Open /etc/ssh/ now.", "Open folder ssh now."),
        ("Open C:\\Windows\\System32\\hosts now.", "Open path hosts now."),
        ("See bin/tts-clean:42 for it.", "See file tts clean, line forty-two for it."),
        ("See docs/setup/tts.md for it.", "See file tts dot md for it."),
        ("See `bin/tts-clean` for it.", "See path tts clean for it."),
    ],
)
def test_paths(text: str, spoken: str) -> None:
    assert en(text) == spoken


@pytest.mark.parametrize("text", ["this and/or that", "5 of A/B tests", "over TCP/IP today", "either/or"])
def test_slashes_in_prose_are_not_paths(text: str) -> None:
    assert tts_clean.clean(text, "en", spell_numbers=False).rstrip(".") == text


@pytest.mark.parametrize(
    ("text", "spoken"),
    [
        ("Set `MAX_RETRY_COUNT` now.", "Set max retry count now."),
        ("Call `foo_bar_baz()` now.", "Call foo bar baz now."),
        ("In snake_case_name here.", "In snake case name here."),
        ("Call `getUserName` now.", "Call get User Name now."),
        ("Run `ls -la` now.", "Run ls la now."),
        ("Run `" + "x " * 40 + "` now.", "Run code skipped now."),
    ],
)
def test_code_inline(text: str, spoken: str) -> None:
    assert en(text) == spoken


@pytest.mark.parametrize(
    ("info", "spoken"),
    [
        ("bash", "Code block, Bash, one line, skipped."),
        ("js", "Code block, Java Script, one line, skipped."),
        ("javascript title=x", "Code block, Java Script, one line, skipped."),
        ("sql", "Code block, sequel, one line, skipped."),
        ("pl/sql", "Code block, pl sql, one line, skipped."),
        ("", "Code block, one line, skipped."),
        ("text", "Code block, one line, skipped."),
    ],
)
def test_code_block_en(info: str, spoken: str) -> None:
    assert en(f"```{info}\ncode\n```") == spoken


def test_code_block_de() -> None:
    assert de("```sql\na\nb\nc\n```") == "Codeblock, S Q L, drei Zeilen, ausgelassen."


@pytest.mark.parametrize(
    ("text", "spoken"),
    [
        ("☑️ Current Tab as Link\n☑️ List of Links", "check box with check emoji, Current Tab as Link. check box with check emoji, List of Links."),
        (":ballot_box_with_check: Current Tab", "check box with check emoji, Current Tab."),
        ("- 🚀 Launch\n- 💡 Idea", "rocket emoji, Launch. light bulb emoji, Idea."),
        ("## 🚀 Features\n\nText.", "rocket emoji, Features.\n\nText."),
        ("We shipped 🚀 today.", "We shipped rocket emoji today."),
        ("We shipped :rocket: today.", "We shipped rocket emoji today."),
        ("Done🎉now", "Done party popper emoji now."),
        ("Great 🎉🎉🎉", "Great party popper emoji."),
        ("Great 🚀 ✨ 🚀", "Great rocket, sparkles emoji."),
        ("Nice 👍🏽 work", "Nice thumbs up emoji work."),
        ("🎉", "party popper emoji."),
        ("1️⃣ First\n2️⃣ Second", "one, First. two, Second."),
        ("Acme© and Foo™ ship.", "Acme© and Foo™ ship."),
        ("✓ Done", "Done."),
    ],
)
def test_emoji_en(text: str, spoken: str) -> None:
    assert en(text) == spoken


def test_colons_are_not_shortcodes() -> None:
    assert "emoji" not in en("Range 5:100:9 here, and [:x:] too.")
    assert ":nope:" in en("Say :nope: loud.")


def test_emoji_de() -> None:
    assert de("🚀 Start\n⚠️ Achtung") == "rakete Emoji, Start. warnung Emoji, Achtung."
    assert de("Ein :rocket: fliegt.") == "Ein rakete Emoji fliegt."


def test_reference_heading_with_emoji_is_cut() -> None:
    assert en("Intro text.\n\n## 📚 References\n\n- A source") == "Intro text."


def test_exponents_keep_their_meaning() -> None:
    assert en("E = mc^2") == "E = mc to the power of two."
    assert de("Also x² ist") == "Also x hoch zwei ist."


@pytest.mark.parametrize(
    ("text", "spoken"),
    [
        ("A claim.[^1] More.\n\n[^1]: The note body.", "A claim. More."),
        ("Only a ref[^1] here.", "Only a ref here."),
        ("He said so.[1][2] Others[citation needed] too.", "He said so. Others too."),
        ("Homer wrote this.12 Then Plato¹ replied.", "Homer wrote this. Then Plato replied."),
        ("A [1](https://x.org#c) cite and [[2]](https://x.org#d) too.", "A cite and too."),
        ("Ref[1] style.\n\n[1]: https://x.org", "Ref style."),
        ("Geschichte[Bearbeiten | Quelltext bearbeiten]\n\nText.", "Geschichte. Text."),
    ],
)
def test_footnotes(text: str, spoken: str) -> None:
    assert " ".join(en(text).split()) == spoken


def test_abbreviated_reference_numbers_survive() -> None:
    assert de("Siehe Nr.12 Dort steht es.") != "Siehe Nummer Dort steht es."


@pytest.mark.parametrize(
    "text",
    [
        "Body text.\n\n## See also\n\n- Foo\n- Bar\n",
        "Body text.\n\n## See also\n\n- Foo\n\n## References\n\n1. Smith\n",
        "Body text.\n\nSee also\n\nFoo\n\nBar\n",
        "Body text.\n\nReferences[edit]\n\nSmith 2019\n",
    ],
)
def test_reference_sections_are_cut(text: str) -> None:
    assert en(text) == "Body text."


def test_reference_sections_de() -> None:
    assert de("Text hier.\n\n## Weblinks\n\n- a\n\n## Einzelnachweise\n\n1. b\n") == "Text hier."


def test_notes_in_the_middle_survive() -> None:
    assert "Later" in en("Intro.\n\n## Notes\n\nA note.\n\n## Later\n\nMore text.\n")


def test_keep_references() -> None:
    assert "Foo" in en("Body.\n\n## See also\n\n- Foo\n", keep_references=True)


def test_only_a_reference_section_is_read() -> None:
    assert "Smith" in en("## References\n\nSmith\n")


def test_small_table_reads_row_by_row() -> None:
    assert en("| Name | Value |\n|---|---|\n| foo | bar |\n| baz | qux |\n") == "Name foo, Value bar. Name baz, Value qux."


def test_large_table_is_announced() -> None:
    rows = "".join(f"| a{i} | b |\n" for i in range(9))
    assert en(f"| A | B |\n|---|---|\n{rows}") == "Table, nine rows, skipped."


def test_contact_data() -> None:
    assert en("Mail jane.doe@example.org now.") == "Mail jane dot doe at example dot org now."
    assert de("Ruf +49 170 1234567 an.") == "Ruf plus vier neun, eins sieben null, eins zwei drei vier fünf sechs sieben an."
    assert de("Wohnt Weg 1, 12345 Berlin dort.").count("eins zwei drei vier fünf") == 1


@pytest.mark.parametrize("text", ["am 2026-11-08 war es", "von 1990-2000 etwa", "12345 Menschen waren da"])
def test_numbers_are_not_phones(text: str) -> None:
    assert "null null" not in de(text) and "eins zwei drei vier fünf" not in de(text)


@pytest.mark.parametrize(
    ("text", "spoken"),
    [
        ("Version v1.2.3 now.", "Version one dot two dot three now."),
        ("Python 3.12 now.", "Python three dot twelve now."),
        ("Commit 2bd15e9 now.", "Commit Hash now."),
        ("Host 192.168.1.1:8080 now.", "Host one hundred ninety-two dot one hundred sixty-eight dot one dot one now."),
        ("At 10.0.0.1:80.", "At ten dot zero dot zero dot one."),
        ("Got v1.2.3.", "Got one dot two dot three."),
        ("On Python 3.12.", "On Python three dot twelve."),
    ],
)
def test_tech_tokens(text: str, spoken: str) -> None:
    assert en(text) == spoken


def test_german_date_is_not_a_version() -> None:
    assert "Punkt" not in de("Am 12.03.2026 war es.")


def test_units() -> None:
    assert en("It is 5 km at 20 °C.") == "It is five kilometers at twenty degrees Celsius."
    assert de("Nur 1 km und 2 h.") == "Nur ein Kilometer und zwei Stunden."
    assert en("About 3.5 GB/s here.") == "About three point five gigabytes per second here."


def test_markup_leftovers() -> None:
    assert en("> A quote line\n\nAfter.") == "A quote line.\n\nAfter."
    assert en("<div>Some <b>html</b> &amp; text</div>") == "Some html and text."
    assert en("**Note:** a → b done.") == "Note: a to b done."
    assert en("- [x] done task\n- [ ] open task\n") == "done task. open task."


def test_plain_text_is_not_mistaken_for_markdown() -> None:
    assert "indented" in en("    indented plain text\n    second line")
    assert en("2*3*4 is it") == "two times three times four is it."


def test_hard_wrapped_plain_text_is_rejoined() -> None:
    long = "word " * 15
    assert "\n" not in en(f"{long}\n{long}\nend")


def test_detect_ignores_code() -> None:
    code = "the and is not of to in that it for with " * 20
    assert tts_clean.detect_language(f"Das ist nicht der Text und auch nicht die Sache.\n\n```\n{code}\n```\n") == "de"


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-q", *sys.argv[1:]]))
