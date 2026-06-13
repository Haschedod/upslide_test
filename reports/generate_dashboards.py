"""Generate PowerPoint-ready chart images for the Q1 2026 sales review.

Reads directly from the dbt marts in sales_tracking/dev.duckdb so the figures
always reflect the current pipeline output. Outputs high-resolution PNGs
(1920x1080, 16:9) into reports/figures/.

"""

from __future__ import annotations

from pathlib import Path

import duckdb
import matplotlib

matplotlib.use("Agg")  # no display needed
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter

QUARTER = "2026Q1"

REPO_ROOT = Path(__file__).resolve().parent.parent
DB_PATH = REPO_ROOT / "sales_tracking" / "dev.duckdb"
FIG_DIR = Path(__file__).resolve().parent / "figures"

# 16:9 at 150 dpi -> 1920x1080, crisp on a slide
FIGSIZE = (12.8, 7.2)
DPI = 150

COLOR_MET = "#2e7d32"
COLOR_MISS = "#c62828"
COLOR_NEW_BIZ = "#1f6feb"
COLOR_UPSELL = "#f0883e"
COLOR_NEUTRAL = "#6e7681"
COLOR_TARGET = "#24292f"

plt.rcParams.update(
    {
        "figure.figsize": FIGSIZE,
        "figure.dpi": DPI,
        "font.size": 14,
        "axes.titlesize": 20,
        "axes.titleweight": "bold",
        "axes.labelsize": 14,
        "axes.spines.top": False,
        "axes.spines.right": False,
        "axes.grid": True,
        "grid.alpha": 0.25,
        "grid.linestyle": "--",
    }
)


def query(con: duckdb.DuckDBPyConnection, sql: str):
    return con.execute(sql).df()


def _euro(x, _pos=None) -> str:
    return f"{x/1000:,.0f}k"


