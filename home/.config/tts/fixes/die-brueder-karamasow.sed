# -*- mode: sed -*-
# vim: ft=sed:et:ts=2:sts=2:sw=2
#
# ~/.config/tts/fixes/die-brueder-karamasow.sed: names in Dostojewski's
# "Die Brüder Karamasow" for Piper; tts-speak --fixes die-brueder-karamasow
#
# espeak-ng reads Russian names by German rules: "Fj" as "Eff-j", "Dm" as
# "De-m", "Ch" as "K", and mostly stresses the wrong syllable. These are
# phonemes ([[ ]], read verbatim by Piper) with the Russian stress; (s?)
# keeps a German genitive. Spellings differ between translations, hence the
# alternatives (-ow/-off, -i/-ij). How to check a fix: see ../piper-de.sed.

# The family
s/\bFjodorowitsch(s?)\b/[[fjˈoːdɔrɔvɪtʃ\1]]/g
s/\bFjodor(s?)\b/[[fjˈoːdɔɾ\1]]/g
s/\bPawlowitsch(s?)\b/[[pˈavlɔvɪtʃ\1]]/g
s/\bKaramas(ow|off)(s?)\b/[[kaɾamˈaːzɔf\2]]/g
s/\bAlex(ej|ei)(s?)\b/[[alɛksˈɛj\2]]/g
s/\bDmitrij?(s?)\b/[[dmˈiːtrɪj\1]]/g
s/\bMitja(s?)\b/[[mˈiːtja\1]]/g
s/\bSmerdjak(ow|off)(s?)\b/[[smɛɾdjakˈɔf\2]]/g

# Others
s/\bGruschenka(s?)\b/[[ɡrˈuːʃɛnka\1]]/g
s/\bIwanowna(s?)\b/[[ivˈaːnɔvna\1]]/g
s/\bRakitin(s?)\b/[[rakˈiːtɪn\1]]/g
s/\bIljuscha(s?)\b/[[iljˈuːʃa\1]]/g
s/\bGrigorij?(s?)\b/[[ɡriɡˈɔrɪj\1]]/g
s/\bChochlak(owa|ova)(s?)\b/[[xɔxlakˈoːva\2]]/g
s/\bSnegirj(ow|off)(s?)\b/[[snɛɡirjˈɔf\2]]/g
