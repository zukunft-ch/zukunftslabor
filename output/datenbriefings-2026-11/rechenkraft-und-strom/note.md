+++
title = "Rechenkraft und Strom: Was zehnmal mehr öffentliche KI-Kapazität braucht"
description = "Rechenzentren brauchten 2024 rund 2,1 TWh oder 3,6 Prozent des Schweizer Stroms. Eine Verzehnfachung der öffentlichen Rechenkraft auf Basis von Alps würde nach unserer Schätzung 0,6 bis 0,8 TWh pro Jahr benötigen: planbar, aber nicht nebenbei."
slug = "rechenkraft-und-strom"
date = 2026-11-08
template = "notiz.html"

[extra]
category = "datenbriefing"
evidence = "mittel"
tags = ["rechenkraft", "ki", "strom", "rechenzentren", "cscs", "bfe"]
charts = ["rechenkraft_rechenzentren_strom.svg", "rechenkraft_landeserzeugung.svg", "rechenkraft_verzehnfachung.svg"]
pillar = "souveraene-ki"
+++

Die Rechenzentren der Schweiz verbrauchten 2024 rund 2,1 Terawattstunden Strom, 3,6 Prozent des Landesverbrauchs. Bis 2030 rechnet das Bundesamt für Energie mit 2,5 bis 3,2 TWh, im Maximalszenario mit 3,5 TWh. Der grösste öffentliche KI-Rechner des Landes, Alps am CSCS in Lugano, zog bei der offiziellen Leistungsmessung rund 7,1 Megawatt. Zehnmal so viel öffentliche Rechenkraft mit heutiger Technik würde nach unserer Schätzung 0,6 bis 0,8 TWh pro Jahr brauchen, also gut 1 Prozent des heutigen Endverbrauchs.

<!-- more -->

---

## Methodik

