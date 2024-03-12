Die FX Liste ist ein massives Projekt zum Reverse-Engineering und zur Klassifizierung sämtlicher SFX und VFX des Spiels.
Es hat sehr viel Geduld und interdisziplinäre Kompetenzen (wie lese ich DLL-files, was sind FX, wie bearbeite ich Screenshots in GIMP...) benötigt,
aber schlussendlich hat es sich gelohnt, die liste ist heute vollständig.

Sie sollte im Wiki als sortierbare und filterbare Tabelle exportiert werden, aber leider hat das Wiki gerade ein paar Probleme und bis die gelöst sind, kann ich nicht daran weiterarbeiten.
Den Code für die Tabelle habe ich aber angefügt.
Das Sortierverfahren ist nicht optimal (O(n^2)), aber stabil.
Für neuere versionen ist es geplant, auf stable mergesort zu wechseln.
Bisher haber nicht notwendig, da Tabelle nur vergleichsweise wenige Datensätze hat und diese auch nicht so häufig sortieren muss.

Der Startpunkt:
https://darkmatters.org/forums/index.php?/topic/49710-reverse-engineering-fx/
https://darkmatters.org/forums/index.php?/topic/72356-s2logicdll-and-s2coredll-data-extraction/


Die FX-Liste:
https://darkmatters.org/forums/index.php?/topic/50689-complete-sacred-2-fx-list-part-i/
https://darkmatters.org/forums/index.php?/topic/70926-complete-sacred-2-fx-list-part-ii/
https://darkmatters.org/forums/index.php?/topic/70928-complete-sacred-2-fx-list-part-iii/
https://darkmatters.org/forums/index.php?/topic/70929-complete-sacred-2-fx-list-part-iv/
https://darkmatters.org/forums/index.php?/topic/72347-complete-sacred-2-fx-list-part-v/


Als Tabelle exportiert ins Wiki:
https://www.sacredwiki.org/index.php/Sacred_2:FX