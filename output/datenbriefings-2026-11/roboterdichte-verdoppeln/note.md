+++
title = "Roboterdichte verdoppeln: Was 600 statt 294 Roboter bedeuten würden"
description = "Die Schweiz hat 294 Industrieroboter pro 10'000 Beschäftigte, weniger als Deutschland oder Japan. Die Forschung zeigt: Mehr Roboter heben die Produktivität. Ob Stellen verloren gehen, hängt stark davon ab, wie der Übergang organisiert wird."
slug = "roboterdichte-verdoppeln"
date = 2026-11-08
template = "notiz.html"

[extra]
category = "datenbriefing"
evidence = "mittel"
tags = ["robotik", "industrie", "produktivitaet", "beschaeftigung", "ifr"]
charts = ["roboter_dichte_vergleich.svg", "roboter_industrie_beschaeftigung.svg", "roboter_industrie_anteil.svg"]
pillar = "robotik"
+++

Mit 294 Industrierobotern pro 10'000 Beschäftigten liegt die Schweiz 2024 knapp in den weltweiten Top 10, aber deutlich hinter Südkorea (1'220), Singapur (818), Deutschland (449) und Japan (446). Eine Verdoppelung auf rund 600 würde die Schweiz vor Deutschland bringen. Die Industrie beschäftigt seit 2010 recht stabil rund 630'000 bis 650'000 Personen, ihr Anteil an allen Erwerbstätigen sinkt aber. Studien aus vergleichbaren Ländern zeigen klare Produktivitätsgewinne durch Roboter; die Wirkung auf die Beschäftigung ist gemischt und hängt vom Umbau ab.

<!-- more -->

---

## Methodik

Die Roboterdichte stammt aus dem World Robotics Report 2025 der International Federation of Robotics (IFR): installierte Industrieroboter pro 10'000 Beschäftigte in der verarbeitenden Industrie, Stand 2024. Die Werte für China basieren laut IFR auf revidierten Arbeitsmarktdaten und sind mit früheren Ausgaben nicht vergleichbar; aus diesem Grund zeigen wir keine Zeitreihe der Roboterdichte. Die Beschäftigung stammt aus der Schweizerischen Arbeitskräfteerhebung (SAKE) des BFS, Abschnitte B–E (Industrie, Bergbau, Energie- und Wasserversorgung). Bis 2009 sind es Werte des 2. Quartals, ab 2010 Jahresdurchschnitte; der Bruch ist im Diagramm sichtbar. Die Wirkungen von Robotern übernehmen wir aus begutachteten Studien zu anderen Ländern; für die Schweiz gibt es keine vergleichbare Untersuchung.

---

### Die Schweiz im Vergleich

{% chart(spec="roboter_dichte_vergleich", alt="Roboterdichte 2024 nach Ländern, mit dem Ziel einer verdoppelten Schweizer Dichte") %}
Die Schweiz liegt mit 294 über dem EU-Durchschnitt (231) und dem Weltdurchschnitt (132), aber unter Ländern mit ähnlich hohem Lohnniveau und starker Exportindustrie wie Deutschland, Japan, Schweden und Dänemark. Ein Ziel von rund 600 (doppelter Wert von 2024) ist ambitioniert, liegt aber klar unter Südkorea und Singapur. Gerade ein Hochlohnland mit Fachkräftemangel hat einen starken Grund, Produktion zu automatisieren statt sie zu verlagern.
{% end %}

---

### Industriebeschäftigung: stabil in absoluten Zahlen

{% chart(spec="roboter_industrie_beschaeftigung", alt="Erwerbstätige in Industrie und Bergbau in der Schweiz 1991 bis 2025") %}
Von 1991 bis 2004 sank die Zahl der Erwerbstätigen in den Abschnitten B–E von rund 798'000 auf 634'000. Seither schwankt sie in einem engen Band; 2025 waren es 633'600. Die Industrie ist also nicht verschwunden; seit zwei Jahrzehnten hält sie ihre Beschäftigung in absoluten Zahlen.
{% end %}

---

