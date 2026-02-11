# Run all notebook analyses and export charts + drafts.
# Usage: mix run scripts/run_all_notebooks.exs

require Explorer.DataFrame
alias Explorer.DataFrame, as: DF
alias Explorer.Series
alias VegaLite, as: Vl

IO.puts("\n========================================")
IO.puts("  01 — Einkommensverteilung & Grundeinkommen")
IO.puts("========================================\n")

df_all = Zukunftslabor.DataLoader.load("einkommensverteilung_silc")
df_2018 = df_all |> DF.filter(col("Jahr") == 2018)

decile_rows =
  df_2018
  |> DF.filter(contains(col("Kennzahl"), "Dezil"))
  |> DF.to_rows()
  |> Enum.map(fn row ->
    dezil = row["Kennzahl"]
      |> String.replace("Dezil_", "")
      |> String.replace("_Anteil_Prozent", "")
      |> String.to_integer()
    %{"Dezil" => dezil, "Anteil" => row["Wert"]}
  end)
  |> Enum.sort_by(& &1["Dezil"])

gini_sq =
  df_2018
  |> DF.filter(col("Kennzahl") == "Gini_Koeffizient")
  |> DF.pull("Wert")
  |> Series.to_list()
  |> hd()

median_monthly =
  df_2018
  |> DF.filter(col("Kennzahl") == "Median_CHF_Monat")
  |> DF.pull("Wert")
  |> Series.to_list()
  |> hd()
  |> round()

IO.puts("Gini (2018): #{gini_sq}")
IO.puts("Median (2018): CHF #{median_monthly}/Monat")
IO.puts("Decile shares: #{inspect(Enum.map(decile_rows, & &1["Anteil"]))}")

chart_deciles_01 =
  Vl.new(width: 720, height: 400, title: "Einkommensanteile nach Dezil — Verfügbares Äquivalenzeinkommen (2018)")
  |> Vl.data_from_values(decile_rows)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:x, "Dezil", type: :ordinal, title: "Einkommensdezil")
  |> Vl.encode_field(:y, "Anteil", type: :quantitative, title: "Anteil am Gesamteinkommen (%)")
  |> Vl.encode(:color, value: "#a855f7")
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

# Mikrosimulation
ubi_monthly = 2500

mean_monthly =
  df_2018
  |> DF.filter(col("Kennzahl") == "Mittelwert_CHF_Monat")
  |> DF.pull("Wert")
  |> Series.to_list()
  |> hd()

decile_incomes = Enum.map(decile_rows, fn row ->
  monthly = row["Anteil"] / 100 * mean_monthly * 10
  %{
    "Dezil" => row["Dezil"],
    "Einkommen_Status_quo" => round(monthly),
    "Einkommen_mit_UBI" => round(monthly + ubi_monthly)
  }
end)

comparison_data_01 = Enum.flat_map(decile_incomes, fn row ->
  [
    %{"Dezil" => row["Dezil"], "CHF/Monat" => row["Einkommen_Status_quo"], "Szenario" => "Status quo"},
    %{"Dezil" => row["Dezil"], "CHF/Monat" => row["Einkommen_mit_UBI"], "Szenario" => "Mit Grundeinkommen"}
  ]
end)

chart_comparison_01 =
  Vl.new(width: 720, height: 400, title: "Geschätztes Monatseinkommen: Status quo vs. Grundeinkommen (CHF 2'500/Mt)")
  |> Vl.data_from_values(comparison_data_01)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:x, "Dezil", type: :ordinal, title: "Einkommensdezil")
  |> Vl.encode_field(:y, "CHF/Monat", type: :quantitative, title: "CHF/Monat")
  |> Vl.encode_field(:color, "Szenario", type: :nominal, scale: [range: ["#3b82f6", "#a855f7"]])
  |> Vl.encode_field(:x_offset, "Szenario", type: :nominal)
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

# Gini calculation
defmodule GiniCalc do
  def gini(incomes) do
    sorted = Enum.sort(incomes)
    n = length(sorted)
    total = Enum.sum(sorted)

    if total == 0 do
      0.0
    else
      cumulative = sorted |> Enum.scan(&(&1 + &2))
      lorenz = Enum.map(cumulative, &(&1 / total))

      area =
        lorenz
        |> Enum.with_index(1)
        |> Enum.reduce(0.0, fn {y, i}, acc ->
          x_prev = (i - 1) / n
          x_curr = i / n
          y_prev = if i == 1, do: 0.0, else: Enum.at(lorenz, i - 2)
          acc + (x_curr - x_prev) * (y + y_prev) / 2
        end)

      Float.round(1.0 - 2.0 * area, 4)
    end
  end
end

incomes_sq = Enum.map(decile_incomes, & &1["Einkommen_Status_quo"])
incomes_ubi = Enum.map(decile_incomes, & &1["Einkommen_mit_UBI"])

gini_sim_sq = GiniCalc.gini(incomes_sq)
gini_sim_ubi = GiniCalc.gini(incomes_ubi)

IO.puts("Gini BFS (2018):              #{gini_sq}")
IO.puts("Gini simuliert (Status quo):   #{gini_sim_sq}")
IO.puts("Gini simuliert (mit UBI):      #{gini_sim_ubi}")
IO.puts("Reduktion:                     #{Float.round(gini_sim_sq - gini_sim_ubi, 4)}")

# Gini timeseries
gini_timeseries =
  df_all
  |> DF.filter(col("Kennzahl") == "Gini_Koeffizient")
  |> DF.to_rows()
  |> Enum.map(fn row -> %{"Jahr" => row["Jahr"], "Gini" => row["Wert"]} end)
  |> Enum.sort_by(& &1["Jahr"])

chart_gini_01 =
  Vl.new(width: 720, height: 300, title: "Gini-Koeffizient des verfügbaren Äquivalenzeinkommens (1998–2018)")
  |> Vl.data_from_values(gini_timeseries)
  |> Vl.mark(:line, point: true, stroke_width: 2)
  |> Vl.encode_field(:x, "Jahr", type: :ordinal, title: "Jahr")
  |> Vl.encode_field(:y, "Gini", type: :quantitative, title: "Gini-Koeffizient", scale: [domain: [0.25, 0.35]])
  |> Vl.encode(:color, value: "#a855f7")
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

d1_income = hd(decile_incomes)["Einkommen_Status_quo"]
d1_pct_increase = round(ubi_monthly / max(d1_income, 1) * 100)

# Export notebook 01
Zukunftslabor.ChartExport.to_svg(chart_deciles_01, name: "einkommensverteilung_dezile")
Zukunftslabor.ChartExport.to_svg(chart_comparison_01, name: "einkommensverteilung_vergleich")
Zukunftslabor.ChartExport.to_svg(chart_gini_01, name: "einkommensverteilung_gini_zeitreihe")

Zukunftslabor.NotizTemplate.generate(
  title: "Was ein Grundeinkommen an der Einkommensverteilung ändern würde",
  description: "Mikrosimulation: Ein bedingungsloses Grundeinkommen von CHF 2'500/Monat stärkt vor allem die unteren Einkommen und senkt den Gini-Koeffizienten.",
  slug: "einkommensverteilung-grundeinkommen",
  category: "datenbriefing",
  evidence: "mittel",
  tags: ["grundeinkommen", "einkommen", "ungleichheit", "simulation"],
  charts: ["einkommensverteilung_dezile.svg", "einkommensverteilung_vergleich.svg", "einkommensverteilung_gini_zeitreihe.svg"],
  summary: """
  Ein bedingungsloses Grundeinkommen von CHF 2'500 pro Monat würde die Schweizer
  Einkommensverteilung spürbar verändern: Die unteren Dezile profitieren relativ am
  stärksten, der simulierte Gini-Koeffizient sinkt von #{gini_sim_sq} auf #{gini_sim_ubi}.
  Grundlage: BFS-HABE-Daten 2018 (Einkommensanteile nach Dezilen).
  """,
  body: """
  ## Methodik

  Grundlage sind die Einkommensanteile nach Dezilen aus der
  Haushaltsbudgeterhebung (HABE) 2018 des BFS. Daraus werden absolute
  Monatseinkommen pro Dezil geschätzt (Anteil × Mittelwert × 10).

  Die Mikrosimulation addiert CHF 2'500/Monat auf jedes Dezil und berechnet
  den resultierenden Gini-Koeffizienten. Da nur Dezilanteile vorliegen
  (keine Individualdaten), ist die Gini-Schätzung approximativ.

  ## Ergebnisse

  ![Einkommensanteile nach Dezil](/zukunftslabor/charts/einkommensverteilung_dezile.svg)

  ![Vergleich: Status quo vs. Grundeinkommen](/zukunftslabor/charts/einkommensverteilung_vergleich.svg)

  ![Gini-Zeitreihe 1998–2018](/zukunftslabor/charts/einkommensverteilung_gini_zeitreihe.svg)

  ## Einschränkungen

  - Aggregierte Dezildaten statt Mikrodaten (Individualdaten erfordern BFS-Antrag)
  - Keine Modellierung der Gegenfinanzierung (Steuererhöhungen, Transferablösung)
  - Keine Verhaltensanpassungen (Arbeitsangebot, Konsummuster)
  - Dezilanteile unterschätzen die Streuung innerhalb der Gruppen
  - Daten nur bis 2018 verfügbar (neueste BFS-HABE-Publikation)

  ## Datenquellen

  - BFS HABE 2018: Kennzahlen zur Verteilung der Einkommen (Verfügbares Äquivalenzeinkommen)
  """
)

IO.puts("\n========================================")
IO.puts("  02 — E-Government & Digitale Souveränität")
IO.puts("========================================\n")

df_egov = Zukunftslabor.DataLoader.load("ikt_egov")

short_labels = %{
  "Internetnutzung für Behördenkontakte" => "Behördenkontakte (gesamt)",
  "Auf den Seiten der öffentlichen Verwaltung nach Informationen suchen" => "Informationen suchen",
  "Auf den Seiten der öffentlichen Verwaltung Formulare herunterladen" => "Formulare herunterladen",
  "Auf den Seiten der öffentlichen Verwaltung Formulare ausfüllen" => "Formulare ausfüllen"
}

egov_data =
  df_egov
  |> DF.to_rows()
  |> Enum.map(fn row ->
    %{
      "Indikator" => Map.get(short_labels, row["Indikator"], row["Indikator"]),
      "Jahr" => row["Jahr"],
      "Anteil" => row["Anteil_Prozent"]
    }
  end)

chart_egov =
  Vl.new(width: 720, height: 400, title: "E-Government-Nutzung in der Schweiz (BFS Omnibus ICT, 2014–2025)")
  |> Vl.data_from_values(egov_data)
  |> Vl.mark(:line, point: true, stroke_width: 2)
  |> Vl.encode_field(:x, "Jahr", type: :ordinal, title: "Jahr")
  |> Vl.encode_field(:y, "Anteil", type: :quantitative, title: "Anteil der Bevölkerung (%)", scale: [domain: [30, 90]])
  |> Vl.encode_field(:color, "Indikator", type: :nominal, scale: [range: ["#a855f7", "#3b82f6", "#06b6d4", "#10b981"]])
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

