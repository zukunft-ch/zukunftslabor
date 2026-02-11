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
IO.puts("  Done! All 4 notebooks executed.")
IO.puts("========================================")
IO.puts("Charts → output/charts/")
IO.puts("Drafts → output/drafts/")
IO.puts("Next: mise run publish")
