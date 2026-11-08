+++
title = "Von Rang 16 auf Rang 26: Warum die Schweiz im E-Government zurückfällt"
description = "Im UN-E-Government-Index fiel die Schweiz von Rang 16 (2020) auf 23 (2022) und 26 (2024). Infrastruktur und Bildung sind stark, die Lücke liegt bei den Online-Diensten des Staates."
slug = "egovernment-rang-26"
date = 2026-11-08
template = "notiz.html"

[extra]
category = "datenbriefing"
evidence = "stark"
tags = ["e-government", "offener-staat", "e-id", "egdi", "vergleich"]
charts = ["egov_rang_verlauf.svg", "egov_teilindizes_2024.svg", "egov_osi_komponenten_2024.svg"]
pillar = "offener-staat"
+++

Im E-Government Development Index (EGDI) der Vereinten Nationen ist die Schweiz von Rang 16 (2020) über Rang 23 (2022) auf Rang 26 (2024) von 193 Staaten zurückgefallen, obwohl ihr Indexwert leicht stieg (0,89 auf 0,90). Andere Länder werden schlicht schneller besser. Bei Infrastruktur und Bildung liegt die Schweiz nahe an der Spitze; die Lücke liegt fast vollständig beim Online-Angebot des Staates. Die staatliche E-ID, im September 2025 knapp angenommen, hat seit Juni 2026 kein Startdatum mehr.

<!-- more -->

---

## Methodik

Der EGDI ist der Durchschnitt aus drei gleich gewichteten Teilindizes zwischen 0 und 1: Online-Service-Index (OSI, Angebot und Qualität staatlicher Online-Dienste), Telecommunication Infrastructure Index (TII) und Human Capital Index (HCI). Alle Werte stammen aus den Länderprofilen des UN E-Government Knowledge Base (Erhebungen 2018–2024). Verglichen werden die Schweiz, Dänemark, Estland, Südkorea, Singapur, Deutschland und Österreich. Wichtig: 2024 hat die UNO die Methodik angepasst (TII mit Erschwinglichkeit statt Festnetz-Breitband, HCI mit zusätzlicher Komponente E-Government-Kompetenz). Absolute Werte sind über die Jahre daher nur eingeschränkt vergleichbar; Ränge innerhalb eines Jahrgangs schon.

---

### Ein Rückfall auf hohem Niveau

{% chart(spec="egov_rang_verlauf", alt="Rang der Schweiz im UN-E-Government-Index 2018 bis 2024") %}
2018 lag die Schweiz auf Rang 15, 2020 auf Rang 16, 2022 auf Rang 23 und 2024 auf Rang 26. Der EGDI-Wert blieb dabei fast stabil (2020: 0,8907; 2022: 0,8752; 2024: 0,9004). Der Rückfall ist also relativ: Die Schweiz stagniert, während Länder wie Singapur (2022: Rang 12, 2024: Rang 3), Estland (8 auf 2) und Deutschland (22 auf 12) deutlich zulegen. Österreich fiel im gleichen Zeitraum von Rang 20 auf 22.
{% end %}

---

### Die Lücke liegt beim Staat, nicht bei der Bevölkerung

{% chart(spec="egov_teilindizes_2024", alt="EGDI-Teilindizes 2024 für sieben Länder") %}
Bei Telekom-Infrastruktur (0,958) und Humankapital (0,903) liegt die Schweiz im Feld der Spitzenländer. Beim Online-Service-Index erreicht sie dagegen nur 0,841, gegenüber 0,999 (Dänemark), 0,995 (Estland), 1,000 (Südkorea) und 0,983 (Singapur). Auch Deutschland (0,924) liegt klar vorn; nur Österreich (0,838) ist ähnlich schwach. Der OSI der Schweiz lag 2020 bei 0,829 und 2022 bei 0,768. Das zeigt: Netz und Bildung sind vorhanden, was fehlt, ist das digitale Angebot der Verwaltung.
{% end %}

---

### Wo genau der Online-Service-Index Punkte verliert

{% chart(spec="egov_osi_komponenten_2024", alt="Komponenten des Online-Service-Index 2024: Schweiz, Deutschland, Dänemark, Estland") %}
Beim institutionellen Rahmen (Strategien, Gesetze) erreicht die Schweiz wie alle Vergleichsländer den Höchstwert. Die Abstände entstehen bei der Umsetzung: Dienstangebot 0,81 (Estland 1,00, Dänemark 0,99), Inhalte 0,89 (Estland und Dänemark 1,00), E-Partizipation 0,82 und vor allem Technologie 0,63 (alle drei Vergleichsländer 0,88). Die Schweiz hat also die Papiere, aber zu wenige durchgängig digitale Verfahren.
{% end %}