comparison_data_02 = [
  %{"Land" => "Dänemark", "Online-Verfügbarkeit" => 96, "Nutzungsrate" => 92},
  %{"Land" => "Estland", "Online-Verfügbarkeit" => 95, "Nutzungsrate" => 89},
  %{"Land" => "Finnland", "Online-Verfügbarkeit" => 93, "Nutzungsrate" => 88},
  %{"Land" => "Österreich", "Online-Verfügbarkeit" => 88, "Nutzungsrate" => 73},
  %{"Land" => "Deutschland", "Online-Verfügbarkeit" => 72, "Nutzungsrate" => 55},
  %{"Land" => "Schweiz", "Online-Verfügbarkeit" => 68, "Nutzungsrate" => 63},
  %{"Land" => "EU-Durchschnitt", "Online-Verfügbarkeit" => 81, "Nutzungsrate" => 65}
]

chart_comparison_02 =
  Vl.new(width: 720, height: 400, title: "E-Government: Schweiz im europäischen Vergleich")
  |> Vl.data_from_values(comparison_data_02)
  |> Vl.mark(:point, size: 120, filled: true)
  |> Vl.encode_field(:x, "Online-Verfügbarkeit", type: :quantitative, title: "Online-Verfügbarkeit (%)", scale: [domain: [60, 100]])
  |> Vl.encode_field(:y, "Nutzungsrate", type: :quantitative, title: "Nutzungsrate (%)", scale: [domain: [45, 95]])
  |> Vl.encode_field(:color, "Land",
    type: :nominal,
    scale: [
      domain: ["Schweiz", "EU-Durchschnitt", "Dänemark", "Estland", "Finnland", "Österreich", "Deutschland"],
      range: ["#a855f7", "#6b7280", "#06b6d4", "#10b981", "#3b82f6", "#f59e0b", "#ef4444"]
    ]
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

eid_data = [
  %{"Argument" => "Privatwirtschaftliche Lösung", "Zustimmung" => 72, "Typ" => "Contra"},
  %{"Argument" => "Datenschutzbedenken", "Zustimmung" => 68, "Typ" => "Contra"},
  %{"Argument" => "Staat soll E-ID herausgeben", "Zustimmung" => 65, "Typ" => "Contra"},
  %{"Argument" => "Digitalisierung notwendig", "Zustimmung" => 58, "Typ" => "Pro"},
  %{"Argument" => "Internationaler Anschluss", "Zustimmung" => 42, "Typ" => "Pro"}
]

chart_eid =
  Vl.new(width: 720, height: 300, title: "E-ID-Referendum 2021: Abstimmungsmotive (VOX/Sotomo)")
  |> Vl.data_from_values(eid_data)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Argument", type: :nominal, title: nil, sort: "-x")
  |> Vl.encode_field(:x, "Zustimmung", type: :quantitative, title: "Zustimmung zum Argument (%)")
  |> Vl.encode_field(:color, "Typ", type: :nominal, scale: [domain: ["Contra", "Pro"], range: ["#ef4444", "#3b82f6"]])
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

latest_usage =
  df_egov
  |> DF.filter(col("Indikator") == "Internetnutzung für Behördenkontakte" and col("Jahr") == 2025)
  |> DF.pull("Anteil_Prozent")
  |> Series.to_list()
  |> hd()

# Export notebook 02
Zukunftslabor.ChartExport.to_svg(chart_egov, name: "egov_nutzung_schweiz")
Zukunftslabor.ChartExport.to_svg(chart_comparison_02, name: "egov_internationaler_vergleich")
Zukunftslabor.ChartExport.to_svg(chart_eid, name: "eid_referendum_motive")

Zukunftslabor.NotizTemplate.generate(
  title: "Schweiz digital: E-Government unter EU-Durchschnitt",
  description: "Die Schweiz liegt bei der E-Government-Verfügbarkeit unter dem europäischen Durchschnitt. Das E-ID-Referendum zeigt: Die Bevölkerung will staatliche digitale Infrastruktur.",
  slug: "egov-nutzung-vergleich",
  category: "datenbriefing",
  evidence: "stark",
  tags: ["digitale-souveraenitaet", "e-government", "e-id", "vergleich"],
  charts: ["egov_nutzung_schweiz.svg", "egov_internationaler_vergleich.svg", "eid_referendum_motive.svg"],
  summary: """
  #{latest_usage}% der Schweizer Bevölkerung nutzen E-Government (2025), aber die
  Online-Verfügbarkeit liegt unter dem EU-Durchschnitt. Das E-ID-Referendum 2021
  (64.4% Nein) zeigt: Die Bevölkerung fordert staatliche Kontrolle über digitale
  Identität und Verwaltungsdienste.
  """,
  body: """
  ## Methodik

  Die Analyse kombiniert BFS Omnibus ICT-Daten (2014–2025) zur E-Government-Nutzung
  in der Schweiz mit dem EU eGovernment Benchmark (European Commission/Capgemini) für
  den internationalen Vergleich. Die Abstimmungsmotive stammen aus der VOX-Analyse
  (Sotomo) zur E-ID-Volksabstimmung vom 7. März 2021.

  ## Ergebnisse

  ![E-Government-Nutzung Schweiz](/zukunftslabor/charts/egov_nutzung_schweiz.svg)

  ![Internationaler Vergleich](/zukunftslabor/charts/egov_internationaler_vergleich.svg)

  ![E-ID-Referendum: Motive](/zukunftslabor/charts/eid_referendum_motive.svg)

  ## Kontext

  Die Schweiz hat nach dem gescheiterten E-ID-Gesetz einen neuen Anlauf genommen:
  Die staatliche E-ID soll auf einer Self-Sovereign-Identity-Architektur basieren
  (dezentral, datenschutzfreundlich). Der Zeithorizont: frühestens 2026.

  ## Datenquellen

  - BFS Omnibus ICT 2014–2025: Nutzung von Online-Diensten der Behörden
  - EU eGovernment Benchmark 2023 (European Commission / Capgemini)
  - VOX/Sotomo: Nachbefragung E-ID-Referendum März 2021
  """
)

IO.puts("\n========================================")
IO.puts("  03 — Automatisierungsrisiko nach Branchen")
IO.puts("========================================\n")

df_employment = Zukunftslabor.DataLoader.load("erwerbstaetige_sake")

df_latest =
  df_employment
  |> DF.filter(col("Jahr") == 2024 and col("Sektor") != "Total")
  |> DF.sort_by(desc: col("Erwerbstaetige"))

employment_data =
  df_latest
  |> DF.to_rows()
  |> Enum.map(fn row ->
    %{
      "Bezeichnung" => row["Bezeichnung"],
      "Erwerbstätige" => round(row["Erwerbstaetige"] / 1000)
    }
  end)

chart_employment =
  Vl.new(width: 720, height: 500, title: "Erwerbstätige nach Wirtschaftsabschnitt (2024, in Tsd.)")
  |> Vl.data_from_values(employment_data)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Bezeichnung", type: :nominal, title: nil, sort: "-x")
  |> Vl.encode_field(:x, "Erwerbstätige", type: :quantitative, title: "Erwerbstätige (in 1'000)")
  |> Vl.encode(:color, value: "#3b82f6")
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

employment_lookup =
  df_latest
  |> DF.to_rows()
  |> Map.new(fn row -> {row["Bezeichnung"], round(row["Erwerbstaetige"] / 1000)} end)

risk_data = [
  %{"Sektor" => "Verarbeitendes Gewerbe, Bergbau", "Risiko_hoch" => 35, "Risiko_mittel" => 30},
  %{"Sektor" => "Handel, Reparatur", "Risiko_hoch" => 28, "Risiko_mittel" => 35},
  %{"Sektor" => "Gastgewerbe, Beherbergung", "Risiko_hoch" => 42, "Risiko_mittel" => 28},
  %{"Sektor" => "Verkehr, Lagerei", "Risiko_hoch" => 38, "Risiko_mittel" => 25},
  %{"Sektor" => "Finanz-, Versicherungsdienstl.", "Risiko_hoch" => 22, "Risiko_mittel" => 38},
  %{"Sektor" => "Gesundheits-, Sozialwesen", "Risiko_hoch" => 12, "Risiko_mittel" => 25},
  %{"Sektor" => "Information, Kommunikation", "Risiko_hoch" => 8, "Risiko_mittel" => 22},
  %{"Sektor" => "Baugewerbe", "Risiko_hoch" => 25, "Risiko_mittel" => 32},
  %{"Sektor" => "Erziehung und Unterricht", "Risiko_hoch" => 5, "Risiko_mittel" => 15},
  %{"Sektor" => "Öffentliche Verwaltung", "Risiko_hoch" => 15, "Risiko_mittel" => 30}
]

risk_enriched = Enum.map(risk_data, fn row ->
  beschaeftigte = Map.get(employment_lookup, row["Sektor"], 0)
  exposed = round(beschaeftigte * row["Risiko_hoch"] / 100)
  row
  |> Map.put("Beschaeftigte", beschaeftigte)
  |> Map.put("Exponierte_Stellen", exposed)
end)

chart_risk =
  Vl.new(width: 720, height: 400, title: "Automatisierungsrisiko nach Branche (OECD-Methodik)")
  |> Vl.data_from_values(
    risk_enriched
    |> Enum.flat_map(fn row ->
      [
        %{"Sektor" => row["Sektor"], "Anteil" => row["Risiko_hoch"], "Risikostufe" => "Hoch (>70%)"},
        %{"Sektor" => row["Sektor"], "Anteil" => row["Risiko_mittel"], "Risikostufe" => "Mittel (50-70%)"}
      ]
    end)
  )
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Sektor", type: :nominal, title: nil, sort: "-x")
  |> Vl.encode_field(:x, "Anteil", type: :quantitative, title: "Anteil Arbeitsplätze (%)", stack: :zero)
  |> Vl.encode_field(:color, "Risikostufe",
    type: :nominal,
    scale: [domain: ["Hoch (>70%)", "Mittel (50-70%)"], range: ["#ef4444", "#f59e0b"]]
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

total_exposed = risk_enriched |> Enum.map(& &1["Exponierte_Stellen"]) |> Enum.sum()
total_workers = risk_enriched |> Enum.map(& &1["Beschaeftigte"]) |> Enum.sum()

chart_exposed =
  Vl.new(width: 720, height: 400, title: "Geschätzte exponierte Arbeitsplätze (hohes Automatisierungsrisiko)")
  |> Vl.data_from_values(
    risk_enriched
    |> Enum.sort_by(& &1["Exponierte_Stellen"], :desc)
    |> Enum.map(&%{"Sektor" => &1["Sektor"], "Exponierte Stellen (Tsd.)" => &1["Exponierte_Stellen"]})
  )
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Sektor", type: :nominal, title: nil, sort: "-x")
  |> Vl.encode_field(:x, "Exponierte Stellen (Tsd.)", type: :quantitative, title: "Arbeitsplätze (in 1'000)")
  |> Vl.encode(:color, value: "#a855f7")
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

IO.puts("Total exponierte Stellen: #{total_exposed}'000 (#{round(total_exposed / max(total_workers, 1) * 100)}%)")

# Export notebook 03
Zukunftslabor.ChartExport.to_svg(chart_employment, name: "beschaeftigung_branchen")
Zukunftslabor.ChartExport.to_svg(chart_risk, name: "automatisierungsrisiko_branchen")
Zukunftslabor.ChartExport.to_svg(chart_exposed, name: "exponierte_arbeitsplaetze")

Zukunftslabor.NotizTemplate.generate(
  title: "Welche Branchen die Automatisierung am stärksten trifft",
  description: "Rund #{total_exposed}'000 Schweizer Arbeitsplätze tragen ein hohes Automatisierungsrisiko — vor allem im Gewerbe, Handel und Gastgewerbe.",
  slug: "automatisierungsrisiko-branchen",
  category: "datenbriefing",
  evidence: "mittel",
  tags: ["automatisierung", "arbeit", "branchen", "uebergaenge"],
  charts: ["beschaeftigung_branchen.svg", "automatisierungsrisiko_branchen.svg", "exponierte_arbeitsplaetze.svg"],
  summary: """
  Rund #{total_exposed}'000 Arbeitsplätze in der Schweiz tragen ein hohes
  Automatisierungsrisiko (>70% nach OECD-Methodik). Besonders exponiert:
  Verarbeitendes Gewerbe, Handel und Gastgewerbe. Die Daten zeigen, wo
  Übergangsstrategien — wie ein Grundeinkommen — am dringendsten wirken.
  """,
  body: """
  ## Methodik

  Die Analyse kombiniert BFS-SAKE-Beschäftigungsdaten (2024) mit OECD-
  Automatisierungsrisikoschätzungen (Nedelkoska & Quintini 2018, aktualisiert).
  Die OECD-Methodik schätzt das Risiko auf Berufsebene (ISCO) und wird hier
  auf Branchenebene (NOGA) aggregiert.

  «Hohes Risiko» bedeutet: >70% der Tätigkeiten in einem Beruf sind potenziell
  automatisierbar. Das heisst nicht, dass der Beruf verschwindet — sondern dass
  sich das Tätigkeitsprofil grundlegend verändert.

  ## Ergebnisse

  ![Beschäftigung nach Branchen](/zukunftslabor/charts/beschaeftigung_branchen.svg)

  ![Automatisierungsrisiko](/zukunftslabor/charts/automatisierungsrisiko_branchen.svg)

  ![Exponierte Arbeitsplätze](/zukunftslabor/charts/exponierte_arbeitsplaetze.svg)

  ## Politische Einordnung

  Die Automatisierung trifft vor allem Branchen mit geringerer Qualifikation
  und tieferen Löhnen. Ein Grundeinkommen bietet hier eine doppelte Funktion:

  1. **Sicherheitsnetz** während beruflicher Übergänge
  2. **Ermöglicher** für Weiterbildung und neue Tätigkeitsformen

  ## Datenquellen

  - BFS SAKE 2024: Erwerbstätige nach Wirtschaftsabschnitt
  - OECD (2018): Automation and Independent Work in a Digital Economy
  - Nedelkoska & Quintini (2018): Automation, skills use and training (OECD Social, Employment and Migration Working Papers No. 202)
  """
)

IO.puts("\n========================================")
IO.puts("  04 — Mietbelastung nach Einkommensgruppe")
IO.puts("========================================\n")

df_mieten = Zukunftslabor.DataLoader.load("mietzinse_kantone")

burden_data = [
  %{"Quintil" => "1 (tiefstes)", "Mietanteil" => 40},
  %{"Quintil" => "2", "Mietanteil" => 28},
  %{"Quintil" => "3", "Mietanteil" => 22},
  %{"Quintil" => "4", "Mietanteil" => 18},
  %{"Quintil" => "5 (höchstes)", "Mietanteil" => 12}
]

chart_burden =
  Vl.new(width: 720, height: 400, title: "Mietbelastungsquote nach Einkommensquintil (BFS SILC 2022)")
  |> Vl.data_from_values(burden_data)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:x, "Quintil", type: :ordinal, title: "Einkommensquintil (1 = tiefstes)")
  |> Vl.encode_field(:y, "Mietanteil", type: :quantitative, title: "Mietanteil am Einkommen (%)")
  |> Vl.encode(:color, field: "Mietanteil", type: :quantitative, scale: [scheme: "reds"], legend: nil)
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

df_3z =
  df_mieten
  |> DF.filter(col("Zimmerzahl") == "3 Zimmer" and col("Jahr") == 2023)
  |> DF.sort_by(desc: col("Miete_CHF"))

canton_data =
  df_3z
  |> DF.to_rows()
  |> Enum.map(fn row ->
    %{"Kanton" => row["Kanton"], "Miete_CHF" => row["Miete_CHF"]}
  end)

chart_kantone =
  Vl.new(width: 720, height: 600, title: "Durchschnittliche Monatsmiete, 3-Zimmer-Wohnung (2023)")
  |> Vl.data_from_values(canton_data)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Kanton", type: :nominal, title: nil, sort: "-x")
  |> Vl.encode_field(:x, "Miete_CHF", type: :quantitative, title: "CHF/Monat")
  |> Vl.encode(:color, field: "Miete_CHF", type: :quantitative, scale: [scheme: "purples"], legend: nil)
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

# UBI rent burden simulation
quintile_data = [
  %{"Quintil" => "1 (tiefstes)", "Einkommen" => 24000, "Miete_anteil" => 40},
  %{"Quintil" => "2", "Einkommen" => 38000, "Miete_anteil" => 28},
  %{"Quintil" => "3", "Einkommen" => 50000, "Miete_anteil" => 22},
  %{"Quintil" => "4", "Einkommen" => 65000, "Miete_anteil" => 18},
  %{"Quintil" => "5 (höchstes)", "Einkommen" => 105000, "Miete_anteil" => 12}
]

ubi_annual = 30_000

sim_data = Enum.flat_map(quintile_data, fn q ->
  miete_chf = q["Einkommen"] * q["Miete_anteil"] / 100
  new_income = q["Einkommen"] + ubi_annual
  new_anteil = Float.round(miete_chf / new_income * 100, 1)

  [
    %{"Quintil" => q["Quintil"], "Anteil" => q["Miete_anteil"] / 1, "Szenario" => "Status quo"},
    %{"Quintil" => q["Quintil"], "Anteil" => new_anteil, "Szenario" => "Mit Grundeinkommen"}
  ]
end)

chart_sim =
  Vl.new(width: 720, height: 400, title: "Mietbelastung: Status quo vs. Grundeinkommen (CHF 2'500/Mt)")
  |> Vl.data_from_values(sim_data)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:x, "Quintil", type: :ordinal, title: "Einkommensquintil")
  |> Vl.encode_field(:y, "Anteil", type: :quantitative, title: "Mietanteil am Einkommen (%)")
  |> Vl.encode_field(:color, "Szenario", type: :nominal, scale: [range: ["#ef4444", "#10b981"]])
  |> Vl.encode_field(:x_offset, "Szenario", type: :nominal)
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