Wir verbinden drei amtliche bzw. primäre Quellen: die Studie von EnergieSchweiz/BFE zum Stromverbrauch der Rechenzentren (Mai 2026), die Elektrizitätsbilanz 2025 des BFE und die gemessene Leistungsaufnahme von Alps in der TOP500-Liste (7'124 kW, Messung nach Level 3). Alps umfasst 10'752 GH200-Superchips von NVIDIA in 2'688 Knoten (CSCS).

Die Hochrechnung für eine Verzehnfachung ist eine **eigene Schätzung** mit bewusst einfachen Annahmen: Dauerbetrieb während 8'760 Stunden pro Jahr bei der gemessenen Linpack-Leistung, linear skaliert. Für Kühlung und Gebäudetechnik nehmen wir einen Zuschlag von 30 Prozent an (PUE 1,3); das ist eine Annahme, kein Messwert für Alps. Neuere Chips liefern mehr Rechenleistung pro Watt, darum ist die Schätzung eher eine Obergrenze für «zehnmal Alps».

---

### Rechenzentren wachsen, aber planbar

{% chart(spec="rechenkraft_rechenzentren_strom", alt="Stromverbrauch der Schweizer Rechenzentren 2019 und 2024 sowie BFE-Szenarien für 2030") %}
Von 2019 bis 2024 stieg der Verbrauch der Rechenzentren von 1,77 auf 2,1 TWh, im Schnitt um 3,4 Prozent pro Jahr. Das Wachstum kommt aus den grossen kommerziellen Rechenzentren (44 Prozent des Verbrauchs), deren Bedarf sich bis 2030 mehr als verdoppeln könnte. Firmeneigene Rechenzentren (56 Prozent) stagnieren oder sinken, weil Lasten in die Cloud wandern. Das BFE beziffert das verbleibende Effizienzpotenzial auf rund 0,8 TWh, fast 38 Prozent des heutigen Verbrauchs.
{% end %}

---

### Die Ausgangslage im Netz

{% chart(spec="rechenkraft_landeserzeugung", alt="Schweizer Stromproduktion 2025 nach Quelle in Terawattstunden") %}
2025 erzeugte die Schweiz 67,5 TWh Strom, bei einem Endverbrauch von 58,0 TWh (plus 0,8 Prozent gegenüber 2024). 55,5 Prozent stammten aus Wasserkraft, davon 31,3 Prozentpunkte aus Speicherkraftwerken, 27,2 Prozent aus Kernenergie und 11,8 Prozent aus Photovoltaik. Die Jahresbilanz sagt allerdings wenig über den Winter: Rechenzentren laufen das ganze Jahr mit fast konstanter Last, also auch dann, wenn die Produktion im Inland knapp ist.
{% end %}

---

### Was eine Verzehnfachung kosten würde, in Strom

{% chart(spec="rechenkraft_verzehnfachung", alt="Geschätzter Jahresstrombedarf von zehnmal Alps im Vergleich zum Verbrauch aller Rechenzentren") %}
Rechnung (Schätzung): 7,124 MW × 8'760 h ergibt rund 62 GWh pro Jahr für Alps. Zehnmal so viel sind 71 MW und 0,62 TWh, mit 30 Prozent Kühlzuschlag 93 MW und 0,81 TWh. Das entspricht 1,1 bis 1,4 Prozent des Endverbrauchs 2025, weniger als der Zuwachs, den das BFE im hohen Szenario ohnehin für alle Rechenzentren bis 2030 erwartet (+1,1 TWh), und etwa so viel wie das vom BFE ausgewiesene Effizienzpotenzial der bestehenden Rechenzentren. Zum Vergleich: Laut Internationaler Energieagentur verbraucht ein typisches KI-Rechenzentrum so viel Strom wie 100'000 Haushalte, die grössten im Bau befindlichen das Zwanzigfache.
{% end %}

---

## Was das für die Politik heisst

- **Energie und Rechenkraft zusammen planen.** Ein öffentliches KI-Programm in der Grössenordnung von 70 bis 90 MW ist für das Schweizer Netz machbar, braucht aber feste Standorte mit Netzanschluss, Kühlung und Abwärmenutzung. Das gehört in dieselbe Planung wie der Ausbau der Winterproduktion: [Energie & Infrastruktur-Resilienz](@/energy-resilience.md).
- **Effizienz zuerst heben.** Das ausgewiesene Effizienzpotenzial von rund 0,8 TWh in bestehenden Rechenzentren entspricht etwa dem geschätzten Bedarf einer Verzehnfachung der öffentlichen Rechenkraft. Verbindliche Effizienzkennzahlen für grosse Rechenzentren schaffen Platz im Netz.
- **Öffentliche Rechenkraft messbar ausbauen.** Ziel und Fortschritt in Megawatt und Rechenleistung ausweisen, mit offenem Zugang für Hochschulen, KMU und Verwaltung: [Souveräne KI & Rechenkraft](@/souveraene-ki.md).

---

## Quellen

1. Bundesamt für Energie / EnergieSchweiz: Stromverbrauch der Rechenzentren in der Schweiz, Medienmitteilung vom 7. Mai 2026. https://www.admin.ch/de/newnsb/GV-_d7OgIlqjfQDGZqbkN
2. Bundesamt für Energie: Elektrizitätsbilanz 2025, Medienmitteilung vom 18. Juni 2026. https://www.admin.ch/de/newnsb/YQtEZcK-D9fQ
3. TOP500: Alps, HPE Cray EX254n, CSCS (Leistungsaufnahme 7'124 kW, Liste November 2024 bis Juni 2026). https://www.top500.org/system/180259/
4. CSCS: Alps hardware (2'688 Knoten, 10'752 GH200). https://docs.cscs.ch/alps/hardware/
5. Internationale Energieagentur (IEA): Energy and AI, Executive Summary, 2025. https://www.iea.org/reports/energy-and-ai/executive-summary
