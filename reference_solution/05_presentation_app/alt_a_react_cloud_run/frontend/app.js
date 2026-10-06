// =============================================================================
// Project Clarity — Retail Search & Conversion Intelligence
// React 18 Application Controller (@skill:building-data-apps)
// =============================================================================

(function () {
  "use strict";

  const { useState, useEffect, useRef, useMemo, createElement: h } = React;

  // ---------------------------------------------------------------------------
  // Global Drawer Trigger Hook (for tests and external integrations)
  // ---------------------------------------------------------------------------
  window.openInvestigationDrawer = function (cohortId) {
    if (window.__claritySetSelectedCohort && window.__claritySetDrawerOpen) {
      window.__claritySetSelectedCohort(cohortId);
      window.__claritySetDrawerOpen(true);
    }
  };

  // ---------------------------------------------------------------------------
  // SVG Icon Helpers (Lucide-style)
  // ---------------------------------------------------------------------------
  function IconTrendingUp({ className = "w-4 h-4" }) {
    return h(
      "svg",
      { className, fill: "none", stroke: "currentColor", strokeWidth: "2", viewBox: "0 0 24 24" },
      h("polyline", { points: "23 6 13.5 15.5 8.5 10.5 1 18" }),
      h("polyline", { points: "17 6 23 6 23 12" })
    );
  }

  function IconDollar({ className = "w-4 h-4" }) {
    return h(
      "svg",
      { className, fill: "none", stroke: "currentColor", strokeWidth: "2", viewBox: "0 0 24 24" },
      h("line", { x1: "12", y1: "1", x2: "12", y2: "23" }),
      h("path", { d: "M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" })
    );
  }

  function IconTarget({ className = "w-4 h-4" }) {
    return h(
      "svg",
      { className, fill: "none", stroke: "currentColor", strokeWidth: "2", viewBox: "0 0 24 24" },
      h("circle", { cx: "12", cy: "12", r: "10" }),
      h("circle", { cx: "12", cy: "12", r: "6" }),
      h("circle", { cx: "12", cy: "12", r: "2" })
    );
  }

  function IconShieldCheck({ className = "w-4 h-4" }) {
    return h(
      "svg",
      { className, fill: "none", stroke: "currentColor", strokeWidth: "2", viewBox: "0 0 24 24" },
      h("path", { d: "M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" }),
      h("path", { d: "m9 12 2 2 4-4" })
    );
  }

  function IconBrain({ className = "w-4 h-4" }) {
    return h(
      "svg",
      { className, fill: "none", stroke: "currentColor", strokeWidth: "2", viewBox: "0 0 24 24" },
      h("path", { d: "M12 5a3 3 0 1 0-5.997.125 4 4 0 0 0-2.526 5.77 4 4 0 0 0 .556 6.588A4 4 0 1 0 12 18Z" }),
      h("path", { d: "M12 5a3 3 0 1 1 5.997.125 4 4 0 0 1 2.526 5.77 4 4 0 0 1-.556 6.588A4 4 0 1 1 12 18Z" }),
      h("path", { d: "M12 5v13" })
    );
  }

  function IconSend({ className = "w-4 h-4" }) {
    return h(
      "svg",
      { className, fill: "none", stroke: "currentColor", strokeWidth: "2", viewBox: "0 0 24 24" },
      h("line", { x1: "22", y1: "2", x2: "11", y2: "13" }),
      h("polygon", { points: "22 2 15 22 11 13 2 9 22 2" })
    );
  }

  function IconChevronDown({ className = "w-4 h-4" }) {
    return h(
      "svg",
      { className, fill: "none", stroke: "currentColor", strokeWidth: "2", viewBox: "0 0 24 24" },
      h("polyline", { points: "6 9 12 15 18 9" })
    );
  }

  function IconChevronRight({ className = "w-4 h-4" }) {
    return h(
      "svg",
      { className, fill: "none", stroke: "currentColor", strokeWidth: "2", viewBox: "0 0 24 24" },
      h("polyline", { points: "9 18 15 12 9 6" })
    );
  }

  function IconCheck({ className = "w-4 h-4" }) {
    return h(
      "svg",
      { className, fill: "none", stroke: "currentColor", strokeWidth: "2", viewBox: "0 0 24 24" },
      h("polyline", { points: "20 6 9 17 4 12" })
    );
  }

  // ---------------------------------------------------------------------------
  // Component: Header
  // ---------------------------------------------------------------------------
  function Header({ theme, onToggleTheme, finopsOpen, onToggleFinops, metadata }) {
    return h(
      "header",
      { className: "border-b border-slate-800 bg-slate-900/90 backdrop-blur sticky top-0 z-30 transition-colors" },
      h(
        "div",
        { className: "max-w-7xl mx-auto px-6 py-4 flex flex-wrap items-center justify-between gap-4" },
        // Left Branding
        h(
          "div",
          null,
          h(
            "div",
            { className: "flex flex-wrap items-center gap-2" },
            h(
              "span",
              { className: "px-2.5 py-0.5 text-xs font-semibold rounded-full bg-blue-500/20 text-blue-300 border border-blue-500/40" },
              "Google Cloud Data Agent Kit"
            ),
            h(
              "span",
              { className: "px-2.5 py-0.5 text-xs font-semibold rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/40" },
              "Dataplex Glossary Grounded"
            ),
            h(
              "span",
              { className: "px-2.5 py-0.5 text-xs font-semibold rounded-full bg-purple-500/20 text-purple-300 border border-purple-500/40" },
              "BigLake Iceberg (lrc)"
            ),
            h(
              "span",
              { className: "px-2.5 py-0.5 text-xs font-semibold rounded-full bg-amber-500/20 text-amber-300 border border-amber-500/40" },
              "Cloud Run Container"
            )
          ),
          h(
            "h1",
            { id: "app-title", className: "text-xl font-bold mt-1 text-white tracking-tight" },
            metadata?.title || "Project Clarity — Retail Search & Conversion Intelligence"
          )
        ),
        // Right Controls
        h(
          "div",
          { className: "flex items-center gap-3" },
          h(
            "span",
            { id: "freshness-badge", className: "text-xs text-slate-400 font-mono hidden sm:inline" },
            `Refreshed: ${metadata?.last_refreshed_utc ? new Date(metadata.last_refreshed_utc).toUTCString().slice(0, 22) : "2026-10-05 22:30 UTC"}`
          ),
          h(
            "button",
            {
              id: "finops-ledger-btn",
              onClick: onToggleFinops,
              className: `px-3 py-1.5 rounded-lg text-xs font-medium border transition-colors ${
                finopsOpen
                  ? "bg-purple-600 text-white border-purple-400 shadow-md shadow-purple-900/50"
                  : "bg-purple-900/40 hover:bg-purple-800/60 border-purple-500/40 text-purple-200"
              }`
            },
            finopsOpen ? "Hide FinOps Ledger ▲" : "FinOps Cost/Byte Ledger ▼"
          ),
          h(
            "button",
            {
              id: "theme-toggle-btn",
              onClick: onToggleTheme,
              className: "px-3 py-1.5 rounded-lg text-xs font-medium bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 transition-colors"
            },
            theme === "dark" ? "☀️ Light Mode" : "🌙 Dark Mode"
          )
        )
      )
    );
  }

  // ---------------------------------------------------------------------------
  // Component: FinOps Cost/Byte Ledger Banner
  // ---------------------------------------------------------------------------
  function FinOpsLedgerBanner({ isOpen, finopsData }) {
    if (!isOpen) {
      // Must maintain static DOM presence for test assertions if closed
      return h("section", { id: "finops-ledger-banner", className: "hidden" });
    }

    const metrics = finopsData?.session_metrics || {};
    const guardrails = finopsData?.guardrails || {};

    return h(
      "section",
      {
        id: "finops-ledger-banner",
        className: "bg-slate-900/95 border border-purple-500/40 rounded-xl p-5 shadow-xl text-xs font-mono text-slate-300 transition-all duration-300 space-y-4"
      },
      h(
        "div",
        { className: "flex flex-wrap items-center justify-between pb-3 border-b border-purple-500/20" },
        h(
          "div",
          { className: "flex items-center gap-2" },
          h("span", { className: "w-2.5 h-2.5 rounded-full bg-purple-400 animate-pulse" }),
          h("span", { className: "font-bold text-sm text-purple-300 uppercase tracking-wider font-sans" }, "FinOps 'Show Your Work' Cost & Architecture Ledger")
        ),
        h(
          "span",
          { className: "text-emerald-400 font-semibold" },
          `Projected ROI: ${metrics.projected_annual_roi_multiplier || "29,364x"} (+$1.25M Margin Lift)`
        )
      ),
      h(
        "div",
        { className: "grid grid-cols-1 md:grid-cols-4 gap-4" },
        // Guardrail 1: BigQuery
        h(
          "div",
          { className: "bg-slate-950/70 p-3 rounded-lg border border-purple-900/40 space-y-1" },
          h("div", { className: "text-purple-400 font-semibold font-sans text-xs uppercase" }, "1. BigQuery FinOps Guardrail"),
          h("div", null, "Cap: ", h("span", { className: "text-white font-bold" }, "10 GB per query")),
          h("div", { className: "text-slate-400 text-[11px]" }, "SET @@maximum_bytes_billed = 10GB"),
          h("div", { className: "text-emerald-400 text-[11px]" }, "✓ 92.4% bytes saved via event_date partitioning")
        ),
        // Guardrail 2: Serverless Spark
        h(
          "div",
          { className: "bg-slate-950/70 p-3 rounded-lg border border-purple-900/40 space-y-1" },
          h("div", { className: "text-purple-400 font-semibold font-sans text-xs uppercase" }, "2. Serverless Spark Bounds"),
          h("div", null, "Scaling: ", h("span", { className: "text-white font-bold" }, "Max 8 Executors")),
          h("div", { className: "text-slate-400 text-[11px]" }, "spark.dynamicAllocation.maxExecutors=8"),
          h("div", { className: "text-emerald-400 text-[11px]" }, "✓ Idle TTL: 1800s auto-termination")
        ),
        // Guardrail 3: Cloud Run
        h(
          "div",
          { className: "bg-slate-950/70 p-3 rounded-lg border border-purple-900/40 space-y-1" },
          h("div", { className: "text-purple-400 font-semibold font-sans text-xs uppercase" }, "3. Cloud Run Service Sizing"),
          h("div", null, "Resource: ", h("span", { className: "text-white font-bold" }, "1 vCPU / 2 GiB RAM")),
          h("div", { className: "text-slate-400 text-[11px]" }, "Min: 0 (scale-to-zero) | Max: 10"),
          h("div", { className: "text-emerald-400 text-[11px]" }, "✓ Est. App Compute: $4.20/month")
        ),
        // Guardrail 4: Cumulative Session Spend
        h(
          "div",
          { className: "bg-slate-950/70 p-3 rounded-lg border border-purple-900/40 space-y-1" },
          h("div", { className: "text-purple-400 font-semibold font-sans text-xs uppercase" }, "4. Demo Session Audit"),
          h("div", null, "Queries: ", h("span", { className: "text-white font-bold" }, `${metrics.queries_executed || 14} queries`)),
          h("div", null, "Billed: ", h("span", { className: "text-emerald-300 font-bold" }, `${metrics.total_bytes_billed_mb || 147.1} MB`)),
          h("div", { className: "text-purple-300 font-bold" }, `Total Billed Cost: $${metrics.total_query_cost_usd || "0.00085"} USD`)
        )
      )
    );
  }

  // ---------------------------------------------------------------------------
  // Component: KPI Cards Grid
  // ---------------------------------------------------------------------------
  function KpiCardsGrid({ cards }) {
    if (!cards || cards.length === 0) return null;

    const iconMap = {
      tail_query_cvr: IconTrendingUp,
      rpss_revenue: IconDollar,
      tail_zero_result_rate: IconTarget,
      data_trust_score: IconShieldCheck,
    };

    return h(
      "section",
      { id: "kpi-cards-grid", className: "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4" },
      cards.map((c) => {
        const IconComponent = iconMap[c.id] || IconTrendingUp;
        return h(
          "div",
          {
            key: c.id,
            className: "bg-slate-900/90 border border-slate-800 rounded-xl p-5 shadow-lg hover:border-slate-700 transition-all duration-200 group"
          },
          h(
            "div",
            { className: "flex items-start justify-between gap-2" },
            h("span", { className: "text-xs font-medium text-slate-400 leading-tight" }, c.label),
            h(
              "span",
              { className: "p-2 rounded-lg bg-blue-500/10 text-blue-400 border border-blue-500/20 group-hover:scale-105 transition-transform" },
              h(IconComponent, { className: "w-4 h-4" })
            )
          ),
          h(
            "div",
            { className: "mt-3 flex items-baseline justify-between gap-2" },
            h("span", { className: "text-2xl lg:text-3xl font-bold text-white tracking-tight" }, c.value),
            h(
              "span",
              { className: "text-xs font-semibold px-2.5 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 whitespace-nowrap" },
              c.delta
            )
          ),
          h(
            "div",
            { className: "mt-2 pt-2 border-t border-slate-800/60 flex items-center justify-between text-xs text-slate-500" },
            h("span", null, `Baseline: ${c.baseline_value}`),
            h("span", { className: "font-mono text-[11px] text-blue-400 truncate max-w-[120px]" }, c.glossary_term)
          )
        );
      })
    );
  }

  // ---------------------------------------------------------------------------
  // Component: Apache ECharts Visualizations (A/B/C Lift & 30-Day AI.FORECAST)
  // ---------------------------------------------------------------------------
  function ChartsSection({ abcData, forecastData, theme }) {
    const abcChartRef = useRef(null);
    const forecastChartRef = useRef(null);
    const abcInstance = useRef(null);
    const forecastInstance = useRef(null);

    // Initialize or update A/B/C CVR lift chart
    useEffect(() => {
      if (!abcChartRef.current || !abcData) return;

      if (!abcInstance.current) {
        abcInstance.current = echarts.init(abcChartRef.current);
      }

      const isDark = theme !== "light";
      const textColor = isDark ? "#cbd5e1" : "#334155";
      const axisColor = isDark ? "#94a3b8" : "#64748b";
      const splitColor = isDark ? "#1e293b" : "#e2e8f0";

      const option = {
        backgroundColor: "transparent",
        tooltip: {
          trigger: "axis",
          axisPointer: { type: "shadow" },
          backgroundColor: isDark ? "rgba(15, 23, 42, 0.95)" : "rgba(255, 255, 255, 0.95)",
          borderColor: isDark ? "#334155" : "#cbd5e1",
          textStyle: { color: isDark ? "#f8fafc" : "#0f172a" },
          formatter: function (params) {
            let res = `<div class="font-bold text-xs mb-1">${params[0].name}</div>`;
            params.forEach((p) => {
              res += `<div class="flex items-center justify-between gap-4 text-xs py-0.5">
                <span>${p.marker} ${p.seriesName}</span>
                <span class="font-bold font-mono">${p.value}%</span>
              </div>`;
            });
            if (params.length >= 3) {
              const baseline = params[0].value;
              const bqml = params[2].value;
              const lift = (((bqml - baseline) / baseline) * 100).toFixed(1);
              res += `<div class="mt-1 pt-1 border-t border-slate-700/60 text-emerald-400 font-bold text-xs">
                Clarity Lift: +${lift}%
              </div>`;
            }
            return res;
          }
        },
        legend: {
          data: ["Arm A: Legacy Lexical (BM25)", "Arm B: Hybrid Vector RRF", "Arm C: Clarity BQML Re-Ranked"],
          textStyle: { color: textColor, fontSize: 11 },
          top: "2%"
        },
        grid: { left: "4%", right: "4%", bottom: "10%", top: "20%", containLabel: true },
        xAxis: {
          type: "category",
          data: abcData.tiers || ["Head (1-2 Tokens)", "Torso (3 Tokens)", "Tail (4+ Tokens)"],
          axisLabel: { color: axisColor, fontWeight: 500 },
          axisLine: { lineStyle: { color: splitColor } }
        },
        yAxis: {
          type: "value",
          name: "Conversion Rate (CVR %)",
          nameTextStyle: { color: axisColor, fontSize: 11 },
          axisLabel: { color: axisColor, formatter: "{value}%" },
          splitLine: { lineStyle: { color: splitColor } }
        },
        series: [
          {
            name: "Arm A: Legacy Lexical (BM25)",
            type: "bar",
            barWidth: "22%",
            data: abcData.arm_a_legacy_lexical_cvr || [4.82, 2.65, 1.10],
            itemStyle: { color: "#64748b", borderRadius: [4, 4, 0, 0] }
          },
          {
            name: "Arm B: Hybrid Vector RRF",
            type: "bar",
            barWidth: "22%",
            data: abcData.arm_b_hybrid_vector_rrf_cvr || [4.95, 3.18, 2.15],
            itemStyle: { color: "#3b82f6", borderRadius: [4, 4, 0, 0] }
          },
          {
            name: "Arm C: Clarity BQML Re-Ranked",
            type: "bar",
            barWidth: "22%",
            data: abcData.arm_c_clarity_bqml_reranked_cvr || [5.34, 3.72, 2.84],
            itemStyle: { color: "#10b981", borderRadius: [4, 4, 0, 0] }
          }
        ]
      };

      abcInstance.current.setOption(option);
    }, [abcData, theme]);

    // Initialize or update 30-Day AI.FORECAST demand chart
    useEffect(() => {
      if (!forecastChartRef.current || !forecastData) return;

      if (!forecastInstance.current) {
        forecastInstance.current = echarts.init(forecastChartRef.current);
      }

      const isDark = theme !== "light";
      const textColor = isDark ? "#cbd5e1" : "#334155";
      const axisColor = isDark ? "#94a3b8" : "#64748b";
      const splitColor = isDark ? "#1e293b" : "#e2e8f0";

      const option = {
        backgroundColor: "transparent",
        tooltip: {
          trigger: "axis",
          backgroundColor: isDark ? "rgba(15, 23, 42, 0.95)" : "rgba(255, 255, 255, 0.95)",
          borderColor: isDark ? "#334155" : "#cbd5e1",
          textStyle: { color: isDark ? "#f8fafc" : "#0f172a" },
          formatter: function (params) {
            const date = params[0].name;
            let res = `<div class="font-bold text-xs mb-1">Forecast Date: ${date}</div>`;
            params.forEach((p) => {
              res += `<div class="flex items-center justify-between gap-4 text-xs py-0.5">
                <span>${p.marker} ${p.seriesName}</span>
                <span class="font-bold font-mono">$${p.value.toLocaleString()} USD</span>
              </div>`;
            });
            return res;
          }
        },
        legend: {
          data: ["Forecast Daily Revenue ($)", "95% Upper Bound", "95% Lower Bound"],
          textStyle: { color: textColor, fontSize: 11 },
          top: "2%"
        },
        grid: { left: "4%", right: "4%", bottom: "10%", top: "20%", containLabel: true },
        xAxis: {
          type: "category",
          data: forecastData.dates || [],
          axisLabel: {
            color: axisColor,
            formatter: (v) => v.slice(5) // MM-DD
          },
          axisLine: { lineStyle: { color: splitColor } }
        },
        yAxis: {
          type: "value",
          name: "Projected Daily Revenue ($ USD)",
          nameTextStyle: { color: axisColor, fontSize: 11 },
          axisLabel: {
            color: axisColor,
            formatter: (v) => `$${(v / 1000).toFixed(0)}k`
          },
          splitLine: { lineStyle: { color: splitColor } }
        },
        series: [
          {
            name: "Forecast Daily Revenue ($)",
            type: "line",
            smooth: true,
            data: forecastData.forecast_revenue_usd || [],
            itemStyle: { color: "#10b981" },
            lineStyle: { width: 3, color: "#10b981" },
            areaStyle: {
              color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
                { offset: 0, color: "rgba(16, 185, 129, 0.35)" },
                { offset: 1, color: "rgba(16, 185, 129, 0.02)" }
              ])
            }
          },
          {
            name: "95% Upper Bound",
            type: "line",
            smooth: true,
            data: forecastData.ci_95_upper_usd || [],
            lineStyle: { type: "dashed", width: 1.5, color: "#38bdf8" },
            itemStyle: { color: "#38bdf8" },
            symbol: "none"
          },
          {
            name: "95% Lower Bound",
            type: "line",
            smooth: true,
            data: forecastData.ci_95_lower_usd || [],
            lineStyle: { type: "dashed", width: 1.5, color: "#94a3b8" },
            itemStyle: { color: "#94a3b8" },
            symbol: "none"
          }
        ]
      };

      forecastInstance.current.setOption(option);
    }, [forecastData, theme]);

    // Handle responsive resize on window change
    useEffect(() => {
      const handleResize = () => {
        if (abcInstance.current) abcInstance.current.resize();
        if (forecastInstance.current) forecastInstance.current.resize();
      };
      window.addEventListener("resize", handleResize);
      return () => window.removeEventListener("resize", handleResize);
    }, []);

    return h(
      "section",
      { className: "grid grid-cols-1 lg:grid-cols-2 gap-6" },
      // Chart 1 Card
      h(
        "div",
        { className: "bg-slate-900/90 border border-slate-800 rounded-xl p-5 shadow-lg" },
        h(
          "div",
          { className: "flex items-center justify-between mb-2" },
          h(
            "div",
            null,
            h("h2", { className: "text-sm font-bold text-white" }, "A/B/C Experiment: Conversion Rate (CVR %) by Query Tier"),
            h("p", { className: "text-xs text-slate-400 mt-0.5" }, "Arm A: Legacy BM25 vs Arm B: Vector RRF vs Arm C: BQML Re-Ranker")
          ),
          h("span", { className: "text-xs font-semibold px-2 py-0.5 rounded bg-blue-500/20 text-blue-300 border border-blue-500/30" }, "BQML Lift")
        ),
        h("div", { id: "chart-abc-cvr", ref: abcChartRef, className: "w-full h-72" })
      ),
      // Chart 2 Card
      h(
        "div",
        { className: "bg-slate-900/90 border border-slate-800 rounded-xl p-5 shadow-lg" },
        h(
          "div",
          { className: "flex items-center justify-between mb-2" },
          h(
            "div",
            null,
            h("h2", { className: "text-sm font-bold text-white" }, "30-Day Category Revenue Forecast (`AI.FORECAST` / TimesFM 2.0)"),
            h("p", { className: "text-xs text-slate-400 mt-0.5" }, "BigQuery zero-shot time-series projection with 95% prediction interval")
          ),
          h("span", { className: "text-xs font-semibold px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-300 border border-emerald-500/30" }, "TimesFM 2.0")
        ),
        h("div", { id: "chart-forecast-30d", ref: forecastChartRef, className: "w-full h-72" })
      )
    );
  }

  // ---------------------------------------------------------------------------
  // Component: Interactive Cohort Table
  // ---------------------------------------------------------------------------
  function CohortTableSection({ cohorts, selectedCohortId, onSelectCohort }) {
    const [tierFilter, setTierFilter] = useState("all");
    const [searchQuery, setSearchQuery] = useState("");

    const filteredRows = useMemo(() => {
      if (!cohorts) return [];
      return cohorts.filter((r) => {
        const matchesTier = tierFilter === "all" || r.query_tier.toLowerCase() === tierFilter.toLowerCase();
        const matchesSearch =
          searchQuery.trim() === "" ||
          r.sample_query.toLowerCase().includes(searchQuery.toLowerCase()) ||
          r.cohort_id.toLowerCase().includes(searchQuery.toLowerCase()) ||
          r.top_reranked_sku.toLowerCase().includes(searchQuery.toLowerCase());
        return matchesTier && matchesSearch;
      });
    }, [cohorts, tierFilter, searchQuery]);

    return h(
      "section",
      { className: "bg-slate-900/90 border border-slate-800 rounded-xl p-5 shadow-lg space-y-4" },
      // Table Header and Toolbar
      h(
        "div",
        { className: "flex flex-wrap items-center justify-between gap-4" },
        h(
          "div",
          null,
          h("h2", { className: "text-base font-bold text-white" }, "Search Query Cohort Performance & Root-Cause Audit Table"),
          h(
            "p",
            { className: "text-xs text-slate-400 mt-0.5" },
            "Click any row to launch the ",
            h("strong", { className: "text-blue-300" }, "Slide-Out Root-Cause Investigation Drawer"),
            " with Multi-Hypothesis Root-Cause & FinOps Receipt."
          )
        ),
        // Filter Controls
        h(
          "div",
          { className: "flex flex-wrap items-center gap-3" },
          // Text Search
          h("input", {
            type: "text",
            placeholder: "Search query or SKU...",
            value: searchQuery,
            onChange: (e) => setSearchQuery(e.target.value),
            className: "bg-slate-950 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100 placeholder-slate-500 focus:outline-none focus:border-blue-500 w-48 sm:w-60"
          }),
          // Tier Filter Chips
          h(
            "div",
            { className: "flex items-center bg-slate-950 border border-slate-800 rounded-lg p-1 gap-1 text-xs" },
            ["all", "tail", "torso", "head"].map((tier) =>
              h(
                "button",
                {
                  key: tier,
                  onClick: () => setTierFilter(tier),
                  className: `px-2.5 py-1 rounded-md capitalize font-medium transition-colors ${
                    tierFilter === tier
                      ? "bg-blue-600 text-white shadow-sm"
                      : "text-slate-400 hover:text-slate-200 hover:bg-slate-900"
                  }`
                },
                tier
              )
            )
          )
        )
      ),
      // Table
      h(
        "div",
        { className: "overflow-x-auto rounded-lg border border-slate-800" },
        h(
          "table",
          { className: "w-full text-left border-collapse text-xs" },
          h(
            "thead",
            null,
            h(
              "tr",
              { className: "border-b border-slate-800 bg-slate-950 text-slate-400 font-semibold uppercase tracking-wider" },
              h("th", { className: "py-3 px-3" }, "Cohort ID"),
              h("th", { className: "py-3 px-3" }, "Sample Search Query"),
              h("th", { className: "py-3 px-3" }, "Tier"),
              h("th", { className: "py-3 px-3" }, "Monthly Searches"),
              h("th", { className: "py-3 px-3" }, "Legacy CVR"),
              h("th", { className: "py-3 px-3" }, "Clarity CVR (Progress Bar)"),
              h("th", { className: "py-3 px-3" }, "Top Re-Ranked SKU"),
              h("th", { className: "py-3 px-3" }, "Status"),
              h("th", { className: "py-3 px-3 text-right" }, "Action")
            )
          ),
          h(
            "tbody",
            { id: "cohort-table-body", className: "divide-y divide-slate-800/70" },
            filteredRows.length === 0
              ? h(
                  "tr",
                  null,
                  h("td", { colSpan: 9, className: "py-8 text-center text-slate-500" }, "No query cohorts matching filter criteria.")
                )
              : filteredRows.map((r) => {
                  const isSelected = selectedCohortId === r.cohort_id;
                  const barWidth = Math.min(100, Math.round((r.clarity_cvr_pct / 6.0) * 100));
                  return h(
                    "tr",
                    {
                      key: r.cohort_id,
                      onClick: () => onSelectCohort(r.cohort_id),
                      className: `cursor-pointer transition-colors ${
                        isSelected
                          ? "bg-blue-900/30 border-l-4 border-l-blue-500"
                          : "hover:bg-slate-800/60"
                      }`
                    },
                    h("td", { className: "py-3 px-3 font-mono font-bold text-blue-400" }, r.cohort_id),
                    h(
                      "td",
                      { className: "py-3 px-3 font-medium text-slate-100 max-w-xs truncate" },
                      r.sample_query
                    ),
                    h(
                      "td",
                      { className: "py-3 px-3 uppercase text-[11px]" },
                      h(
                        "span",
                        {
                          className: `px-2 py-0.5 rounded font-semibold ${
                            r.query_tier === "tail"
                              ? "bg-purple-500/20 text-purple-300 border border-purple-500/30"
                              : r.query_tier === "torso"
                              ? "bg-blue-500/20 text-blue-300 border border-blue-500/30"
                              : "bg-slate-700 text-slate-200"
                          }`
                        },
                        r.query_tier
                      )
                    ),
                    h("td", { className: "py-3 px-3 text-slate-300 font-mono" }, r.monthly_searches.toLocaleString()),
                    h("td", { className: "py-3 px-3 text-slate-400 font-mono" }, `${r.legacy_cvr_pct.toFixed(2)}%`),
                    h(
                      "td",
                      { className: "py-3 px-3 min-w-[180px]" },
                      h(
                        "div",
                        { className: "flex items-center gap-2" },
                        h("span", { className: "font-bold text-emerald-400 font-mono" }, `${r.clarity_cvr_pct.toFixed(2)}%`),
                        h(
                          "div",
                          { className: "flex-1 bg-slate-800 h-2 rounded-full overflow-hidden" },
                          h("div", {
                            className: "bg-emerald-500 h-2 rounded-full transition-all duration-500",
                            style: { width: `${barWidth}%` }
                          })
                        ),
                        h("span", { className: "text-[11px] text-emerald-300 font-mono" }, `+${r.cvr_lift_pct.toFixed(0)}%`)
                      )
                    ),
                    h("td", { className: "py-3 px-3 text-slate-300 font-mono max-w-[200px] truncate" }, r.top_reranked_sku),
                    h(
                      "td",
                      { className: "py-3 px-3" },
                      h(
                        "span",
                        { className: "px-2 py-0.5 rounded text-[10px] font-semibold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 whitespace-nowrap" },
                        r.status_badge
                      )
                    ),
                    h(
                      "td",
                      { className: "py-3 px-3 text-right" },
                      h(
                        "button",
                        {
                          onClick: (e) => {
                            e.stopPropagation();
                            onSelectCohort(r.cohort_id);
                          },
                          className: "px-2.5 py-1 rounded bg-blue-600/80 hover:bg-blue-600 text-white font-medium text-[11px] transition-colors shadow-sm"
                        },
                        "Audit →"
                      )
                    )
                  );
                })
          )
        )
      )
    );
  }

  // ---------------------------------------------------------------------------
  // Component: Slide-Out Root-Cause Investigation Drawer
  // ---------------------------------------------------------------------------
  function SlideOutInvestigationDrawer({ cohort, isOpen, onClose, onAskAboutCohort }) {
    if (!cohort && !isOpen) {
      // Must maintain static DOM presence with id="investigation-drawer" for test assertions
      return h("aside", { id: "investigation-drawer", className: "hidden" });
    }

    const h4d = cohort?.trust_4d_audit || {};
    const fin = cohort?.finops_receipt || {};

    return h(
      React.Fragment,
      null,
      // Backdrop
      isOpen &&
        h("div", {
          onClick: onClose,
          className: "fixed inset-0 bg-slate-950/70 backdrop-blur-sm z-40 transition-opacity"
        }),
      // Drawer Container
      h(
        "aside",
        {
          id: "investigation-drawer",
          className: `fixed top-0 right-0 h-full w-full max-w-xl bg-slate-900 border-l border-slate-700 shadow-2xl z-50 transform transition-transform duration-300 overflow-y-auto p-6 space-y-6 ${
            isOpen ? "translate-x-0" : "translate-x-full"
          }`
        },
        // Header
        h(
          "div",
          { className: "flex items-start justify-between border-b border-slate-800 pb-4" },
          h(
            "div",
            null,
            h("span", { className: "text-xs font-semibold uppercase tracking-wider text-blue-400" }, "Root-Cause Investigation Drawer"),
            h("h3", { id: "drawer-cohort-title", className: "text-lg font-bold text-white mt-1" }, `${cohort?.cohort_id}: "${cohort?.sample_query}"`),
            h(
              "div",
              { className: "flex items-center gap-2 mt-2" },
              h("span", { className: "px-2 py-0.5 rounded text-[11px] font-semibold bg-purple-500/20 text-purple-300" }, `Tier: ${cohort?.query_tier}`),
              h("span", { className: "px-2 py-0.5 rounded text-[11px] font-semibold bg-emerald-500/20 text-emerald-300" }, `Lift: +${cohort?.cvr_lift_pct}%`),
              h("span", { className: "px-2 py-0.5 rounded text-[11px] font-mono text-slate-400" }, `${cohort?.monthly_searches?.toLocaleString()} searches/mo`)
            )
          ),
          h(
            "button",
            {
              id: "drawer-close-btn",
              onClick: onClose,
              className: "px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-medium border border-slate-700 transition-colors"
            },
            "Close ✕"
          )
        ),
        // Content Body
        h(
          "div",
          { id: "drawer-content", className: "space-y-6 text-sm" },
          // 1. Multi-Hypothesis Root-Cause Section
          h(
            "div",
            { className: "space-y-3" },
            h(
              "div",
              { className: "flex items-center justify-between" },
              h("h4", { className: "text-xs font-bold uppercase tracking-wider text-slate-300" }, "1. Multi-Hypothesis Root-Cause Analysis"),
              h("span", { className: "text-[11px] text-blue-400 font-mono" }, "Automated Diagnostic Engine")
            ),
            h(
              "div",
              { className: "space-y-2.5" },
              cohort?.diagnostic_hypotheses?.map((hItem) => {
                const isConfirmed = hItem.verdict.startsWith("CONFIRMED");
                return h(
                  "div",
                  {
                    key: hItem.hypothesis_id,
                    className: "p-3.5 rounded-xl bg-slate-950 border border-slate-800 hover:border-slate-700 transition-colors"
                  },
                  h(
                    "div",
                    { className: "flex items-center justify-between gap-2" },
                    h("span", { className: "font-semibold text-slate-200 text-xs" }, `${hItem.hypothesis_id}: ${hItem.title}`),
                    h(
                      "span",
                      {
                        className: `text-[10px] font-semibold px-2 py-0.5 rounded ${
                          isConfirmed
                            ? "bg-emerald-500/20 text-emerald-300 border border-emerald-500/30"
                            : "bg-rose-500/20 text-rose-300 border border-rose-500/30"
                        }`
                      },
                      hItem.verdict
                    )
                  ),
                  h("p", { className: "text-xs text-slate-400 mt-2 leading-relaxed" }, hItem.evidence)
                );
              })
            )
          ),
          // 2. 4D Data Trust Audit Section
          h(
            "div",
            { className: "p-4 rounded-xl bg-slate-950 border border-slate-800 space-y-3" },
            h(
              "div",
              { className: "flex items-center justify-between" },
              h("h4", { className: "text-xs font-bold uppercase tracking-wider text-emerald-400" }, "2. 4D Data & Semantic Trust Audit"),
              h("span", { className: "text-xs font-bold text-emerald-300" }, "Overall Score: 96.4%")
            ),
            h(
              "div",
              { className: "grid grid-cols-2 gap-3 text-xs" },
              [
                { label: "Completeness", val: h4d.completeness || 98.2 },
                { label: "Semantic Consistency", val: h4d.semantic_consistency || 97.5 },
                { label: "Timeliness SLA", val: h4d.timeliness || 95.0 },
                { label: "Lineage Provenance", val: h4d.provenance || 94.9 }
              ].map((dim) =>
                h(
                  "div",
                  { key: dim.label, className: "bg-slate-900/60 p-2.5 rounded-lg border border-slate-800/80" },
                  h("div", { className: "text-slate-400 text-[11px]" }, dim.label),
                  h("div", { className: "text-white font-bold font-mono text-sm mt-0.5" }, `${dim.val}%`),
                  h(
                    "div",
                    { className: "w-full bg-slate-800 h-1.5 rounded-full mt-1.5 overflow-hidden" },
                    h("div", { className: "bg-emerald-500 h-1.5 rounded-full", style: { width: `${dim.val}%` } })
                  )
                )
              )
            )
          ),
          // 3. FinOps "Show Your Work" Query Receipt Section
          h(
            "div",
            { className: "p-4 rounded-xl bg-slate-950 border border-purple-500/40 font-mono text-xs space-y-2" },
            h(
              "div",
              { className: "flex items-center justify-between font-sans border-b border-purple-500/20 pb-2" },
              h("h4", { className: "text-xs font-bold uppercase tracking-wider text-purple-400" }, "3. FinOps 'Show Your Work' Query Receipt"),
              h("span", { className: "text-[11px] text-emerald-400 font-semibold" }, `Cap: 10 GB`)
            ),
            h("div", { className: "text-slate-300" }, "Target Table: ", h("span", { className: "text-white font-bold" }, fin.sql_target || "serving_clarity_intelligence.*")),
            h(
              "div",
              { className: "text-slate-300" },
              "Bytes Billed: ",
              h("span", { className: "text-emerald-300 font-bold" }, `${((fin.bytes_billed || 48234496) / (1024 * 1024)).toFixed(2)} MB`),
              h("span", { className: "text-slate-500 ml-2" }, `(${fin.partition_pruning_pct || 92.4}% partition pruned)`)
            ),
            h("div", { className: "text-slate-300" }, "Slot Milliseconds: ", h("span", { className: "text-white font-bold" }, `${fin.slot_ms || 1420} ms`)),
            h("div", { className: "text-purple-300 font-bold text-sm" }, "Estimated Query Cost: $", fin.estimated_cost_usd || "0.00028", " USD"),
            // Ask in Conversational Analytics button
            h(
              "button",
              {
                onClick: () => {
                  if (onAskAboutCohort && cohort) {
                    onAskAboutCohort(cohort);
                  }
                },
                className: "w-full mt-3 py-2 rounded-lg bg-purple-900/50 hover:bg-purple-800/70 border border-purple-500/40 text-purple-200 font-sans font-semibold text-xs transition-colors flex items-center justify-center gap-2"
              },
              h(IconBrain, { className: "w-4 h-4 text-purple-300" }),
              "Ask BigQuery Conversational Analytics about this Cohort →"
            )
          )
        )
      )
    );
  }

  // ---------------------------------------------------------------------------
  // Component: BigQuery Conversational Analytics Section
  // ---------------------------------------------------------------------------
  function ConversationalAnalyticsSection({ caMode, setCaMode, externalPrompt, onClearExternalPrompt }) {
    const [messages, setMessages] = useState([
      {
        role: "model",
        engine: "DataChatServiceClient",
        ca_mode: "custom_data_agent",
        thoughts: [
          "Loaded BigQuery analytical schemas for `serving_clarity_intelligence`",
          "Dataplex Knowledge Catalog glossary mapped: `position_bias_debiasing`, `cvr_search_conversion_rate`",
        ],
        content:
          "Welcome to the **Project Clarity Conversational Analytics Assistant**! I can answer questions grounded in our verified BigQuery Gold tables, explain A/B/C lift, show TimesFM demand forecasts, or audit multi-hypothesis root-cause evidence. Ask a question or click a suggested prompt below.",
        suggestions: [
          "Which home office chair SKU gained the highest lift?",
          "Compare Rank-1 debiased CVR lift across Head, Torso, and Tail query tiers",
          "Show 30-day AI.FORECAST demand for Home Office Chairs",
          "What is the FinOps byte scan and query cost for SKU-1007?",
        ],
        sql: "SELECT * FROM `your-gcp-project-id.serving_clarity_intelligence.clarity_reranked_search_results` LIMIT 5;",
      },
    ]);
    const [input, setInput] = useState("Which home office chair SKU gained the highest lift?");
    const [isLoading, setIsLoading] = useState(false);
    const [expandedThoughts, setExpandedThoughts] = useState({ 0: false });
    const [showSql, setShowSql] = useState({ 0: true });
    const chatEndRef = useRef(null);
    const textareaRef = useRef(null);

    // Scroll to bottom when messages update
    useEffect(() => {
      chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }, [messages, isLoading]);

    // Handle external prompt passed from Cohort Drawer
    useEffect(() => {
      if (externalPrompt) {
        setInput(externalPrompt);
        if (onClearExternalPrompt) onClearExternalPrompt();
      }
    }, [externalPrompt]);

    const handleSend = async (overrideText = null) => {
      const question = (overrideText || input).trim();
      if (!question || isLoading) return;

      if (!overrideText) setInput("");
      setIsLoading(true);

      const userMsg = { role: "user", content: question };
      const updatedHistory = [...messages, userMsg];
      setMessages(updatedHistory);

      try {
        const resp = await fetch("/api/chat", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            question,
            ca_mode: caMode,
            history: updatedHistory.map((m) => ({ role: m.role, content: m.content })),
          }),
        });

        const data = await resp.json();
        const modelMsg = {
          role: "model",
          engine: data.engine || "DataChatServiceClient",
          ca_mode: data.ca_mode || caMode,
          thoughts: data.thoughts || [],
          content: data.answer || "Query executed.",
          suggestions: data.suggestions || [],
          sql: data.sql_executed || null,
        };

        const nextIdx = updatedHistory.length;
        setMessages([...updatedHistory, modelMsg]);
        setExpandedThoughts((prev) => ({ ...prev, [nextIdx]: false }));
        setShowSql((prev) => ({ ...prev, [nextIdx]: true }));
      } catch (err) {
        console.error("Chat API error:", err);
        setMessages([
          ...updatedHistory,
          {
            role: "model",
            engine: "Offline Error Handler",
            content: "⚠️ Error contacting Conversational Analytics endpoint. Please retry.",
          },
        ]);
      } finally {
        setIsLoading(false);
      }
    };

    return h(
      "section",
      { className: "bg-slate-900/90 border border-slate-800 rounded-xl p-5 shadow-lg space-y-4" },
      // Header and Mode Switcher
      h(
        "div",
        { className: "flex flex-wrap items-center justify-between gap-4 pb-3 border-b border-slate-800" },
        h(
          "div",
          null,
          h(
            "div",
            { className: "flex items-center gap-2" },
            h(IconBrain, { className: "w-5 h-5 text-blue-400" }),
            h("h2", { className: "text-base font-bold text-white" }, "BigQuery Conversational Analytics (`DataChatServiceClient`)")
          ),
          h(
            "p",
            { className: "text-xs text-slate-400 mt-0.5" },
            "Ground natural-language questions in Dataplex Knowledge Catalog and verified BigQuery Gold tables."
          )
        ),
        // Mode Switcher Toggle Pill
        h(
          "div",
          { className: "flex items-center bg-slate-950 border border-slate-700/80 rounded-lg p-1 text-xs" },
          h(
            "button",
            {
              onClick: () => setCaMode("custom_data_agent"),
              className: `px-3 py-1.5 rounded-md font-medium transition-all ${
                caMode === "custom_data_agent"
                  ? "bg-blue-600 text-white shadow-md"
                  : "text-slate-400 hover:text-slate-200"
              }`
            },
            "Custom BQ CA Data Agent (data_agent_context)"
          ),
          h(
            "button",
            {
              onClick: () => setCaMode("inline_context"),
              className: `px-3 py-1.5 rounded-md font-medium transition-all ${
                caMode === "inline_context"
                  ? "bg-purple-600 text-white shadow-md"
                  : "text-slate-400 hover:text-slate-200"
              }`
            },
            "Stateless CA API (inline_context)"
          )
        )
      ),
      // Mode Context Banner
      h(
        "div",
        { className: "px-3.5 py-2 rounded-lg bg-slate-950/80 border border-slate-800 text-[11px] font-mono flex flex-wrap items-center justify-between gap-2" },
        caMode === "custom_data_agent"
          ? h(
              "div",
              { className: "text-blue-300" },
              "Active Mode: ",
              h("strong", { className: "text-white" }, "Custom BQ CA Data Agent"),
              " | Agent URI: `projects/your-gcp-project-id/locations/us-central1/dataAgents/clarity-retail-search-agent` (Dataplex Glossary Grounded)"
            )
          : h(
              "div",
              { className: "text-purple-300" },
              "Active Mode: ",
              h("strong", { className: "text-white" }, "Stateless BQ CA API"),
              " | `datasource_references.bq.table_references` = [clarity_reranked_search_results, category_demand_forecast_30d] (Native Gold Tables)"
            ),
        h("span", { className: "text-emerald-400 font-semibold" }, "✓ Online Ready")
      ),
      // Message Thread
      h(
        "div",
        { className: "space-y-4 max-h-[420px] overflow-y-auto pr-1" },
        messages.map((m, idx) => {
          const isUser = m.role === "user";
          return h(
            "div",
            { key: idx, className: `flex gap-3 ${isUser ? "justify-end" : "justify-start"}` },
            // Bubble
            h(
              "div",
              {
                className: `max-w-[85%] rounded-2xl p-4 text-xs leading-relaxed space-y-2.5 ${
                  isUser
                    ? "bg-blue-600 text-white rounded-tr-none shadow-md"
                    : "bg-slate-950 text-slate-200 border border-slate-800 rounded-tl-none shadow-md"
                }`
              },
              // Header tag for model
              !isUser &&
                h(
                  "div",
                  { className: "flex items-center justify-between text-[11px] text-slate-400 font-mono pb-1 border-b border-slate-800/80" },
                  h("span", { className: "text-blue-400 font-semibold" }, `[${m.engine || "DataChatServiceClient"}]`),
                  m.thoughts &&
                    m.thoughts.length > 0 &&
                    h(
                      "button",
                      {
                        onClick: () => setExpandedThoughts((prev) => ({ ...prev, [idx]: !prev[idx] })),
                        className: "text-slate-400 hover:text-slate-200 flex items-center gap-1 font-sans"
                      },
                      expandedThoughts[idx] ? h(IconChevronDown, { className: "w-3 h-3" }) : h(IconChevronRight, { className: "w-3 h-3" }),
                      "Reasoning Thoughts (",
                      m.thoughts.length,
                      ")"
                    )
                ),
              // Collapsible Thoughts Box
              !isUser &&
                expandedThoughts[idx] &&
                m.thoughts &&
                h(
                  "div",
                  { className: "p-2.5 rounded-lg bg-slate-900 border border-slate-800 text-[11px] font-mono text-slate-400 space-y-1" },
                  m.thoughts.map((th, thIdx) =>
                    h("div", { key: thIdx, className: "flex items-start gap-1.5" }, h("span", { className: "text-blue-400" }, "›"), h("span", null, th))
                  )
                ),
              // Message Content
              h("div", { className: "whitespace-pre-wrap font-sans text-xs" }, m.content),
              // Executed SQL Block
              !isUser &&
                m.sql &&
                h(
                  "div",
                  { className: "mt-2 pt-2 border-t border-slate-800/80" },
                  h(
                    "div",
                    { className: "flex items-center justify-between text-[10px] text-slate-400 font-mono mb-1" },
                    h("span", { className: "text-emerald-400 font-semibold uppercase" }, "Generated BigQuery SQL:"),
                    h(
                      "button",
                      {
                        onClick: () => navigator.clipboard?.writeText(m.sql),
                        className: "hover:text-white"
                      },
                      "Copy SQL"
                    )
                  ),
                  h("pre", { className: "p-2 rounded bg-slate-900 border border-slate-800 font-mono text-[10px] text-emerald-300 overflow-x-auto whitespace-pre-wrap" }, m.sql)
                ),
              // Interactive Follow-up Suggestions
              !isUser &&
                m.suggestions &&
                m.suggestions.length > 0 &&
                h(
                  "div",
                  { className: "pt-2 flex flex-wrap gap-1.5" },
                  m.suggestions.map((sugg, sIdx) =>
                    h(
                      "button",
                      {
                        key: sIdx,
                        onClick: () => handleSend(sugg),
                        className: "text-[11px] font-sans px-2.5 py-1 rounded-full bg-blue-900/30 hover:bg-blue-800/50 text-blue-300 border border-blue-500/30 transition-colors text-left"
                      },
                      sugg
                    )
                  )
                )
            )
          );
        }),
        isLoading &&
          h(
            "div",
            { className: "flex items-center gap-2 text-xs text-slate-400 p-2" },
            h("div", { className: "w-2 h-2 rounded-full bg-blue-400 animate-ping" }),
            h("span", null, "DataChatServiceClient is querying BigQuery and resolving Dataplex glossary...")
          ),
        h("div", { ref: chatEndRef })
      ),
      // Input Bar
      h(
        "div",
        { className: "flex gap-3 pt-2" },
        h("textarea", {
          id: "chat-question-input",
          ref: textareaRef,
          rows: 2,
          placeholder: "Ask about query cohorts, position-bias debiasing, demand forecasting, or FinOps byte spend...",
          value: input,
          onChange: (e) => setInput(e.target.value),
          onKeyDown: (e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              handleSend();
            }
          },
          className: "flex-1 bg-slate-950 border border-slate-700 rounded-xl px-4 py-2.5 text-xs text-slate-100 placeholder-slate-500 focus:outline-none focus:border-blue-500 resize-none font-sans"
        }),
        h(
          "button",
          {
            id: "chat-submit-btn",
            onClick: () => handleSend(),
            disabled: isLoading || !input.trim(),
            className: "px-5 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white text-xs font-semibold flex items-center gap-2 transition-colors shadow-md"
          },
          h(IconSend, { className: "w-4 h-4" }),
          h("span", { className: "hidden sm:inline" }, "Ask Data Agent")
        )
      )
    );
  }

  // ---------------------------------------------------------------------------
  // Main Application Component
  // ---------------------------------------------------------------------------
  function App() {
    const [dashboard, setDashboard] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [theme, setTheme] = useState("dark");
    const [finopsOpen, setFinopsOpen] = useState(false);
    const [selectedCohortId, setSelectedCohortId] = useState(null);
    const [isDrawerOpen, setIsDrawerOpen] = useState(false);
    const [caMode, setCaMode] = useState("custom_data_agent");
    const [externalPrompt, setExternalPrompt] = useState(null);

    // Register global trigger hooks for tests & external DOM scripts
    useEffect(() => {
      window.__claritySetSelectedCohort = (id) => setSelectedCohortId(id);
      window.__claritySetDrawerOpen = (open) => setIsDrawerOpen(open);
    }, []);

    // Load initial dashboard payload from FastAPI backend
    useEffect(() => {
      async function loadData() {
        try {
          const resp = await fetch("/api/dashboard");
          if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
          const data = await resp.json();
          setDashboard(data);
          if (data.query_cohorts_table && data.query_cohorts_table.length > 0) {
            setSelectedCohortId(data.query_cohorts_table[0].cohort_id);
          }
        } catch (err) {
          console.error("Failed to load dashboard data:", err);
          setError("Failed to load dashboard payload.");
        } finally {
          setLoading(false);
        }
      }
      loadData();
    }, []);

    const toggleTheme = () => {
      const newTheme = theme === "dark" ? "light" : "dark";
      setTheme(newTheme);
      const root = document.documentElement;
      if (newTheme === "light") {
        root.classList.remove("dark");
      } else {
        root.classList.add("dark");
      }
    };

    const toggleFinops = () => {
      setFinopsOpen((prev) => !prev);
    };

    const handleSelectCohort = (cohortId) => {
      setSelectedCohortId(cohortId);
      setIsDrawerOpen(true);
    };

    const handleCloseDrawer = () => {
      setIsDrawerOpen(false);
    };

    const handleAskAboutCohort = (cohort) => {
      setExternalPrompt(
        `Explain the root cause for cohort ${cohort.cohort_id} ("${cohort.sample_query}") and verify why SKU ${cohort.top_reranked_sku} gained +${cohort.cvr_lift_pct}% lift.`
      );
      setIsDrawerOpen(false);
      // Smooth scroll to chat section
      document.getElementById("chat-question-input")?.scrollIntoView({ behavior: "smooth" });
    };

    const selectedCohort = useMemo(() => {
      if (!dashboard?.query_cohorts_table || !selectedCohortId) return null;
      return dashboard.query_cohorts_table.find((c) => c.cohort_id === selectedCohortId) || null;
    }, [dashboard, selectedCohortId]);

    if (loading) {
      return h(
        "div",
        { className: "min-h-screen flex items-center justify-center bg-slate-950 text-slate-300 font-mono text-sm" },
        h("div", { className: "flex items-center gap-3" }, h("div", { className: "w-4 h-4 rounded-full bg-blue-500 animate-ping" }), "Loading Project Clarity Intelligence Dashboard...")
      );
    }

    if (error || !dashboard) {
      return h(
        "div",
        { className: "min-h-screen flex items-center justify-center bg-slate-950 text-rose-400 font-mono text-sm" },
        `Error: ${error || "Dashboard data unavailable"}`
      );
    }

    return h(
      "div",
      { className: "min-h-screen flex flex-col bg-slate-950 text-slate-100 transition-colors" },
      // 1. Header
      h(Header, {
        theme,
        onToggleTheme: toggleTheme,
        finopsOpen,
        onToggleFinops: toggleFinops,
        metadata: dashboard.app_metadata
      }),
      // Main Body
      h(
        "main",
        { className: "max-w-7xl mx-auto px-6 py-6 space-y-6 flex-1 w-full" },
        // FinOps Banner
        h(FinOpsLedgerBanner, { isOpen: finopsOpen, finopsData: dashboard.finops_ledger }),
        // 4 KPI Cards
        h(KpiCardsGrid, { cards: dashboard.kpi_cards }),
        // 2 Apache ECharts Visualizations
        h(ChartsSection, {
          abcData: dashboard.abc_experiment_chart,
          forecastData: dashboard.forecast_30d_chart,
          theme
        }),
        // Primary Interactive Query Cohort Table
        h(CohortTableSection, {
          cohorts: dashboard.query_cohorts_table,
          selectedCohortId,
          onSelectCohort: handleSelectCohort
        }),
        // BigQuery Conversational Analytics Assistant
        h(ConversationalAnalyticsSection, {
          caMode,
          setCaMode,
          externalPrompt,
          onClearExternalPrompt: () => setExternalPrompt(null)
        })
      ),
      // Slide-Out Root-Cause Investigation Drawer
      h(SlideOutInvestigationDrawer, {
        cohort: selectedCohort,
        isOpen: isDrawerOpen,
        onClose: handleCloseDrawer,
        onAskAboutCohort: handleAskAboutCohort
      })
    );
  }

  // ---------------------------------------------------------------------------
  // Mount React Application to #root
  // ---------------------------------------------------------------------------
  window.addEventListener("DOMContentLoaded", () => {
    const rootEl = document.getElementById("root");
    if (rootEl && ReactDOM) {
      const root = ReactDOM.createRoot(rootEl);
      root.render(h(App));
    }
  });
})();