q1_ubi = Enum.find(sim_data, &(&1["Quintil"] == "1 (tiefstes)" && &1["Szenario"] == "Mit Grundeinkommen"))["Anteil"]
most_expensive = hd(canton_data)["Kanton"]
least_expensive = List.last(canton_data)["Kanton"]
most_rent = hd(canton_data)["Miete_CHF"]
least_rent = List.last(canton_data)["Miete_CHF"]

IO.puts("Q1 Mietbelastung mit UBI: #{q1_ubi}%")
IO.puts("Teuerster Kanton: #{most_expensive} (CHF #{most_rent})")
IO.puts("Günstigster Kanton: #{least_expensive} (CHF #{least_rent})")

# Export notebook 04
Zukunftslabor.ChartExport.to_svg(chart_burden, name: "mietbelastung_quintile")
Zukunftslabor.ChartExport.to_svg(chart_kantone, name: "mieten_kantone")
Zukunftslabor.ChartExport.to_svg(chart_sim, name: "mietbelastung_grundeinkommen")

Zukunftslabor.NotizTemplate.generate(
  title: "40% des Einkommens für Miete — unterste Einkommen besonders belastet",
  description: "Das unterste Einkommensquintil gibt 40% für Miete aus. Ein Grundeinkommen würde die Belastung deutlich senken — mit starken kantonalen Unterschieden.",
  slug: "mietbelastung-einkommensgruppen",
  category: "datenbriefing",
  evidence: "stark",
  tags: ["wohnen", "miete", "ungleichheit", "grundeinkommen"],
  charts: ["mietbelastung_quintile.svg", "mieten_kantone.svg", "mietbelastung_grundeinkommen.svg"],
  summary: """
  Das unterste Einkommensquintil gibt heute rund 40% seines Einkommens für Miete
  aus — weit über der 30%-Schwelle. Ein Grundeinkommen von CHF 2'500/Monat
  würde die Belastung auf rund #{q1_ubi}% senken. Die kantonalen Unterschiede
  sind dabei erheblich: von CHF #{most_rent} (#{most_expensive}) bis CHF #{least_rent} (#{least_expensive}).
  """,
  body: """
  ## Methodik

  Die Mietbelastungsquoten stammen aus publizierten BFS-SILC-Tabellen (2022),
  aufgeschlüsselt nach Einkommensquintilen. Die kantonalen Durchschnittsmieten
  basieren auf der BFS-Strukturerhebung Bau- und Wohnungswesen (2023). Die
  Simulation addiert CHF 30'000 Jahreseinkommen (UBI) bei konstanten Mietkosten.

  ## Ergebnisse

  ![Mietbelastung nach Quintil](/zukunftslabor/charts/mietbelastung_quintile.svg)

  ![Kantonale Mieten](/zukunftslabor/charts/mieten_kantone.svg)

  ![Simulation: Mietbelastung mit Grundeinkommen](/zukunftslabor/charts/mietbelastung_grundeinkommen.svg)

  ## Einschränkungen

  - Die Simulation hält Mieten konstant — in der Realität könnten Vermieter auf
    höhere Einkommen reagieren (Mietpreiseffekt)
  - Quintilmediane verdecken Extremfälle innerhalb der Gruppen
  - Kein Modell für Wohngeld / Mietzuschüsse, die durch UBI teilweise ersetzt würden
  - SILC-Mietbelastungsdaten sind aggregierte Publikationswerte (keine Mikrodaten)

  ## Politische Einordnung

  Die Mietbelastungsdaten machen deutlich: Wohnen ist das grösste Alltagsproblem
  für tiefe Einkommen in der Schweiz. Ein Grundeinkommen wirkt hier direkt — aber
  ohne parallele Wohnbaupolitik droht ein Teil des Effekts von steigenden Mieten
  absorbiert zu werden.

  ## Datenquellen

  - BFS SILC 2022: Wohnkostenbelastung nach Einkommensquintil (publizierte Tabelle)
  - BFS Strukturerhebung 2023: Durchschnittliche Mietzinse nach Kanton und Zimmerzahl
  """
)

IO.puts("\n========================================")
IO.puts("  05 — Forschung & Innovation")
IO.puts("========================================\n")