def _save(fig, name: str) -> Path:
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    path = FIG_DIR / name
    fig.text(
        0.01,
        0.01,
        f"Source: dbt marts (sales_tracking/dev.duckdb) - {QUARTER}",
        fontsize=9,
        color=COLOR_NEUTRAL,
    )
    fig.savefig(path, dpi=DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  wrote {path.relative_to(REPO_ROOT)}")
    return path


def chart_office_attainment(con) -> None:
    df = query(
        con,
        """
        select account_office, attainment_pct, is_target_met
        from mart_office_performance
        order by attainment_pct
        """,
    )
    colors = [COLOR_MET if m else COLOR_MISS for m in df["is_target_met"]]
    fig, ax = plt.subplots()
    bars = ax.bar(df["account_office"], df["attainment_pct"], color=colors)
    ax.axhline(100, color=COLOR_TARGET, linestyle="--", linewidth=1.5)
    ax.text(len(df) - 0.4, 105, "Target (100%)", color=COLOR_TARGET, fontsize=11)
    ax.bar_label(bars, fmt="%.0f%%", padding=3, fontsize=13, fontweight="bold")
    ax.set_title("Q1 2026 target attainment by office")
    ax.set_ylabel("Attainment (% of new ARR target)")
    ax.set_ylim(0, max(df["attainment_pct"]) * 1.15)
    fig.tight_layout()
    _save(fig, "fig_01_office_attainment.png")


def chart_office_arr_breakdown(con) -> None:
    df = query(
        con,
        """
        select account_office, quarter_target, won_arr_new_business, won_arr_upsell
        from mart_office_performance
        order by quarter_target desc
        """,
    )
    fig, ax = plt.subplots()
    x = range(len(df))
    nb = ax.bar(x, df["won_arr_new_business"], color=COLOR_NEW_BIZ, label="New business ARR")
    up = ax.bar(
        x,
        df["won_arr_upsell"],
        bottom=df["won_arr_new_business"],
        color=COLOR_UPSELL,
        label="Upsell ARR",
    )
    # target markers
    for i, t in enumerate(df["quarter_target"]):
        ax.hlines(t, i - 0.4, i + 0.4, color=COLOR_TARGET, linewidth=2.5)
    ax.plot([], [], color=COLOR_TARGET, linewidth=2.5, label="Quarter target")
    ax.set_xticks(list(x))
    ax.set_xticklabels(df["account_office"])
    ax.yaxis.set_major_formatter(FuncFormatter(_euro))
    ax.set_title("Q1 2026 won ARR vs target by office (new business + upsell)")
    ax.set_ylabel("ARR")
    ax.legend(loc="upper left")
    fig.tight_layout()
    _save(fig, "fig_02_office_arr_breakdown.png")


def chart_salesperson_attainment(con) -> None:
    df = query(
        con,
        f"""
        select d.salesperson_name || ' (' || t.account_office || ')' as label,
               t.attainment_pct,
               t.is_target_met
        from fct_target_attainment t
        left join dim_salespeople d using (salesperson_id)
        where t.target_quarter = '{QUARTER}'
        order by t.attainment_pct
        """,
    )
    colors = [COLOR_MET if m else COLOR_MISS for m in df["is_target_met"]]
    fig, ax = plt.subplots()
    bars = ax.barh(df["label"], df["attainment_pct"], color=colors)
    ax.axvline(100, color=COLOR_TARGET, linestyle="--", linewidth=1.5)
    ax.bar_label(bars, fmt="%.0f%%", padding=3, fontsize=12)
    ax.set_title("Q1 2026 target attainment by salesperson")
    ax.set_xlabel("Attainment (% of new ARR target)")
    # legend proxy
    ax.bar(0, 0, color=COLOR_MET, label="Target met")
    ax.bar(0, 0, color=COLOR_MISS, label="Target missed")
    ax.legend(loc="lower right")
    fig.tight_layout()
    _save(fig, "fig_03_salesperson_attainment.png")


def chart_drivers(con) -> None:
    df = query(
        con,
        f"""
        select d.salesperson_name as name,
               count(*) filter (where is_closed) as closed_deals,
               round(100.0 * count(*) filter (where is_won)
                     / nullif(count(*) filter (where is_closed), 0), 1) as win_rate_pct,
               round(avg(arr) filter (where is_won), 0) as avg_won_deal_size
        from fct_opportunities f
        left join dim_salespeople d using (salesperson_id)
        where f.closed_quarter = '{QUARTER}' and f.is_valid_account
        group by 1
        order by win_rate_pct
        """,
    )
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=FIGSIZE)
    b1 = ax1.barh(df["name"], df["win_rate_pct"], color=COLOR_NEUTRAL)
    ax1.bar_label(b1, fmt="%.0f%%", padding=3, fontsize=11)
    ax1.set_title("Win rate by salesperson")
    ax1.set_xlabel("Won / closed deals (%)")

    b2 = ax2.barh(df["name"], df["avg_won_deal_size"].fillna(0), color=COLOR_NEW_BIZ)
    ax2.bar_label(b2, fmt=lambda v: f"{v/1000:,.0f}k" if v else "-", padding=3, fontsize=11)
    ax2.set_title("Average won deal size")
    ax2.set_xlabel("ARR per won deal")
    ax2.xaxis.set_major_formatter(FuncFormatter(_euro))

    fig.suptitle("Q1 2026 performance drivers by salesperson", fontsize=20, fontweight="bold")
    fig.tight_layout(rect=(0, 0, 1, 0.96))
    _save(fig, "fig_04_drivers.png")


def chart_sp009_pipeline(con) -> None:
    df = query(
        con,
        f"""
        select status, count(*) as opportunities
        from fct_opportunities
        where salesperson_id = 'SP009'
          and (created_quarter = '{QUARTER}' or closed_quarter = '{QUARTER}')
        group by 1
        """,
    )
    order = ["created", "qualified", "won", "lost"]
    df["status"] = df["status"].astype("category")
    df = df.set_index("status").reindex(order).fillna(0).reset_index()
    colors = [
        COLOR_NEUTRAL,
        COLOR_NEW_BIZ,
        COLOR_MET,
        COLOR_MISS,
    ]
    fig, ax = plt.subplots()
    bars = ax.bar(df["status"], df["opportunities"], color=colors)
    ax.bar_label(bars, fmt="%.0f", padding=3, fontsize=14, fontweight="bold")
    ax.set_title("SP009 (Germany): Q1 2026 pipeline by status - healthy pipeline, nothing won")
    ax.set_ylabel("Number of opportunities")
    fig.tight_layout()
    _save(fig, "fig_05_sp009_pipeline.png")


def main() -> None:
    if not DB_PATH.exists():
        raise SystemExit(
            f"Database not found at {DB_PATH}. Run `dbt build` in sales_tracking/ first."
        )
    print(f"Reading from {DB_PATH}")
    con = duckdb.connect(str(DB_PATH), read_only=True)
    try:
        chart_office_attainment(con)
        chart_office_arr_breakdown(con)
        chart_salesperson_attainment(con)
        chart_drivers(con)
        chart_sp009_pipeline(con)
    finally:
        con.close()
    print(f"Done. Figures in {FIG_DIR.relative_to(REPO_ROOT)}/")


if __name__ == "__main__":
    main()
