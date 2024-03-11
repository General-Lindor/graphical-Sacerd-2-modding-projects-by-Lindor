Für die Berechnung von Oren-Nayar war eine Farbraumkonvertierung von RGB zu HSL notwendig.
Auf Wikipedia waren einige Formeln angegeben, wo man dann nicht wusste, was man nehmen soll.

Um mehr über meine Arbeit mit Shadern zu lernen, habe ich versucht,
ein optimales Modell für Farbraumkonvertierung zu finden.

Dabei habe ich mir verschiedene Methoden überlegt und diese dann in Python implementiert und geplotted.
Es wurde dabei sowohl auf Geschwindigkeit (Benchmark) als auch auf das Aussehen der Plots geachtet.

Die verschiedenen Methoden, die ich mir überlegt habe, habe ich in einem Diagramm auf OneNote dargestellt.
Dieses Diagramm habe ich Ihnen als PDF angefügt.
Für die verschiedenen Methoden existieren Modelle in meinem Kopf,
sie sind allerdings etwas schwierig schriftlich erklärbar.
Bei Rückfragen stehe ich Ihnen allerding gerne persönlich zur Verfügung,
um Ihnen persönlich mit Stift und Papier aufzuzeichnen und parallel zu erklären,
was ich da gemacht habe.

Das bisherige Ergebnis: https://github.com/General-Lindor/Color_space_conversion_with_gamma_correction/tree/main
Der Konsens bisher ist, dass das "Color_Standard"-Modell best practice ist (daher der Name).
Das ist das Modell, das ich hier benutzt habe: https://github.com/General-Lindor/LibraryCollection/blob/main/Python/Color%20Space%20Conversion/color.py

Der pure Python-Code für das Standardmodell liegt bei.
    

Die Reise ist aber noch nicht abgeschlossen und es gibt noch einige frische Ideen, die auf ihre Umsetzung warten.

Abschließend noch das Tutorial, das ich geschrieben habe:
https://darkmatters.org/forums/index.php?/topic/72344-guide-correct-rgb-to-hsl-conversion-with-gamma-correction/