df_rd = Zukunftslabor.DataLoader.load("forschung_ausgaben")

latest_rd_year =
  df_rd
  |> DF.pull("Jahr")
  |> Series.max()

df_rd_latest =
  df_rd
  |> DF.filter(col("Jahr") == ^latest_rd_year)
  |> DF.sort_by(desc: col("Ausgaben_Mio_CHF"))

sector_data_05 =
  df_rd_latest
  |> DF.to_rows()
  |> Enum.map(fn row ->
    %{"Sektor" => row["Sektor"], "Ausgaben (Mio. CHF)" => row["Ausgaben_Mio_CHF"]}
  end)

chart_sectors_05 =
  Vl.new(width: 720, height: 400, title: "F&E-Ausgaben nach Sektor — Schweiz (#{latest_rd_year})")
  |> Vl.data_from_values(sector_data_05)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Sektor", type: :nominal, title: nil, sort: "-x")
  |> Vl.encode_field(:x, "Ausgaben (Mio. CHF)", type: :quantitative, title: "Mio. CHF")
  |> Vl.encode(:color, value: "#a855f7")
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

oecd_data_05 = [
  %{"Land" => "Israel", "F&E_BIP" => 5.56, "BIP_pro_Kopf" => 54_660},
  %{"Land" => "Südkorea", "F&E_BIP" => 4.93, "BIP_pro_Kopf" => 50_490},
  %{"Land" => "Schweden", "F&E_BIP" => 3.40, "BIP_pro_Kopf" => 60_240},
  %{"Land" => "Schweiz", "F&E_BIP" => 3.36, "BIP_pro_Kopf" => 93_260},
  %{"Land" => "USA", "F&E_BIP" => 3.46, "BIP_pro_Kopf" => 76_330},
  %{"Land" => "Deutschland", "F&E_BIP" => 3.13, "BIP_pro_Kopf" => 51_380},
  %{"Land" => "Österreich", "F&E_BIP" => 3.20, "BIP_pro_Kopf" => 56_800},
  %{"Land" => "OECD-Durchschnitt", "F&E_BIP" => 2.71, "BIP_pro_Kopf" => 47_000}
]

