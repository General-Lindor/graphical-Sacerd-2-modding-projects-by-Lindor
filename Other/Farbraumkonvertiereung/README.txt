Für die Berechnung von Oren-Nayar war eine Farbraumkonvertierung von RGB zu HSL notwendig.
Auf Wikipedia waren einige Formeln angegeben, wo man dann nicht wusste, was man nehmen soll.

Um mehr über meine Arbeit mit Shadern zu lernen, habe ich versucht,
ein optimales Modell für Farbraumkonvertierung zu finden.

Dabei habe ich mir verschiedene Methoden überlegt und diese dann in Python implementiert und geplotted.
Es wurde dabei sowohl auf Geschwindigkeit (Benchmark) als auch auf das Aussehen der Plots geachtet.

Die verschiedenen Methoden, die ich mir überlegt habe, habe ich in einem Diagramm auf OneNote dargestellt.
Dieses Diagramm habe ich Ihnen als PDF angefügt.

Das bisherige Ergebnis: https://github.com/General-Lindor/Color_space_conversion_with_gamma_correction/tree/main
Der Konsens bisher ist, dass das "Color_Standard"-Modell best practice ist (daher der Name).
Das ist das Modell, das ich hier benutzt habe: https://github.com/General-Lindor/LibraryCollection/blob/main/Python/Color%20Space%20Conversion/color.py

Das Modell:
RGB zu HSV:
    Value: MAX
    Saturation: MAX - MIN
    Hue: Wenn S und V gegeben hat und sich die geschlossene Kurve sämtlicher Punkte im RGB-Cube vorstellt, welche das erfüllen, dann ist die Hue eines Farbpunktes die Bogenlänge des Weges entlang dieser Kurve von Rot bis zum Farbpunkt. D.h. RGB-x00 hat für jedes x die Hue 0. Diese Methode habe ich "Hexagon" genannt.
HSV zu HSL:
    die von mir so genannte "Cone-Stretching"-Methode hat sich durchgesetzt.
    Stellt man sich HSV als Kegel vor, dann kriegt man HSL, indem man dich den Mittelpunkt des äußersten Kreises schnappt und dann langzieht.
    Mathematisch lässt sich das dann so ausdrücken (Python Code):
    def tohsl(self):
        l = self.v * (1 - (self.s * 0.5))
        if math.isclose(self.s, 0):
            return hsl(self.h, 0, l)
        if l < 0.5:
            s = (self.s) / (2 - self.s)
            return hsl(self.h, s, l)
        else:
            s = (self.s * self.v) / ((2 - (2 * self.v)) + (self.s * self.v))
            return hsl(self.h, s, l)
Aus diesen Angaben lässt sich auch die Rückkonvertierung berechnen.
    

Die Reise ist aber noch nicht abgeschlossen und es gibt noch einige frische Ideen, die auf ihre Umsetzung warten.

Abschließend noch das Tutorial, das ich geschrieben habe:
https://darkmatters.org/forums/index.php?/topic/72344-guide-correct-rgb-to-hsl-conversion-with-gamma-correction/