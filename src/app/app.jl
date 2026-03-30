"""CSS for the application — supports light and dark themes via data-theme attribute."""
const GLOBAL_CSS = """
/* ── Reset & Base ── */
* { box-sizing: border-box; margin: 0; padding: 0; }

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif !important;
    -webkit-font-smoothing: antialiased;
    background: var(--bg) !important;
    color: var(--text) !important;
}

/* ── Sidebar button overrides ── */
.ov-sidebar-nav button {
    all: unset !important;
    display: block !important;
    width: 100% !important;
    padding: 0 !important;
    margin: 0 !important;
    font-family: inherit !important;
    font-size: 14px !important;
    color: inherit !important;
    cursor: pointer !important;
    background: none !important;
    border: none !important;
    box-shadow: none !important;
    text-align: left !important;
}

/* ── Light Theme (default on :root) ── */
:root {
    --bg: #f8fafc;
    --bg-card: #ffffff;
    --bg-sidebar: #1e293b;
    --bg-input: #f1f5f9;
    --border: #e2e8f0;
    --border-input: #cbd5e1;
    --text: #1e293b;
    --text-muted: #64748b;
    --text-sidebar: #cbd5e1;
    --text-sidebar-active: #ffffff;
    --shadow: 0 1px 3px rgba(0,0,0,0.08);
}

/* ── Dark Theme (toggled via .ov-dark class) ── */
.ov-dark {
    --bg: #0f172a;
    --bg-card: #1e293b;
    --bg-sidebar: #0f172a;
    --bg-input: #1e293b;
    --border: #334155;
    --border-input: #475569;
    --text: #f1f5f9;
    --text-muted: #94a3b8;
    --text-sidebar: #94a3b8;
    --text-sidebar-active: #ffffff;
    --shadow: 0 1px 3px rgba(0,0,0,0.3);
}

/* ── Layout ── */
.ov-layout {
    display: flex;
    min-height: 100vh;
    background: var(--bg);
    color: var(--text);
}

.ov-main {
    flex: 1;
    padding: 24px;
    max-width: 1400px;
    overflow-y: auto;
}

/* ── Cards ── */
.ov-card {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 20px;
    box-shadow: var(--shadow);
    margin-bottom: 16px;
}

/* ── Sidebar ── */
.ov-sidebar {
    width: 220px;
    background: var(--bg-sidebar);
    padding: 20px 0;
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--border);
    min-height: 100vh;
}

.ov-sidebar-title {
    color: white;
    font-size: 18px;
    font-weight: 700;
    padding: 0 20px 20px;
    border-bottom: 1px solid rgba(255,255,255,0.1);
    margin-bottom: 8px;
}

.ov-nav-item {
    display: block;
    width: 100%;
    padding: 10px 20px;
    color: var(--text-sidebar);
    background: transparent;
    border: none;
    text-align: left;
    font-size: 14px;
    cursor: pointer;
    transition: all 0.15s;
    border-left: 3px solid transparent;
}

.ov-nav-item:hover {
    color: var(--text-sidebar-active);
    background: rgba(255,255,255,0.05);
}

.ov-nav-item.active {
    color: var(--text-sidebar-active);
    background: rgba(37,99,235,0.15);
    border-left-color: #2563eb;
    font-weight: 600;
}

/* ── Header ── */
.ov-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 24px;
    padding-bottom: 16px;
    border-bottom: 1px solid var(--border);
}

.ov-header h1 {
    font-size: 24px;
    font-weight: 700;
}

.ov-status-dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    margin-right: 6px;
}

/* ── Charger Cards Grid ── */
.ov-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 16px;
    margin-bottom: 24px;
}

.ov-charger-card {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 20px;
    cursor: pointer;
    transition: all 0.15s;
    box-shadow: var(--shadow);
}

.ov-charger-card:hover {
    border-color: #2563eb;
    box-shadow: 0 0 0 1px #2563eb;
}

/* ── Status Badges ── */
.ov-badge {
    display: inline-flex;
    align-items: center;
    padding: 2px 10px;
    border-radius: 12px;
    font-size: 12px;
    font-weight: 600;
}

.ov-badge-available { background: #dcfce7; color: #166534; }
.ov-badge-charging { background: #dbeafe; color: #1e40af; }
.ov-badge-suspended { background: #fef3c7; color: #92400e; }
.ov-badge-faulted { background: #fee2e2; color: #991b1b; }
.ov-badge-unavailable { background: #f1f5f9; color: #64748b; }
.ov-badge-active { background: #dcfce7; color: #166534; }
.ov-badge-completed { background: #f1f5f9; color: #64748b; }

.ov-dark .ov-badge-available { background: #166534; color: #dcfce7; }
.ov-dark .ov-badge-charging { background: #1e40af; color: #dbeafe; }
.ov-dark .ov-badge-suspended { background: #92400e; color: #fef3c7; }
.ov-dark .ov-badge-faulted { background: #991b1b; color: #fee2e2; }
.ov-dark .ov-badge-unavailable { background: #334155; color: #94a3b8; }
.ov-dark .ov-badge-active { background: #166534; color: #dcfce7; }
.ov-dark .ov-badge-completed { background: #334155; color: #94a3b8; }

/* ── Metric Display ── */
.ov-metric-large {
    font-size: 36px;
    font-weight: 700;
    line-height: 1;
}

.ov-metric-unit {
    font-size: 16px;
    font-weight: 400;
    color: var(--text-muted);
    margin-left: 4px;
}

.ov-metric-row {
    display: flex;
    gap: 16px;
    margin: 12px 0;
    color: var(--text-muted);
    font-size: 14px;
}

.ov-metric-item {
    display: flex;
    flex-direction: column;
    align-items: center;
}

.ov-metric-value { font-weight: 600; color: var(--text); font-size: 16px; }
.ov-metric-label { font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; }

/* ── Buttons ── */
button, .ov-btn {
    padding: 8px 16px !important;
    border-radius: 8px !important;
    border: 1px solid var(--border) !important;
    font-size: 13px !important;
    font-weight: 600 !important;
    cursor: pointer !important;
    transition: all 0.15s !important;
    background: var(--bg-card) !important;
    color: var(--text) !important;
}

.ov-btn-primary {
    background: #2563eb !important;
    color: white !important;
    border-color: #2563eb !important;
}

.ov-btn-primary:hover { background: #1d4ed8 !important; }

.ov-btn-danger {
    background: #ef4444 !important;
    color: white !important;
    border-color: #ef4444 !important;
}

/* ── Inputs ── */
input, select, textarea {
    padding: 8px 12px !important;
    border: 1px solid var(--border-input) !important;
    border-radius: 8px !important;
    background: var(--bg-input) !important;
    color: var(--text) !important;
    font-size: 14px !important;
    width: 100% !important;
}

input:focus, select:focus, textarea:focus {
    outline: none !important;
    border-color: #2563eb !important;
    box-shadow: 0 0 0 2px rgba(37,99,235,0.2) !important;
}

/* ── Tables ── */
.ov-table {
    width: 100%;
    border-collapse: collapse;
}

.ov-table th {
    text-align: left;
    padding: 8px 12px;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--text-muted);
    border-bottom: 1px solid var(--border);
}

.ov-table td {
    padding: 10px 12px;
    font-size: 14px;
    border-bottom: 1px solid var(--border);
}

/* ── Logs ── */
.ov-log-area {
    background: #0f172a;
    color: #e2e8f0;
    font-family: 'JetBrains Mono', 'Fira Code', 'Consolas', monospace;
    font-size: 12px;
    padding: 16px;
    border-radius: 8px;
    max-height: 500px;
    overflow-y: auto;
    line-height: 1.6;
}

/* ── Summary Stats ── */
.ov-stats-row {
    display: flex;
    gap: 16px;
    margin-bottom: 24px;
}

.ov-stat-card {
    flex: 1;
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 16px;
    text-align: center;
    box-shadow: var(--shadow);
}

.ov-stat-value { font-size: 24px; font-weight: 700; }
.ov-stat-label { font-size: 12px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; margin-top: 4px; }

/* ── Phase bars ── */
.ov-phase-row {
    display: flex;
    gap: 8px;
    font-size: 12px;
    color: var(--text-muted);
    margin-top: 8px;
}

/* ── Two column grid ── */
.ov-two-col {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
}

/* ── Theme toggle ── */
.ov-theme-toggle {
    background: var(--bg-input) !important;
    border: 1px solid var(--border) !important;
    padding: 6px 12px !important;
    border-radius: 8px !important;
    cursor: pointer !important;
    font-size: 14px !important;
}

/* ── Collapsible sections ── */
.ov-section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 0;
    cursor: pointer;
    font-weight: 600;
    font-size: 16px;
    border-bottom: 1px solid var(--border);
}

/* ── Back button ── */
.ov-back-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    color: #2563eb;
    cursor: pointer;
    font-size: 14px;
    font-weight: 600;
    margin-bottom: 16px;
    background: none !important;
    border: none !important;
    padding: 0 !important;
}

.ov-back-btn:hover { text-decoration: underline; }
"""

"""
    create_app(app_state::AppState) → Bonito.App

Create the main Bonito application with sidebar navigation and page routing.
"""
function create_app(app_state::AppState)
    return App(; title = "OCPPVictron") do
        sidebar = build_sidebar(app_state)
        header = build_header(app_state)

        page_content = map(app_state.active_page) do page
            if page == :dashboard
                build_dashboard(app_state)
            elseif page == :config
                build_config_page(app_state)
            elseif page == :logs
                build_logs_page(app_state)
            elseif page == :sessions
                build_sessions_page(app_state)
            else
                DOM.div("Unknown page: $page")
            end
        end

        # Use plain DOM.div for the shell layout to avoid Bonito's
        # Grid/Col height:100% defaults that cause stretching
        main_area = DOM.div(
            header,
            page_content;
            style = "flex:1;padding:24px;overflow-y:auto;height:100vh;",
        )

        layout = DOM.div(
            sidebar,
            main_area;
            style = "display:flex;min-height:100vh;background:var(--bg);color:var(--text);",
        )

        theme_class = map(app_state.theme) do t
            t == :dark ? "ov-dark" : ""
        end

        DOM.div(DOM.style(GLOBAL_CSS), layout; class = theme_class)
    end
end