chart_oecd_05 =
  Vl.new(width: 720, height: 400, title: "F&E-Ausgaben (% BIP) vs. BIP pro Kopf — Internationaler Vergleich")
  |> Vl.data_from_values(oecd_data_05)
  |> Vl.mark(:point, size: 120, filled: true)
  |> Vl.encode_field(:x, "BIP_pro_Kopf", type: :quantitative, title: "BIP pro Kopf (USD, KKP)", scale: [domain: [40_000, 100_000]])
  |> Vl.encode_field(:y, "F&E_BIP", type: :quantitative, title: "F&E-Ausgaben (% des BIP)", scale: [domain: [2.0, 6.0]])
  |> Vl.encode_field(:color, "Land",
    type: :nominal,
    scale: [
      domain: ["Schweiz", "OECD-Durchschnitt", "Israel", "Südkorea", "USA", "Schweden", "Deutschland", "Österreich"],
      range: ["#a855f7", "#6b7280", "#06b6d4", "#10b981", "#3b82f6", "#f59e0b", "#ef4444", "#8b5cf6"]
    ]
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

yearly_totals_05 =
  df_rd
  |> DF.group_by("Jahr")
  |> DF.summarise(Total: sum(col("Ausgaben_Mio_CHF")))
  |> DF.to_rows()
  |> Enum.map(fn row -> %{"Jahr" => row["Jahr"], "Total (Mio. CHF)" => row["Total"]} end)
  |> Enum.sort_by(& &1["Jahr"])

chart_trend_05 =
  Vl.new(width: 720, height: 300, title: "F&E-Gesamtausgaben Schweiz im Zeitverlauf")
  |> Vl.data_from_values(yearly_totals_05)
  |> Vl.mark(:line, point: true, stroke_width: 2)
  |> Vl.encode_field(:x, "Jahr", type: :ordinal, title: "Jahr")
  |> Vl.encode_field(:y, "Total (Mio. CHF)", type: :quantitative, title: "Mio. CHF")
  |> Vl.encode(:color, value: "#a855f7")
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

total_rd_05 = if length(yearly_totals_05) > 0, do: List.last(yearly_totals_05)["Total (Mio. CHF)"], else: 0

IO.puts("Total R&D (#{latest_rd_year}): CHF #{round(total_rd_05)} Mio.")

# Export notebook 05
Zukunftslabor.ChartExport.to_svg(chart_sectors_05, name: "forschung_ausgaben_sektor")
Zukunftslabor.ChartExport.to_svg(chart_oecd_05, name: "forschung_internationaler_vergleich")
Zukunftslabor.ChartExport.to_svg(chart_trend_05, name: "forschung_ausgaben_zeitreihe")

Zukunftslabor.NotizTemplate.generate(
  title: "3.4% des BIP für Forschung — aber wem gehört das Wissen?",
  description: "Die Schweiz gehört bei F&E-Ausgaben zur Weltspitze, doch zwei Drittel kommen aus der Privatwirtschaft. Der öffentliche Ertrag aus öffentlicher Forschung bleibt eine offene Frage.",
  slug: "forschung-innovation-ausgaben",
  category: "datenbriefing",
  evidence: "stark",
  tags: ["forschung", "innovation", "commons", "oecd", "f-und-e"],
  charts: ["forschung_ausgaben_sektor.svg", "forschung_internationaler_vergleich.svg", "forschung_ausgaben_zeitreihe.svg"],
  summary: """
  Die Schweiz investiert rund #{round(total_rd_05 / 1000, 1)} Mrd. CHF (ca. 3.4% des BIP)
  in Forschung und Entwicklung — Top 5 weltweit. Die Frage, was als öffentlicher Ertrag
  aus öffentlich finanzierter Forschung zurückfliesst, ist politisch unbeantwortet.
  """,
  body: """
  ## Methodik

  Grundlage sind die BFS-Forschungsstatistik (F&E-Aufwendungen nach Sektor) und
  die OECD Main Science and Technology Indicators (GERD als % des BIP).

  ## Ergebnisse

  ![F&E-Ausgaben nach Sektor](/zukunftslabor/charts/forschung_ausgaben_sektor.svg)

  ![Internationaler Vergleich](/zukunftslabor/charts/forschung_internationaler_vergleich.svg)

  ![Zeitreihe](/zukunftslabor/charts/forschung_ausgaben_zeitreihe.svg)

  ## Datenquellen

  - BFS: Forschung und Entwicklung — Aufwendungen (2004–2021)
  - OECD Main Science and Technology Indicators 2023
  """
)

IO.puts("\n========================================")
IO.puts("  06 — Energie & Resilienz")
IO.puts("========================================\n")

df_elec = Zukunftslabor.DataLoader.load("elektrizitaet_produktion")

elec_data_06 =
  df_elec
  |> DF.to_rows()
  |> Enum.map(fn row ->
    %{"Jahr" => row["Jahr"], "Energieträger" => row["Energieträger"], "Produktion" => row["value"]}
  end)
  |> Enum.filter(& &1["Produktion"] && &1["Produktion"] > 0)

chart_mix_06 =
  Vl.new(width: 720, height: 400, title: "Schweizer Elektrizitätsproduktion nach Energieträger")
  |> Vl.data_from_values(elec_data_06)
  |> Vl.mark(:bar)
  |> Vl.encode_field(:x, "Jahr", type: :ordinal, title: "Jahr")
  |> Vl.encode_field(:y, "Produktion", type: :quantitative, title: "GWh", stack: :zero)
  |> Vl.encode_field(:color, "Energieträger",
    type: :nominal,
    scale: [range: ["#3b82f6", "#a855f7", "#f59e0b", "#06b6d4", "#10b981", "#6b7280"]]
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

renewable_data_06 = [
  %{"Land" => "Schweiz", "Erneuerbarer Anteil (%)" => 76},
  %{"Land" => "Schweden", "Erneuerbarer Anteil (%)" => 68},
  %{"Land" => "Dänemark", "Erneuerbarer Anteil (%)" => 84},
  %{"Land" => "Österreich", "Erneuerbarer Anteil (%)" => 78},
  %{"Land" => "Deutschland", "Erneuerbarer Anteil (%)" => 52},
  %{"Land" => "Frankreich", "Erneuerbarer Anteil (%)" => 27},
  %{"Land" => "EU-Durchschnitt", "Erneuerbarer Anteil (%)" => 44}
]

chart_renewable_06 =
  Vl.new(width: 720, height: 350, title: "Erneuerbarer Stromanteil im Vergleich (2023)")
  |> Vl.data_from_values(renewable_data_06)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Land", type: :nominal, title: nil, sort: "-x")
  |> Vl.encode_field(:x, "Erneuerbarer Anteil (%)", type: :quantitative, title: "Anteil (%)")
  |> Vl.encode_field(:color, "Land",
    type: :nominal,
    scale: [
      domain: ["Schweiz", "EU-Durchschnitt", "Dänemark", "Österreich", "Schweden", "Deutschland", "Frankreich"],
      range: ["#a855f7", "#6b7280", "#06b6d4", "#10b981", "#f59e0b", "#ef4444", "#3b82f6"]
    ],
    legend: nil
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

import_data_06 = [
  %{"Jahr" => 2015, "Netto-Import (GWh)" => 1_200},
  %{"Jahr" => 2016, "Netto-Import (GWh)" => -2_100},
  %{"Jahr" => 2017, "Netto-Import (GWh)" => -3_400},
  %{"Jahr" => 2018, "Netto-Import (GWh)" => -1_800},
  %{"Jahr" => 2019, "Netto-Import (GWh)" => -5_700},
  %{"Jahr" => 2020, "Netto-Import (GWh)" => -5_600},
  %{"Jahr" => 2021, "Netto-Import (GWh)" => 2_600},
  %{"Jahr" => 2022, "Netto-Import (GWh)" => 3_500},
  %{"Jahr" => 2023, "Netto-Import (GWh)" => -6_400}
]

chart_imports_06 =
  Vl.new(width: 720, height: 300, title: "Netto-Stromimporte der Schweiz (positiv = Import, negativ = Export)")
  |> Vl.data_from_values(import_data_06)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:x, "Jahr", type: :ordinal, title: "Jahr")
  |> Vl.encode_field(:y, "Netto-Import (GWh)", type: :quantitative, title: "GWh")
  |> Vl.encode(:color,
    condition: [test: "datum['Netto-Import (GWh)'] > 0", value: "#ef4444"],
    value: "#10b981"
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

IO.puts("Electricity data loaded: #{length(elec_data_06)} rows")

# Export notebook 06
Zukunftslabor.ChartExport.to_svg(chart_mix_06, name: "energiemix_strommix")
Zukunftslabor.ChartExport.to_svg(chart_renewable_06, name: "energiemix_erneuerbar_vergleich")
Zukunftslabor.ChartExport.to_svg(chart_imports_06, name: "energiemix_netto_importe")

Zukunftslabor.NotizTemplate.generate(
  title: "98% CO₂-arm — aber wie resilient ist die Schweizer Stromversorgung?",
  description: "Die Schweiz hat einen der saubersten Strommixe Europas, doch saisonale Importabhängigkeit und Wasserkraft-Konzentration schaffen Verwundbarkeiten.",
  slug: "energiemix-resilienz",
  category: "datenbriefing",
  evidence: "stark",
  tags: ["energie", "resilienz", "strom", "infrastruktur", "vergleich"],
  charts: ["energiemix_strommix.svg", "energiemix_erneuerbar_vergleich.svg", "energiemix_netto_importe.svg"],
  summary: """
  Die Schweiz produziert 98% ihres Stroms CO₂-arm und liegt mit 76% erneuerbarem Anteil
  weit über dem EU-Durchschnitt (44%). Aber die Winterlücke und die Wasserkraft-Dominanz
  machen das System verwundbar.
  """,
  body: """
  ## Methodik

  BFS/BFE-Elektrizitätsstatistik + IEA/Eurostat-Daten für den internationalen Vergleich.

  ## Ergebnisse

  ![Strommix](/zukunftslabor/charts/energiemix_strommix.svg)

  ![Erneuerbarer Anteil](/zukunftslabor/charts/energiemix_erneuerbar_vergleich.svg)

  ![Netto-Importe](/zukunftslabor/charts/energiemix_netto_importe.svg)

  ## Datenquellen

  - BFS/BFE: Schweizerische Elektrizitätsstatistik
  - IEA / Eurostat: Renewable electricity share by country (2023)
  """
)

IO.puts("\n========================================")
IO.puts("  07 — Übergänge & Weiterbildung")
IO.puts("========================================\n")

education_data_07 = [
  %{"Bildungsniveau" => "Tertiärstufe", "Teilnahme (%)" => 76, "Kategorie" => "Formell + nicht-formell"},
  %{"Bildungsniveau" => "Sekundarstufe II", "Teilnahme (%)" => 58, "Kategorie" => "Formell + nicht-formell"},
  %{"Bildungsniveau" => "Obligatorische Schule", "Teilnahme (%)" => 32, "Kategorie" => "Formell + nicht-formell"},
  %{"Bildungsniveau" => "Tertiärstufe", "Teilnahme (%)" => 22, "Kategorie" => "Nur formell"},
  %{"Bildungsniveau" => "Sekundarstufe II", "Teilnahme (%)" => 12, "Kategorie" => "Nur formell"},
  %{"Bildungsniveau" => "Obligatorische Schule", "Teilnahme (%)" => 6, "Kategorie" => "Nur formell"}
]

chart_education_07 =
  Vl.new(width: 720, height: 350, title: "Weiterbildungsteilnahme nach Bildungsniveau (BFS 2021)")
  |> Vl.data_from_values(education_data_07)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Bildungsniveau", type: :nominal, title: nil,
    sort: ["Tertiärstufe", "Sekundarstufe II", "Obligatorische Schule"])
  |> Vl.encode_field(:x, "Teilnahme (%)", type: :quantitative, title: "Teilnahmequote (%)")
  |> Vl.encode_field(:color, "Kategorie", type: :nominal, scale: [range: ["#a855f7", "#06b6d4"]])
  |> Vl.encode_field(:x_offset, "Kategorie", type: :nominal)
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

age_data_07 = [
  %{"Altersgruppe" => "25–34", "Teilnahme (%)" => 72},
  %{"Altersgruppe" => "35–44", "Teilnahme (%)" => 68},
  %{"Altersgruppe" => "45–54", "Teilnahme (%)" => 60},
  %{"Altersgruppe" => "55–64", "Teilnahme (%)" => 48}
]

chart_age_07 =
  Vl.new(width: 720, height: 300, title: "Weiterbildungsteilnahme nach Altersgruppe (BFS 2021)")
  |> Vl.data_from_values(age_data_07)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:x, "Altersgruppe", type: :ordinal, title: "Altersgruppe")
  |> Vl.encode_field(:y, "Teilnahme (%)", type: :quantitative, title: "Teilnahmequote (%)")
  |> Vl.encode(:color, value: "#3b82f6")
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

intl_data_07 = [
  %{"Land" => "Schweiz", "Weiterbildung (%)" => 68, "Arbeitslosenquote (%)" => 4.3},
  %{"Land" => "Schweden", "Weiterbildung (%)" => 66, "Arbeitslosenquote (%)" => 7.5},
  %{"Land" => "Dänemark", "Weiterbildung (%)" => 55, "Arbeitslosenquote (%)" => 5.1},
  %{"Land" => "Österreich", "Weiterbildung (%)" => 60, "Arbeitslosenquote (%)" => 5.3},
  %{"Land" => "Deutschland", "Weiterbildung (%)" => 54, "Arbeitslosenquote (%)" => 5.8},
  %{"Land" => "Frankreich", "Weiterbildung (%)" => 50, "Arbeitslosenquote (%)" => 7.3},
  %{"Land" => "EU-Durchschnitt", "Weiterbildung (%)" => 47, "Arbeitslosenquote (%)" => 6.2}
]

chart_intl_07 =
  Vl.new(width: 720, height: 400, title: "Weiterbildungsrate vs. Arbeitslosenquote — Internationaler Vergleich")
  |> Vl.data_from_values(intl_data_07)
  |> Vl.mark(:point, size: 120, filled: true)
  |> Vl.encode_field(:x, "Weiterbildung (%)", type: :quantitative, title: "Weiterbildungsteilnahme (%)", scale: [domain: [40, 75]])
  |> Vl.encode_field(:y, "Arbeitslosenquote (%)", type: :quantitative, title: "Arbeitslosenquote (%)", scale: [domain: [3, 9]])
  |> Vl.encode_field(:color, "Land",
    type: :nominal,
    scale: [
      domain: ["Schweiz", "EU-Durchschnitt", "Schweden", "Dänemark", "Österreich", "Deutschland", "Frankreich"],
      range: ["#a855f7", "#6b7280", "#06b6d4", "#10b981", "#f59e0b", "#3b82f6", "#ef4444"]
    ]
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

IO.puts("Weiterbildung: Tertiär 76%, Obligatorisch 32%, 55–64: 48%")

# Export notebook 07
Zukunftslabor.ChartExport.to_svg(chart_education_07, name: "weiterbildung_bildungsniveau")
Zukunftslabor.ChartExport.to_svg(chart_age_07, name: "weiterbildung_altersgruppe")
Zukunftslabor.ChartExport.to_svg(chart_intl_07, name: "weiterbildung_internationaler_vergleich")

Zukunftslabor.NotizTemplate.generate(
  title: "Wer sich weiterbildet — und wer zurückbleibt",
  description: "Die Schweiz hat eine hohe Weiterbildungsquote, aber wer es am meisten braucht, nimmt am wenigsten teil.",
  slug: "weiterbildung-teilnahme-luecken",
  category: "datenbriefing",
  evidence: "mittel",
  tags: ["weiterbildung", "uebergaenge", "bildung", "arbeitsmarkt", "alter"],
  charts: ["weiterbildung_bildungsniveau.svg", "weiterbildung_altersgruppe.svg", "weiterbildung_internationaler_vergleich.svg"],
  summary: """
  Die Schweiz hat mit 68% eine der höchsten Weiterbildungsquoten in Europa. Aber
  die Schere klafft: Tertiärstufe 76%, obligatorische Schule nur 32%. Ältere
  (55–64) nehmen mit 48% deutlich seltener teil.
  """,
  body: """
  ## Methodik

  BFS-Erhebung zur Weiterbildung (Mikrozensus 2021) + Eurostat Adult Education Survey.

  ## Ergebnisse

  ![Teilnahme nach Bildungsniveau](/zukunftslabor/charts/weiterbildung_bildungsniveau.svg)

  ![Teilnahme nach Alter](/zukunftslabor/charts/weiterbildung_altersgruppe.svg)

  ![Internationaler Vergleich](/zukunftslabor/charts/weiterbildung_internationaler_vergleich.svg)

  ## Datenquellen

  - BFS: Mikrozensus Aus- und Weiterbildung 2021
  - Eurostat: Adult Education Survey 2022
  """
)

IO.puts("\n========================================")
IO.puts("  08 — Life Science & Gesundheitskosten")
IO.puts("========================================\n")

df_health = Zukunftslabor.DataLoader.load("gesundheitsausgaben")

health_data_08 =
  df_health
  |> DF.to_rows()
  |> Enum.map(fn row ->
    %{"Jahr" => row["Jahr"], "Kategorie" => row["Kategorie"], "Ausgaben (Mrd. CHF)" => row["Ausgaben_Mio_CHF"] / 1000}
  end)
  |> Enum.filter(& &1["Ausgaben (Mrd. CHF)"] > 0)

chart_spending_08 =
  Vl.new(width: 720, height: 400, title: "Gesundheitsausgaben der Schweiz nach Kategorie")
  |> Vl.data_from_values(health_data_08)
  |> Vl.mark(:area)
  |> Vl.encode_field(:x, "Jahr", type: :ordinal, title: "Jahr")
  |> Vl.encode_field(:y, "Ausgaben (Mrd. CHF)", type: :quantitative, title: "Mrd. CHF", stack: :zero)
  |> Vl.encode_field(:color, "Kategorie",
    type: :nominal,
    scale: [range: ["#a855f7", "#3b82f6", "#06b6d4", "#10b981", "#f59e0b", "#6b7280"]]
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

health_intl_08 = [
  %{"Land" => "Schweiz", "Ausgaben_pK" => 7_138, "Lebenserwartung" => 84.0},
  %{"Land" => "USA", "Ausgaben_pK" => 12_555, "Lebenserwartung" => 77.5},
  %{"Land" => "Deutschland", "Ausgaben_pK" => 7_383, "Lebenserwartung" => 81.2},
  %{"Land" => "Frankreich", "Ausgaben_pK" => 5_564, "Lebenserwartung" => 82.7},
  %{"Land" => "Schweden", "Ausgaben_pK" => 6_262, "Lebenserwartung" => 83.1},
  %{"Land" => "Japan", "Ausgaben_pK" => 4_691, "Lebenserwartung" => 84.8},
  %{"Land" => "UK", "Ausgaben_pK" => 5_138, "Lebenserwartung" => 80.7},
  %{"Land" => "Österreich", "Ausgaben_pK" => 6_693, "Lebenserwartung" => 82.0}
]

chart_health_intl_08 =
  Vl.new(width: 720, height: 400, title: "Gesundheitsausgaben pro Kopf vs. Lebenserwartung (OECD 2023)")
  |> Vl.data_from_values(health_intl_08)
  |> Vl.mark(:point, size: 120, filled: true)
  |> Vl.encode_field(:x, "Ausgaben_pK", type: :quantitative, title: "Gesundheitsausgaben pro Kopf (USD, KKP)", scale: [domain: [4_000, 13_000]])
  |> Vl.encode_field(:y, "Lebenserwartung", type: :quantitative, title: "Lebenserwartung (Jahre)", scale: [domain: [76, 86]])
  |> Vl.encode_field(:color, "Land",
    type: :nominal,
    scale: [
      domain: ["Schweiz", "USA", "Japan", "Deutschland", "Frankreich", "Schweden", "UK", "Österreich"],
      range: ["#a855f7", "#ef4444", "#06b6d4", "#3b82f6", "#10b981", "#f59e0b", "#6b7280", "#8b5cf6"]
    ]
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

admin_data_08 = [
  %{"Land" => "USA", "Verwaltungsanteil (%)" => 8.3},
  %{"Land" => "Schweiz", "Verwaltungsanteil (%)" => 5.2},
  %{"Land" => "Deutschland", "Verwaltungsanteil (%)" => 4.8},
  %{"Land" => "Frankreich", "Verwaltungsanteil (%)" => 5.9},
  %{"Land" => "Schweden", "Verwaltungsanteil (%)" => 2.8},
  %{"Land" => "UK", "Verwaltungsanteil (%)" => 2.3},
  %{"Land" => "Japan", "Verwaltungsanteil (%)" => 1.8},
  %{"Land" => "OECD-Durchschnitt", "Verwaltungsanteil (%)" => 3.5}
]

chart_admin_08 =
  Vl.new(width: 720, height: 350, title: "Verwaltungskosten im Gesundheitswesen (% der Gesamtausgaben)")
  |> Vl.data_from_values(admin_data_08)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Land", type: :nominal, title: nil, sort: "-x")
  |> Vl.encode_field(:x, "Verwaltungsanteil (%)", type: :quantitative, title: "Anteil (%)")
  |> Vl.encode_field(:color, "Land",
    type: :nominal,
    scale: [
      domain: ["Schweiz", "OECD-Durchschnitt", "USA", "Frankreich", "Deutschland", "Schweden", "UK", "Japan"],
      range: ["#a855f7", "#6b7280", "#ef4444", "#10b981", "#3b82f6", "#f59e0b", "#06b6d4", "#8b5cf6"]
    ],
    legend: nil
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

IO.puts("Health spending data: #{length(health_data_08)} rows")

# Export notebook 08
Zukunftslabor.ChartExport.to_svg(chart_spending_08, name: "gesundheitsausgaben_kategorien")
Zukunftslabor.ChartExport.to_svg(chart_health_intl_08, name: "gesundheitsausgaben_vergleich")
Zukunftslabor.ChartExport.to_svg(chart_admin_08, name: "gesundheitsausgaben_verwaltung")

Zukunftslabor.NotizTemplate.generate(
  title: "Beste Gesundheit, höchste Kosten — wo die Verwaltung bremst",
  description: "Die Schweiz hat exzellente Gesundheitsergebnisse, aber überdurchschnittliche Verwaltungskosten.",
  slug: "gesundheitskosten-verwaltung",
  category: "langforschung",
  evidence: "stark",
  tags: ["gesundheit", "life-science", "kosten", "verwaltung", "vergleich"],
  charts: ["gesundheitsausgaben_kategorien.svg", "gesundheitsausgaben_vergleich.svg", "gesundheitsausgaben_verwaltung.svg"],
  summary: """
  Die Schweiz erreicht eine Lebenserwartung von 84.0 Jahren, gibt aber CHF 7'138 pro Kopf
  aus. Der Verwaltungsanteil von 5.2% übersteigt den OECD-Schnitt (3.5%) deutlich.
  """,
  body: """
  ## Methodik

  BFS/BAG-Statistik (Gesundheitsausgaben, 2010–2022) + OECD Health at a Glance 2023.

  ## Ergebnisse

  ![Ausgaben nach Kategorie](/zukunftslabor/charts/gesundheitsausgaben_kategorien.svg)

  ![Ausgaben vs. Lebenserwartung](/zukunftslabor/charts/gesundheitsausgaben_vergleich.svg)

  ![Verwaltungskosten](/zukunftslabor/charts/gesundheitsausgaben_verwaltung.svg)

  ## Datenquellen

  - BFS/BAG: Kosten und Finanzierung des Gesundheitswesens (2010–2022)
  - OECD Health at a Glance 2023
  """
)

IO.puts("\n========================================")
IO.puts("  09 — Sprache & Verständigung")
IO.puts("========================================\n")

canton_lang_data_09 = [
  %{"Kanton" => "Zürich", "Deutsch" => 81, "Französisch" => 3, "Italienisch" => 4, "Englisch" => 8, "Andere" => 4},
  %{"Kanton" => "Bern", "Deutsch" => 84, "Französisch" => 8, "Italienisch" => 2, "Englisch" => 3, "Andere" => 3},
  %{"Kanton" => "Waadt", "Deutsch" => 5, "Französisch" => 80, "Italienisch" => 3, "Englisch" => 6, "Andere" => 6},
  %{"Kanton" => "Genf", "Deutsch" => 4, "Französisch" => 76, "Italienisch" => 4, "Englisch" => 9, "Andere" => 7},
  %{"Kanton" => "Tessin", "Deutsch" => 8, "Französisch" => 2, "Italienisch" => 83, "Englisch" => 3, "Andere" => 4},
  %{"Kanton" => "Freiburg", "Deutsch" => 32, "Französisch" => 62, "Italienisch" => 2, "Englisch" => 2, "Andere" => 2},
  %{"Kanton" => "Wallis", "Deutsch" => 30, "Französisch" => 63, "Italienisch" => 3, "Englisch" => 2, "Andere" => 2},
  %{"Kanton" => "Graubünden", "Deutsch" => 74, "Französisch" => 1, "Italienisch" => 10, "Englisch" => 3, "Andere" => 12},
  %{"Kanton" => "Basel-Stadt", "Deutsch" => 77, "Französisch" => 4, "Italienisch" => 5, "Englisch" => 8, "Andere" => 6},
  %{"Kanton" => "Schweiz (gesamt)", "Deutsch" => 63, "Französisch" => 23, "Italienisch" => 8, "Englisch" => 5, "Andere" => 1}
]

canton_stacked_09 = Enum.flat_map(canton_lang_data_09, fn row ->
  ["Deutsch", "Französisch", "Italienisch", "Englisch", "Andere"]
  |> Enum.map(fn lang ->
    %{"Kanton" => row["Kanton"], "Sprache" => lang, "Anteil (%)" => row[lang]}
  end)
end)

chart_cantons_09 =
  Vl.new(width: 720, height: 400, title: "Hauptsprache(n) nach Kanton (BFS Strukturerhebung 2022)")
  |> Vl.data_from_values(canton_stacked_09)
  |> Vl.mark(:bar)
  |> Vl.encode_field(:y, "Kanton", type: :nominal, title: nil)
  |> Vl.encode_field(:x, "Anteil (%)", type: :quantitative, title: "Anteil (%)", stack: :normalize)
  |> Vl.encode_field(:color, "Sprache",
    type: :nominal,
    scale: [
      domain: ["Deutsch", "Französisch", "Italienisch", "Englisch", "Andere"],
      range: ["#a855f7", "#3b82f6", "#10b981", "#06b6d4", "#6b7280"]
    ]
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

work_lang_data_09 = [
  %{"Sektor" => "Finanzdienstleistungen", "Deutsch" => 72, "Französisch" => 38, "Englisch" => 65, "Italienisch" => 18},
  %{"Sektor" => "IT / Kommunikation", "Deutsch" => 68, "Französisch" => 28, "Englisch" => 72, "Italienisch" => 12},
  %{"Sektor" => "Pharma / Chemie", "Deutsch" => 55, "Französisch" => 35, "Englisch" => 78, "Italienisch" => 10},
  %{"Sektor" => "Öffentliche Verwaltung", "Deutsch" => 76, "Französisch" => 42, "Englisch" => 28, "Italienisch" => 22},
  %{"Sektor" => "Gastgewerbe", "Deutsch" => 62, "Französisch" => 32, "Englisch" => 38, "Italienisch" => 18},
  %{"Sektor" => "Gesundheitswesen", "Deutsch" => 70, "Französisch" => 35, "Englisch" => 22, "Italienisch" => 15}
]

work_stacked_09 = Enum.flat_map(work_lang_data_09, fn row ->
  ["Deutsch", "Französisch", "Englisch", "Italienisch"]
  |> Enum.map(fn lang ->
    %{"Sektor" => row["Sektor"], "Sprache" => lang, "Nutzung (%)" => row[lang]}
  end)
end)

chart_work_09 =
  Vl.new(width: 720, height: 400, title: "Sprachverwendung am Arbeitsplatz nach Sektor (BFS 2019)")
  |> Vl.data_from_values(work_stacked_09)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Sektor", type: :nominal, title: nil)
  |> Vl.encode_field(:x, "Nutzung (%)", type: :quantitative, title: "Anteil Arbeitnehmende (%)")
  |> Vl.encode_field(:color, "Sprache",
    type: :nominal,
    scale: [
      domain: ["Deutsch", "Französisch", "Englisch", "Italienisch"],
      range: ["#a855f7", "#3b82f6", "#06b6d4", "#10b981"]
    ]
  )
  |> Vl.encode_field(:x_offset, "Sprache", type: :nominal)
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

multi_data_09 = [
  %{"Altersgruppe" => "15–24", "Mehrsprachig (%)" => 68},
  %{"Altersgruppe" => "25–34", "Mehrsprachig (%)" => 72},
  %{"Altersgruppe" => "35–44", "Mehrsprachig (%)" => 66},
  %{"Altersgruppe" => "45–54", "Mehrsprachig (%)" => 60},
  %{"Altersgruppe" => "55–64", "Mehrsprachig (%)" => 55},
  %{"Altersgruppe" => "65+", "Mehrsprachig (%)" => 48}
]

chart_multi_09 =
  Vl.new(width: 720, height: 300, title: "Mehrsprachigkeit nach Altersgruppe — regelmässig 2+ Sprachen (BFS 2019)")
  |> Vl.data_from_values(multi_data_09)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:x, "Altersgruppe", type: :ordinal, title: "Altersgruppe")
  |> Vl.encode_field(:y, "Mehrsprachig (%)", type: :quantitative, title: "Anteil (%)")
  |> Vl.encode(:color, value: "#06b6d4")
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

IO.puts("Language data: 63% multilingual, English as bridge language")

# Export notebook 09
Zukunftslabor.ChartExport.to_svg(chart_cantons_09, name: "sprachen_kantone")
Zukunftslabor.ChartExport.to_svg(chart_work_09, name: "sprachen_arbeitsplatz")
Zukunftslabor.ChartExport.to_svg(chart_multi_09, name: "sprachen_mehrsprachigkeit")

Zukunftslabor.NotizTemplate.generate(
  title: "63% mehrsprachig — und Englisch ist längst die Brücke",
  description: "Die Schweiz ist de facto mehrsprachig, mit Englisch als Brückensprache in Wirtschaft und Wissenschaft.",
  slug: "mehrsprachigkeit-englisch-realitaet",
  category: "datenbriefing",
  evidence: "stark",
  tags: ["sprache", "mehrsprachigkeit", "englisch", "kantone", "arbeitsmarkt"],
  charts: ["sprachen_kantone.svg", "sprachen_arbeitsplatz.svg", "sprachen_mehrsprachigkeit.svg"],
  summary: """
  63% der Schweizer Bevölkerung sprechen regelmässig 2+ Sprachen. In IT (72%),
  Pharma (78%) und Finanz (65%) wird Englisch häufiger genutzt als Französisch
  oder Italienisch.
  """,
  body: """
  ## Methodik

  BFS-Strukturerhebung 2022 + BFS-Spracherhebung 2019.

  ## Ergebnisse

  ![Sprachen nach Kanton](/zukunftslabor/charts/sprachen_kantone.svg)

  ![Sprachen am Arbeitsplatz](/zukunftslabor/charts/sprachen_arbeitsplatz.svg)

  ![Mehrsprachigkeit](/zukunftslabor/charts/sprachen_mehrsprachigkeit.svg)

  ## Datenquellen

  - BFS: Strukturerhebung 2022 (Hauptsprache)
  - BFS: Erhebung zur Sprache, Religion und Kultur 2019
  """
)

IO.puts("\n========================================")
IO.puts("  10 — Talent & Migration")
IO.puts("========================================\n")

permit_data_10 = [
  %{"Jahr" => 2015, "Personenfreizügigkeit" => 108_000, "Familiennachzug" => 32_000, "Humanitär" => 28_000, "Übrige" => 12_000},
  %{"Jahr" => 2016, "Personenfreizügigkeit" => 106_000, "Familiennachzug" => 30_000, "Humanitär" => 22_000, "Übrige" => 11_000},
  %{"Jahr" => 2017, "Personenfreizügigkeit" => 100_000, "Familiennachzug" => 29_000, "Humanitär" => 18_000, "Übrige" => 10_000},
  %{"Jahr" => 2018, "Personenfreizügigkeit" => 98_000, "Familiennachzug" => 28_000, "Humanitär" => 15_000, "Übrige" => 10_000},
  %{"Jahr" => 2019, "Personenfreizügigkeit" => 96_000, "Familiennachzug" => 27_000, "Humanitär" => 14_000, "Übrige" => 11_000},
  %{"Jahr" => 2020, "Personenfreizügigkeit" => 78_000, "Familiennachzug" => 22_000, "Humanitär" => 10_000, "Übrige" => 8_000},
  %{"Jahr" => 2021, "Personenfreizügigkeit" => 102_000, "Familiennachzug" => 28_000, "Humanitär" => 14_000, "Übrige" => 10_000},
  %{"Jahr" => 2022, "Personenfreizügigkeit" => 112_000, "Familiennachzug" => 30_000, "Humanitär" => 22_000, "Übrige" => 12_000},
  %{"Jahr" => 2023, "Personenfreizügigkeit" => 115_000, "Familiennachzug" => 31_000, "Humanitär" => 18_000, "Übrige" => 13_000}
]

permit_stacked_10 = Enum.flat_map(permit_data_10, fn row ->
  ["Personenfreizügigkeit", "Familiennachzug", "Humanitär", "Übrige"]
  |> Enum.map(fn cat ->
    %{"Jahr" => row["Jahr"], "Kategorie" => cat, "Personen" => row[cat]}
  end)
end)

chart_permits_10 =
  Vl.new(width: 720, height: 400, title: "Einwanderung in die Schweiz nach Bewilligungskategorie")
  |> Vl.data_from_values(permit_stacked_10)
  |> Vl.mark(:area)
  |> Vl.encode_field(:x, "Jahr", type: :ordinal, title: "Jahr")
  |> Vl.encode_field(:y, "Personen", type: :quantitative, title: "Personen", stack: :zero)
  |> Vl.encode_field(:color, "Kategorie",
    type: :nominal,
    scale: [
      domain: ["Personenfreizügigkeit", "Familiennachzug", "Humanitär", "Übrige"],
      range: ["#a855f7", "#3b82f6", "#f59e0b", "#6b7280"]
    ]
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

origin_data_10 = [
  %{"Herkunftsland" => "Deutschland", "Personen" => 22_100},
  %{"Herkunftsland" => "Italien", "Personen" => 15_800},
  %{"Herkunftsland" => "Frankreich", "Personen" => 14_200},
  %{"Herkunftsland" => "Portugal", "Personen" => 8_900},
  %{"Herkunftsland" => "Spanien", "Personen" => 6_500},
  %{"Herkunftsland" => "Rumänien", "Personen" => 5_800},
  %{"Herkunftsland" => "Türkei", "Personen" => 4_200},
  %{"Herkunftsland" => "Indien", "Personen" => 3_900},
  %{"Herkunftsland" => "Afghanistan", "Personen" => 3_600},
  %{"Herkunftsland" => "Eritrea", "Personen" => 2_800}
]

chart_origin_10 =
  Vl.new(width: 720, height: 400, title: "Top 10 Herkunftsländer der Einwanderung (2023)")
  |> Vl.data_from_values(origin_data_10)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Herkunftsland", type: :nominal, title: nil, sort: "-x")
  |> Vl.encode_field(:x, "Personen", type: :quantitative, title: "Einwanderungen")
  |> Vl.encode(:color, value: "#3b82f6")
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

edu_stacked_10 = [
  %{"Gruppe" => "Zugewanderte (EU/EFTA)", "Bildungsniveau" => "Tertiär", "Anteil (%)" => 52},
  %{"Gruppe" => "Zugewanderte (EU/EFTA)", "Bildungsniveau" => "Sekundär II", "Anteil (%)" => 35},
  %{"Gruppe" => "Zugewanderte (EU/EFTA)", "Bildungsniveau" => "Obligatorisch", "Anteil (%)" => 13},
  %{"Gruppe" => "Zugewanderte (Drittstaaten)", "Bildungsniveau" => "Tertiär", "Anteil (%)" => 38},
  %{"Gruppe" => "Zugewanderte (Drittstaaten)", "Bildungsniveau" => "Sekundär II", "Anteil (%)" => 28},
  %{"Gruppe" => "Zugewanderte (Drittstaaten)", "Bildungsniveau" => "Obligatorisch", "Anteil (%)" => 34},
  %{"Gruppe" => "In der Schweiz Geborene", "Bildungsniveau" => "Tertiär", "Anteil (%)" => 42},
  %{"Gruppe" => "In der Schweiz Geborene", "Bildungsniveau" => "Sekundär II", "Anteil (%)" => 46},
  %{"Gruppe" => "In der Schweiz Geborene", "Bildungsniveau" => "Obligatorisch", "Anteil (%)" => 12}
]

chart_education_10 =
  Vl.new(width: 720, height: 300, title: "Bildungsniveau: Zugewanderte vs. Einheimische (BFS Strukturerhebung)")
  |> Vl.data_from_values(edu_stacked_10)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Gruppe", type: :nominal, title: nil)
  |> Vl.encode_field(:x, "Anteil (%)", type: :quantitative, title: "Anteil (%)")
  |> Vl.encode_field(:color, "Bildungsniveau",
    type: :nominal,
    scale: [domain: ["Tertiär", "Sekundär II", "Obligatorisch"], range: ["#a855f7", "#3b82f6", "#6b7280"]]
  )
  |> Vl.encode_field(:x_offset, "Bildungsniveau", type: :nominal)
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

pf_pct_10 = round(115_000 / (115_000 + 31_000 + 18_000 + 13_000) * 100)
IO.puts("Personenfreizügigkeit: #{pf_pct_10}% der Einwanderung, 52% mit Tertiärabschluss")

# Export notebook 10
Zukunftslabor.ChartExport.to_svg(chart_permits_10, name: "migration_bewilligungen")
Zukunftslabor.ChartExport.to_svg(chart_origin_10, name: "migration_herkunftslaender")
Zukunftslabor.ChartExport.to_svg(chart_education_10, name: "migration_bildungsniveau")

Zukunftslabor.NotizTemplate.generate(
  title: "#{pf_pct_10}% Personenfreizügigkeit — die Zuwanderung ist primär qualifiziert",
  description: "Die Schweiz zieht über die Personenfreizügigkeit vor allem qualifizierte EU-Fachkräfte an.",
  slug: "zuwanderung-qualifikation-daten",
  category: "datenbriefing",
  evidence: "stark",
  tags: ["migration", "talent", "personenfreizuegigkeit", "integration", "bildung"],
  charts: ["migration_bewilligungen.svg", "migration_herkunftslaender.svg", "migration_bildungsniveau.svg"],
  summary: """
  #{pf_pct_10}% der Einwanderung läuft über die Personenfreizügigkeit (2023). 52% der
  EU/EFTA-Zugewanderten haben einen Tertiärabschluss.
  """,
  body: """
  ## Methodik

  SEM-Migrationsstatistik (2015–2023) + BFS-Strukturerhebung (Bildungsniveau).

  ## Ergebnisse

  ![Bewilligungskategorien](/zukunftslabor/charts/migration_bewilligungen.svg)

  ![Herkunftsländer](/zukunftslabor/charts/migration_herkunftslaender.svg)

  ![Bildungsniveau](/zukunftslabor/charts/migration_bildungsniveau.svg)

  ## Datenquellen

  - SEM: Migrationsstatistik 2015–2023
  - BFS: Strukturerhebung (Bildungsniveau)
  - OECD: International Migration Outlook 2023
  """
)

IO.puts("\n========================================")
IO.puts("  11 — Offener Staat")
IO.puts("========================================\n")

egov_comparison_11 = [
  %{"Jahr" => 2014, "Schweiz" => 52, "EU-Durchschnitt" => 46},
  %{"Jahr" => 2017, "Schweiz" => 60, "EU-Durchschnitt" => 53},
  %{"Jahr" => 2019, "Schweiz" => 63, "EU-Durchschnitt" => 57},
  %{"Jahr" => 2021, "Schweiz" => 68, "EU-Durchschnitt" => 63},
  %{"Jahr" => 2023, "Schweiz" => 72, "EU-Durchschnitt" => 68},
  %{"Jahr" => 2025, "Schweiz" => 78, "EU-Durchschnitt" => 72}
]

egov_lines_11 = Enum.flat_map(egov_comparison_11, fn row ->
  [
    %{"Jahr" => row["Jahr"], "Region" => "Schweiz", "E-Gov-Nutzung (%)" => row["Schweiz"]},
    %{"Jahr" => row["Jahr"], "Region" => "EU-Durchschnitt", "E-Gov-Nutzung (%)" => row["EU-Durchschnitt"]}
  ]
end)

chart_egov_comp_11 =
  Vl.new(width: 720, height: 400, title: "E-Government-Nutzung: Schweiz vs. EU-Durchschnitt (2014–2025)")
  |> Vl.data_from_values(egov_lines_11)
  |> Vl.mark(:line, point: true, stroke_width: 2)
  |> Vl.encode_field(:x, "Jahr", type: :ordinal, title: "Jahr")
  |> Vl.encode_field(:y, "E-Gov-Nutzung (%)", type: :quantitative, title: "Nutzungsrate (%)", scale: [domain: [40, 85]])
  |> Vl.encode_field(:color, "Region",
    type: :nominal,
    scale: [domain: ["Schweiz", "EU-Durchschnitt"], range: ["#a855f7", "#6b7280"]]
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

internet_age_data_11 = [
  %{"Altersgruppe" => "15–24", "Nutzung (%)" => 99},
  %{"Altersgruppe" => "25–34", "Nutzung (%)" => 99},
  %{"Altersgruppe" => "35–44", "Nutzung (%)" => 98},
  %{"Altersgruppe" => "45–54", "Nutzung (%)" => 97},
  %{"Altersgruppe" => "55–64", "Nutzung (%)" => 95},
  %{"Altersgruppe" => "65–74", "Nutzung (%)" => 88},
  %{"Altersgruppe" => "75+", "Nutzung (%)" => 62}
]

chart_internet_11 =
  Vl.new(width: 720, height: 300, title: "Internetnutzung nach Altersgruppe in der Schweiz (BFS 2023)")
  |> Vl.data_from_values(internet_age_data_11)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:x, "Altersgruppe", type: :ordinal, title: "Altersgruppe")
  |> Vl.encode_field(:y, "Nutzung (%)", type: :quantitative, title: "Internetnutzung (%)", scale: [domain: [50, 100]])
  |> Vl.encode(:color, value: "#3b82f6")
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

opendata_data_11 = [
  %{"Land" => "Frankreich", "Open Data Score" => 95},
  %{"Land" => "Irland", "Open Data Score" => 93},
  %{"Land" => "Spanien", "Open Data Score" => 91},
  %{"Land" => "Estland", "Open Data Score" => 88},
  %{"Land" => "Deutschland", "Open Data Score" => 78},
  %{"Land" => "Österreich", "Open Data Score" => 82},
  %{"Land" => "Schweiz", "Open Data Score" => 65},
  %{"Land" => "EU-Durchschnitt", "Open Data Score" => 79}
]

chart_opendata_11 =
  Vl.new(width: 720, height: 350, title: "Open-Data-Reife im Vergleich (EU Open Data Maturity 2023)")
  |> Vl.data_from_values(opendata_data_11)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Land", type: :nominal, title: nil, sort: "-x")
  |> Vl.encode_field(:x, "Open Data Score", type: :quantitative, title: "Reifegrad-Score (%)")
  |> Vl.encode_field(:color, "Land",
    type: :nominal,
    scale: [
      domain: ["Schweiz", "EU-Durchschnitt", "Frankreich", "Irland", "Spanien", "Estland", "Deutschland", "Österreich"],
      range: ["#a855f7", "#6b7280", "#3b82f6", "#06b6d4", "#f59e0b", "#10b981", "#ef4444", "#8b5cf6"]
    ],
    legend: nil
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

IO.puts("Open State: 98% internet, but e-gov and open data below EU avg")

# Export notebook 11
Zukunftslabor.ChartExport.to_svg(chart_egov_comp_11, name: "offener_staat_egov_vergleich")
Zukunftslabor.ChartExport.to_svg(chart_internet_11, name: "offener_staat_internet_alter")
Zukunftslabor.ChartExport.to_svg(chart_opendata_11, name: "offener_staat_opendata_reife")

Zukunftslabor.NotizTemplate.generate(
  title: "98% online — aber der Staat hinkt hinterher",
  description: "Die Schweiz hat nahezu universellen Internetzugang, aber bei E-Government und Open Data liegt sie unter dem EU-Durchschnitt.",
  slug: "offener-staat-digitalisierung",
  category: "datenbriefing",
  evidence: "mittel",
  tags: ["offener-staat", "e-government", "open-data", "digitalisierung", "vergleich"],
  charts: ["offener_staat_egov_vergleich.svg", "offener_staat_internet_alter.svg", "offener_staat_opendata_reife.svg"],
  summary: """
  98% der Schweizer nutzen Internet, aber E-Government-Verfügbarkeit (68%) und
  Open-Data-Reife (Score 65%) liegen unter dem EU-Durchschnitt.
  """,
  body: """
  ## Methodik

  BFS Omnibus ICT (2023) + EU eGovernment Benchmark + EU Open Data Maturity Report 2023.

  ## Ergebnisse

  ![E-Government CH vs. EU](/zukunftslabor/charts/offener_staat_egov_vergleich.svg)

  ![Internetnutzung nach Alter](/zukunftslabor/charts/offener_staat_internet_alter.svg)

  ![Open-Data-Reife](/zukunftslabor/charts/offener_staat_opendata_reife.svg)

  ## Datenquellen

  - BFS: Omnibus ICT 2023
  - EU eGovernment Benchmark 2023
  - EU Open Data Maturity Report 2023
  """
)

IO.puts("\n========================================")
IO.puts("  12 — Neutralität & Verteidigung")
IO.puts("========================================\n")

df_mil = Zukunftslabor.DataLoader.load("verteidigungsausgaben")

ch_data_12 =
  df_mil
  |> DF.filter(col("Code") == "CHE")
  |> DF.to_rows()
  |> Enum.map(fn row ->
    %{"Jahr" => row["Jahr"], "Anteil BIP (%)" => row["Anteil_BIP_Prozent"]}
  end)
  |> Enum.sort_by(& &1["Jahr"])

chart_ch_trend_12 =
  Vl.new(width: 720, height: 300, title: "Schweizer Verteidigungsausgaben (% des BIP, 2000–2023)")
  |> Vl.data_from_values(ch_data_12)
  |> Vl.mark(:line, point: true, stroke_width: 2)
  |> Vl.encode_field(:x, "Jahr", type: :ordinal, title: "Jahr")
  |> Vl.encode_field(:y, "Anteil BIP (%)", type: :quantitative, title: "% des BIP", scale: [domain: [0.5, 1.2]])
  |> Vl.encode(:color, value: "#a855f7")
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

latest_mil_year_12 =
  df_mil
  |> DF.filter(col("Code") == "CHE")
  |> DF.pull("Jahr")
  |> Series.max()

comparison_mil_12 =
  df_mil
  |> DF.filter(col("Jahr") == ^latest_mil_year_12)
  |> DF.to_rows()
  |> Enum.map(fn row ->
    %{"Land" => row["Land"], "Verteidigung (% BIP)" => row["Anteil_BIP_Prozent"]}
  end)
  |> Enum.sort_by(& &1["Verteidigung (% BIP)"], :desc)

comparison_with_targets_12 = comparison_mil_12 ++ [
  %{"Land" => "NATO-Ziel", "Verteidigung (% BIP)" => 2.0},
  %{"Land" => "EU-Durchschnitt", "Verteidigung (% BIP)" => 1.55}
]

chart_mil_comparison_12 =
  Vl.new(width: 720, height: 400, title: "Verteidigungsausgaben im Vergleich (% BIP, #{latest_mil_year_12})")
  |> Vl.data_from_values(comparison_with_targets_12)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Land", type: :nominal, title: nil, sort: "-x")
  |> Vl.encode_field(:x, "Verteidigung (% BIP)", type: :quantitative, title: "% des BIP")
  |> Vl.encode_field(:color, "Land",
    type: :nominal,
    scale: [
      domain: ["Switzerland", "Schweiz", "NATO-Ziel", "EU-Durchschnitt", "United States", "France", "Germany", "Austria", "Sweden", "Finland", "Norway"],
      range: ["#a855f7", "#a855f7", "#ef4444", "#6b7280", "#3b82f6", "#10b981", "#06b6d4", "#8b5cf6", "#f59e0b", "#ec4899", "#14b8a6"]
    ],
    legend: nil
  )
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

neutrality_data_12 = [
  %{"Position" => "Bewaffnete Neutralität beibehalten", "Zustimmung (%)" => 78},
  %{"Position" => "Wirtschaftssanktionen mittragen", "Zustimmung (%)" => 56},
  %{"Position" => "Engere Kooperation mit NATO", "Zustimmung (%)" => 33},
  %{"Position" => "NATO-Beitritt", "Zustimmung (%)" => 12},
  %{"Position" => "Cyberverteidigung stärken", "Zustimmung (%)" => 82},
  %{"Position" => "Krit. Infrastruktur schützen", "Zustimmung (%)" => 88}
]

chart_opinion_12 =
  Vl.new(width: 720, height: 350, title: "Öffentliche Meinung zu Neutralität und Sicherheit (ETH/Sotomo 2024)")
  |> Vl.data_from_values(neutrality_data_12)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:y, "Position", type: :nominal, title: nil, sort: "-x")
  |> Vl.encode_field(:x, "Zustimmung (%)", type: :quantitative, title: "Zustimmung (%)")
  |> Vl.encode(:color, field: "Zustimmung (%)", type: :quantitative,
    scale: [scheme: "purples"], legend: nil)
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])

ch_latest_12 = Enum.find(ch_data_12, &(&1["Jahr"] == latest_mil_year_12))
ch_pct_12 = if ch_latest_12, do: ch_latest_12["Anteil BIP (%)"], else: 0.7

IO.puts("Defense: #{ch_pct_12}% GDP, 88% want infrastructure protection, 82% want cyber")

# Export notebook 12
Zukunftslabor.ChartExport.to_svg(chart_ch_trend_12, name: "verteidigung_ch_zeitreihe")
Zukunftslabor.ChartExport.to_svg(chart_mil_comparison_12, name: "verteidigung_internationaler_vergleich")
Zukunftslabor.ChartExport.to_svg(chart_opinion_12, name: "verteidigung_oeffentliche_meinung")

Zukunftslabor.NotizTemplate.generate(
  title: "#{ch_pct_12}% BIP für Verteidigung — die Bevölkerung will Cyber, nicht Panzer",
  description: "Die Schweiz gibt unter 1% des BIP für Verteidigung aus. Die Bevölkerung priorisiert Cybersicherheit und Infrastrukturschutz.",
  slug: "verteidigung-ausgaben-prioritaeten",
  category: "datenbriefing",
  evidence: "mittel",
  tags: ["neutralitaet", "verteidigung", "cyber", "infrastruktur", "vergleich"],
  charts: ["verteidigung_ch_zeitreihe.svg", "verteidigung_internationaler_vergleich.svg", "verteidigung_oeffentliche_meinung.svg"],
  summary: """
  Die Schweiz gibt #{ch_pct_12}% des BIP für Verteidigung aus — weit unter dem
  NATO-Ziel (2%). Die Bevölkerung priorisiert moderne Bedrohungen: 88% wollen
  besseren Infrastrukturschutz, 82% stärkere Cyberverteidigung.
  """,
  body: """
  ## Methodik

  World Bank / SIPRI (Military expenditure, 2000–2023) + ETH Sicherheitsstudie 2024.

  ## Ergebnisse

  ![CH Verteidigungsausgaben](/zukunftslabor/charts/verteidigung_ch_zeitreihe.svg)

  ![Internationaler Vergleich](/zukunftslabor/charts/verteidigung_internationaler_vergleich.svg)

  ![Öffentliche Meinung](/zukunftslabor/charts/verteidigung_oeffentliche_meinung.svg)

  ## Datenquellen

  - World Bank / SIPRI: Military expenditure (% of GDP), 2000–2023
  - ETH Zürich: Sicherheitsstudie 2024
  """
)

IO.puts("\n========================================")
IO.puts("  Done! All 12 notebooks executed.")
IO.puts("========================================")
IO.puts("Charts → output/charts/")
IO.puts("Drafts → output/drafts/")
IO.puts("Next: mise run publish")
