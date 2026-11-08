import json, csv, os, sys
BASE = sys.argv[1]
CONFIG = {"font": "Switzer, system-ui, sans-serif", "view": {"stroke": "transparent"}}

def spec(title, values, mark, encoding, height=380, **extra):
    s = {"$schema": "https://vega.github.io/schema/vega-lite/v5.json", "config": CONFIG,
         "data": {"values": values}, "encoding": encoding, "height": height,
         "mark": mark, "title": title, "width": 720}
    s.update(extra)
    return s

notes = {}

# ---------- 1. egovernment-rang-26 ----------
rang = [{"Jahr": y, "Rang": r, "EGDI": v} for y, r, v in
        [(2018, 15, 0.85), (2020, 16, 0.8907), (2022, 23, 0.8752), (2024, 26, 0.9004)]]
teil = []
for land, osi, tii, hci in [("Schweiz", 0.8408, 0.9576, 0.9026), ("Dänemark", 0.9992, 0.9966, 0.9584),
                            ("Estland", 0.9954, 0.9731, 0.9497), ("Südkorea", 1.0000, 0.9917, 0.9120),
                            ("Singapur", 0.9831, 0.9881, 0.9362), ("Deutschland", 0.9238, 0.9236, 0.9672),
                            ("Österreich", 0.8383, 0.9810, 0.9003)]:
    for k, v in [("Online-Dienste (OSI)", osi), ("Telekom-Infrastruktur (TII)", tii), ("Humankapital (HCI)", hci)]:
        teil.append({"Land": land, "Teilindex": k, "Wert": v})
komp_names = ["Institutioneller Rahmen", "Dienstangebot", "Inhalte", "E-Partizipation", "Technologie"]
komp = []
for land, vals in [("Schweiz", [1.0, 0.8072, 0.8889, 0.8219, 0.6250]), ("Dänemark", [1.0, 0.9880, 1.0, 0.9863, 0.8750]),
                   ("Estland", [1.0, 1.0, 1.0, 0.9589, 0.8750]), ("Deutschland", [1.0, 0.8434, 0.8889, 0.9726, 0.8750])]:
    for n, v in zip(komp_names, vals):
        komp.append({"Land": land, "Komponente": n, "Wert": v})

notes["egovernment-rang-26"] = {
 "egov_rang_verlauf": (rang, spec("Schweiz im UN-E-Government-Index: Rang 2018–2024", rang,
    {"type": "line", "point": True, "strokeWidth": 2},
    {"x": {"field": "Jahr", "type": "ordinal", "title": "Erhebungsjahr"},
     "y": {"field": "Rang", "type": "quantitative", "title": "Rang (von 193 Staaten)", "scale": {"reverse": True, "domain": [1, 30]}},
     "tooltip": [{"field": "Jahr"}, {"field": "Rang"}, {"field": "EGDI", "title": "EGDI-Wert", "format": ".2f"}]}, height=320)),
 "egov_teilindizes_2024": (teil, spec("EGDI-Teilindizes 2024 im Vergleich (0–1)", teil,
    {"type": "bar", "cornerRadiusEnd": 3},
    {"y": {"field": "Land", "type": "nominal", "title": None,
           "sort": ["Dänemark", "Estland", "Singapur", "Südkorea", "Deutschland", "Österreich", "Schweiz"]},
     "yOffset": {"field": "Teilindex", "type": "nominal"},
     "x": {"field": "Wert", "type": "quantitative", "title": "Indexwert", "scale": {"domain": [0.6, 1.0]}},
     "color": {"field": "Teilindex", "type": "nominal", "title": None, "legend": {"orient": "bottom"}},
     "tooltip": [{"field": "Land"}, {"field": "Teilindex"}, {"field": "Wert", "format": ".3f"}]}, height=460)),
 "egov_osi_komponenten_2024": (komp, spec("Online-Service-Index 2024 nach Komponenten (0–1)", komp,
    {"type": "bar", "cornerRadiusEnd": 3},
    {"x": {"field": "Komponente", "type": "nominal", "title": None, "sort": komp_names, "axis": {"labelAngle": 0}},
     "xOffset": {"field": "Land", "type": "nominal", "sort": ["Schweiz", "Deutschland", "Dänemark", "Estland"]},
     "y": {"field": "Wert", "type": "quantitative", "title": "Indexwert", "scale": {"domain": [0, 1]}},
     "color": {"field": "Land", "type": "nominal", "title": None, "sort": ["Schweiz", "Deutschland", "Dänemark", "Estland"], "legend": {"orient": "bottom"}},
     "tooltip": [{"field": "Land"}, {"field": "Komponente"}, {"field": "Wert", "format": ".3f"}]}, height=360)),
}