### Industrieanteil: langsam sinkend

{% chart(spec="roboter_industrie_anteil", alt="Anteil von Industrie und Bergbau an allen Erwerbstätigen 1991 bis 2025") %}
Weil die Gesamtbeschäftigung wuchs (2025: 4,89 Mio. Erwerbstätige), sank der Anteil der Industrie von 21,2 Prozent (1991) auf 13,0 Prozent (2025). Mehr Automatisierung muss diesen Trend nicht beschleunigen: Wo Produktion dank Robotern im Land bleibt oder zurückkommt, bleiben auch Stellen in Planung, Wartung, Qualitätssicherung und Zulieferung.
{% end %}

---

### Was die Forschung über Roboter, Produktivität und Arbeit zeigt

- **Produktivität:** In 17 Ländern von 1993 bis 2007 trug der zunehmende Robotereinsatz rund 0,37 Prozentpunkte zum jährlichen Wachstum der Arbeitsproduktivität bei, steigerte die totale Faktorproduktivität und senkte Produktpreise. Die Gesamtbeschäftigung sank nicht signifikant, der Anteil gering qualifizierter Arbeit aber schon (Graetz und Michaels, 2018).
- **Deutschland:** Stellenverluste in der Industrie durch Roboter wurden durch neue Stellen im Dienstleistungssektor vollständig ausgeglichen. Bestehende Beschäftigte blieben häufiger im selben Betrieb und übernahmen neue Aufgaben; getroffen wurden vor allem junge Berufseinsteigende, die gar nicht erst in die Industrie kamen (Dauth et al., 2021).
- **USA:** Ein zusätzlicher Roboter pro 1'000 Beschäftigte senkte in stark betroffenen Regionen die Beschäftigungsquote um 0,2 Prozentpunkte und die Löhne um 0,42 Prozent (Acemoglu und Restrepo, 2020).

Die Unterschiede zwischen Deutschland und den USA zeigen: Der Arbeitsmarkt passt sich dort besser an, wo Betriebe ihre Leute weiterbilden und intern umsetzen. Diese Befunde lassen sich nicht eins zu eins auf die Schweiz übertragen; sie zeigen aber, worauf es ankommt.

---

## Was das für die Politik heisst

- **Ein messbares Ziel:** Roboterdichte bis 2035 auf rund 600 verdoppeln und jährlich anhand der IFR-Daten ausweisen: [Reindustrialisierung mit Robotik](@/robotik.md).
- **KMU gezielt unterstützen:** Grosse Exportfirmen automatisieren selbst. Der Hebel liegt bei KMU, etwa mit geteilten Testzentren, Leasing-Modellen und Beratung.
- **Übergang im Betrieb organisieren:** Das deutsche Muster, Umschulung im selben Betrieb statt Entlassung, sollte mit Weiterbildungsgutscheinen und Lehrberufen für Robotik und Wartung gestützt werden: [Arbeit ohne Angst](@/uebergaenge.md).

---

## Quellen

1. International Federation of Robotics (IFR): Robot density surges in Europe, Asia and Americas (World Robotics 2025), 8. April 2026. https://ifr.org/ifr-press-releases/news/robot-density-surges-in-europe-asia-and-americas
2. Bundesamt für Statistik (BFS), SAKE: Erwerbstätige nach Wirtschaftsabschnitten (T 03.02.01.20), 1991–2025. https://www.bfs.admin.ch/asset/de/36494612
3. Graetz, G. und Michaels, G. (2018): Robots at Work. Review of Economics and Statistics 100(5), 753–768. https://doi.org/10.1162/rest_a_00754
4. Dauth, W., Findeisen, S., Suedekum, J. und Woessner, N. (2021): The Adjustment of Labor Markets to Robots. Journal of the European Economic Association 19(6), 3104–3153. https://doi.org/10.1093/jeea/jvab012
5. Acemoglu, D. und Restrepo, P. (2020): Robots and Jobs: Evidence from US Labor Markets. Journal of Political Economy 128(6), 2188–2244. https://doi.org/10.1086/705716