---

### E-ID: angenommen, aber ohne Startdatum

Die Stimmberechtigten haben das E-ID-Gesetz am 28. September 2025 mit 50,4 Prozent Ja angenommen. Im Februar 2026 nannte der Bund den 1. Dezember 2026 als Start. Am 30. Juni 2026 hat er diesen Termin aufgehoben: Wegen neuer KI-Risiken (Deepfakes, Schadsoftware auf Endgeräten) soll die Online-Ausstellung zusätzlich abgesichert werden. Ein neues Datum gibt es nicht; die Vertrauensinfrastruktur soll im ersten Halbjahr 2027 in Betrieb gehen. Die Gründe sind nachvollziehbar, die Folge für den Index ist aber klar: Ohne breit genutzte digitale Identität bleiben durchgängige Online-Verfahren die Ausnahme.

### Was die Spitzenländer anders machen

- **Gemeinsame Datendrehscheibe:** In Estland verbindet X-Road öffentliche und private Register; laut e-Estonia laufen darüber rund 2,2 Mrd. Transaktionen pro Jahr. Behörden fragen Daten untereinander ab, statt sie erneut bei der Bevölkerung einzufordern (Once-only).
- **Digitale Identität im Alltag:** Singpass zählt 5 Mio. Nutzende und über 41 Mio. Transaktionen pro Monat; mit Myinfo werden Formulare automatisch vorausgefüllt.
- **Digitaler Kanal als Standard:** In Dänemark müssen Bevölkerung und Unternehmen gesetzlich Digital Post empfangen können; wer nicht digital kommunizieren kann, erhält weiterhin Papier.

Auch die Schweiz hat eine Grundlage: Seit dem 1. Januar 2024 gilt das EMBAG mit dem Grundsatz «open by default» für Verwaltungsdaten; die Übergangsfrist dafür läuft Ende 2026 ab.

---

## Was das für die Politik heisst

- **Ziel messbar machen:** Bis zur UN-Erhebung 2028 zurück in die Top 15, gemessen am Online-Service-Index, nicht an Strategiepapieren: [Offener Staat](@/offener-staat.md).
- **Once-only gesetzlich verankern:** Daten, die eine Behörde bereits hat, darf keine andere erneut verlangen; der Austausch läuft über dokumentierte Schnittstellen (API-by-default).
- **E-ID mit Zeitplan:** Die Sicherheitsarbeiten offen dokumentieren und ein verbindliches Startdatum mit Meilensteinen veröffentlichen.
- **EMBAG-Frist einhalten:** Ab 2027 öffentlich ausweisen, welche Bundesstellen ihre Daten tatsächlich offen bereitstellen.

---

## Quellen

1. UN DESA, E-Government Knowledge Base: Länderprofil Schweiz (Erhebungen 2020, 2022, 2024). https://publicadministration.un.org/egovkb/en-us/Data/Country-Information/id/166-Switzerland
2. UN DESA, Länderprofile Dänemark, Estland, Südkorea, Singapur, Deutschland, Österreich (Erhebung 2024). https://publicadministration.un.org/egovkb/en-us/Data/Country-Information/id/48-Denmark (analog id/57, 138, 154, 65, 10)
3. UN DESA: E-Government Survey 2024 (Methodik, Technical Appendix). https://publicadministration.un.org/egovkb/en-us/Reports/UN-E-Government-Survey-2024
4. Bundesrat: E-ID-Gesetz, Volksabstimmung vom 28. September 2025. https://www.admin.ch/en/e-id-act
5. EJPD: Akzeptanz der E-ID mit zusätzlichen Massnahmen stärken, 25. Februar 2026. https://www.ejpd.admin.ch/de/newnsb/L6Nbf7gStnDm
6. Bundesamt für Justiz: Neuer Zeitplan für die Einführung der E-ID und der Vertrauensinfrastruktur, 30. Juni 2026. https://www.admin.ch/de/newnsb/4ZNYpSk3J1-U
7. e-Estonia: X-Road. https://e-estonia.com/solutions/interoperability-services/x-road/
8. GovTech Singapore: Singpass. https://www.tech.gov.sg/products-and-services/for-citizens/digital-services/singpass/
9. Agency for Digital Government (Dänemark): Digital Post. https://en.digst.dk/systems/digital-post/
10. BFS: Open Government Data, EMBAG Art. 10 und Masterplan 2024–2027. https://www.bfs.admin.ch/de/strategie-og-de