# ---------- 2. talentvisa-im-vergleich ----------
zeit = [
 {"Programm": "Ziel Die Zukunft (10 Arbeitstage)", "Wochen": 2, "Grundlage": "Programmziel"},
 {"Programm": "Singapur: ONE Pass", "Wochen": 4, "Grundlage": "«within 4 weeks for most cases» (MOM)"},
 {"Programm": "Hongkong: Top Talent Pass", "Wochen": 4, "Grundlage": "normalerweise rund 4 Wochen (ImmD)"},
 {"Programm": "UK: Global Talent", "Wochen": 8, "Grundlage": "Endorsement 2–5 Wochen + Visum rund 3 Wochen (GOV.UK)"},
 {"Programm": "Schweiz: Drittstaaten-Bewilligung", "Wochen": 8, "Grundlage": "in der Regel 6–8 Wochen (SEM)"},
]
erteil = [
 {"Programm": "Schweiz: Drittstaatenkontingente genutzt", "Anzahl": 6290, "Art": "Schätzung (74 % von 8'500)"},
 {"Programm": "UK: Global Talent (Hauptgesuchstellende)", "Anzahl": 3877, "Art": "amtlich"},
 {"Programm": "Singapur: ONE Pass ausgestellt", "Anzahl": 3000, "Art": "amtlich (gerundet)"},
 {"Programm": "Hongkong: Top Talent Pass bewilligt", "Anzahl": 38900, "Art": "Schätzung (Ø pro Jahr 2023–Jan. 2026)"},
]
uk = []
for y, m, d in [(2019, 794, 378), (2020, 905, 476), (2021, 1847, 1246), (2022, 2975, 2301),
                (2023, 4112, 3250), (2024, 3878, 2812), (2025, 3903, 2750)]:
    uk += [{"Jahr": y, "Gruppe": "Hauptgesuchstellende", "Visa": m}, {"Jahr": y, "Gruppe": "Familienangehörige", "Visa": d}]
notes["talentvisa-im-vergleich"] = {
 "talent_bearbeitungszeit": (zeit, spec("Richtwert für die Bearbeitungsdauer (obere Grenze, Wochen)", zeit,
    {"type": "bar", "cornerRadiusEnd": 4},
    {"y": {"field": "Programm", "type": "nominal", "title": None, "sort": None},
     "x": {"field": "Wochen", "type": "quantitative", "title": "Wochen", "scale": {"domain": [0, 10]}},
     "tooltip": [{"field": "Programm"}, {"field": "Wochen"}, {"field": "Grundlage"}]}, height=260)),
 "talent_erteilungen": (erteil, spec("Bewilligungen pro Jahr, 2024 bzw. Durchschnitt (nicht direkt vergleichbar)", erteil,
    {"type": "bar", "cornerRadiusEnd": 4},
    {"y": {"field": "Programm", "type": "nominal", "title": None, "sort": "-x"},
     "x": {"field": "Anzahl", "type": "quantitative", "title": "Anzahl pro Jahr", "axis": {"format": "d"}},
     "color": {"field": "Art", "type": "nominal", "title": None, "legend": {"orient": "bottom"}},
     "tooltip": [{"field": "Programm"}, {"field": "Anzahl", "format": "d"}, {"field": "Art"}]}, height=240)),
 "talent_uk_verlauf": (uk, spec("UK Global Talent: erteilte Einreisevisa 2019–2025", uk,
    {"type": "line", "point": True, "strokeWidth": 2},
    {"x": {"field": "Jahr", "type": "ordinal", "title": "Jahr"},
     "y": {"field": "Visa", "type": "quantitative", "title": "Erteilte Visa", "axis": {"format": "d"}},
     "color": {"field": "Gruppe", "type": "nominal", "title": None, "legend": {"orient": "bottom"}},
     "tooltip": [{"field": "Jahr"}, {"field": "Gruppe"}, {"field": "Visa", "format": "d"}]}, height=340)),
}

