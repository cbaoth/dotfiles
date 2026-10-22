# -*- mode: sed -*-
# vim: ft=sed:et:ts=2:sts=2:sw=2
#
# ~/.config/tts/piper-de.sed: German pronunciation fixes for Piper (bin/tts-speak).
#
# Piper phonemizes with espeak-ng, which gets some words wrong; the voice then
# says exactly what it was given. tts-speak runs this script (sed -E) over the
# chunks before Piper, for the piper engine only. Two kinds of fix:
#   - respell: a spelling espeak-ng reads right (fixes every inflected form)
#   - [[phonemes]]: Piper reads the text in [[ ]] as phonemes, verbatim
# To find a fix, compare what espeak-ng makes of a word and of a candidate:
#   ~/.venv/bin/python -c 'import os; from piper import PiperVoice as P;
#     v = P.load(os.path.expanduser("~/.cache/piper-tts/de_DE-thorsten-high.onnx"));
#     print(v.phonemize("vergeuden vergäuden"))'

# vergeuden, vergeudet, Vergeudung: espeak-ng splits "ge-uden" like the ge-
# prefix (fɛɾɡəˈuːdən, "verguuden"); "gäud" gives the eu (fɛɾɡˈɔødən).
s/([Gg])eud/\1äud/g

# -ium: espeak-ng reads a long i and stresses the "um" (ʃtˈuːdiːˌʊm, heard as
# "Studiung"). Respelling as "-jum" fixes the ending but shortens or moves the
# stressed vowel (Studjum: ʃtˈʊdjʊm), so these are phonemes, one word each.
s/\bStudium(s?)\b/[[ʃtˈuːdjʊm\1]]/g