# ---------- 3. transparent-per-gesetz ----------
tot = {2006: 95, 2007: 249, 2008: 221, 2009: 232, 2010: 239, 2011: 470, 2012: 518, 2013: 470, 2014: 582, 2015: 600,
       2016: 554, 2017: 586, 2018: 647, 2019: 916, 2020: 1193, 2021: 1385, 2022: 1180, 2023: 1738, 2024: 2232, 2025: 2145}
gesuche = [{"Jahr": y, "Gesuche": n} for y, n in tot.items()]
cats = ["vollständig gewährt", "teilweise gewährt/aufgeschoben", "vollständig verweigert", "zurückgezogen", "hängig", "kein amtliches Dokument"]
shares = {2019: [59, 19, 9, 4, 5, 4], 2020: [51, 24, 9, 3, 7, 6], 2021: [50, 23, 9, 4, 6, 8], 2022: [53, 20, 8, 5, 6, 8],
          2023: [48, 23, 10, 4, 6, 9], 2024: [52, 21, 8, 6, 5, 8], 2025: [39, 25, 10, 4, 9, 13]}
ergeb = []
for y, s in shares.items():
    for i, (c, v) in enumerate(zip(cats, s)):
        ergeb.append({"Jahr": y, "Ergebnis": c, "Anteil": v, "Reihenfolge": i})
schl = [{"Jahr": y, "Anteil": v} for y, v in [(2018, 50), (2019, 57), (2020, 43), (2021, 42), (2022, 25), (2023, 27), (2024, 28), (2025, 24)]]
notes["transparent-per-gesetz"] = {
 "transparenz_gesuche_verlauf": (gesuche, spec("Zugangsgesuche nach BGÖ an die Bundesverwaltung, 2006–2025", gesuche,
    {"type": "line", "point": True, "strokeWidth": 2},
    {"x": {"field": "Jahr", "type": "ordinal", "title": "Jahr"},
     "y": {"field": "Gesuche", "type": "quantitative", "title": "Gesuche pro Jahr", "axis": {"format": "d"}},
     "tooltip": [{"field": "Jahr"}, {"field": "Gesuche", "format": "d"}]}, height=340)),
 "transparenz_ergebnisse": (ergeb, spec("Ausgang der Zugangsgesuche, 2019–2025 (Anteil in %)", ergeb,
    {"type": "bar"},
    {"x": {"field": "Jahr", "type": "ordinal", "title": "Jahr", "axis": {"labelAngle": 0}},
     "y": {"field": "Anteil", "type": "quantitative", "title": "Anteil (%)", "stack": "zero", "scale": {"domain": [0, 100]}},
     "color": {"field": "Ergebnis", "type": "nominal", "title": None, "sort": cats, "legend": {"orient": "bottom", "columns": 3}},
     "order": {"field": "Reihenfolge", "type": "quantitative"},
     "tooltip": [{"field": "Jahr"}, {"field": "Ergebnis"}, {"field": "Anteil", "title": "Anteil (%)"}]}, height=360)),
 "transparenz_schlichtung_frist": (schl, spec("Schlichtungsverfahren beim EDÖB: Anteil innert 30 Tagen erledigt", schl,
    {"type": "bar", "cornerRadiusEnd": 4},
    {"x": {"field": "Jahr", "type": "ordinal", "title": "Jahr", "axis": {"labelAngle": 0}},
     "y": {"field": "Anteil", "type": "quantitative", "title": "Anteil (%)", "scale": {"domain": [0, 100]}},
     "tooltip": [{"field": "Jahr"}, {"field": "Anteil", "title": "Anteil (%)"}]}, height=300)),
}

for slug, charts in notes.items():
    d = os.path.join(BASE, slug); os.makedirs(d, exist_ok=True)
    rows = []
    for name, (vals, s) in charts.items():
        json.dump(s, open(os.path.join(d, name + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        for v in vals:
            rows.append({"chart": name, **v})
    keys = []
    for r in rows:
        for k in r:
            if k not in keys: keys.append(k)
    with open(os.path.join(d, "data.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=keys); w.writeheader(); w.writerows(rows)
    print(slug, list(charts))
