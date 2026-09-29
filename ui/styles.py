"""
Central design system and CSS styling for Expensify.
Implements a mature, minimal, editorial design aesthetic inspired by high-end
independent productivity & financial tools (Inter typography, warm charcoal tones,
restrained forest green / sage accents, 6-8px border radius, no emojis, no glassmorphism).
"""

CUSTOM_CSS = """
<style>
/* Import Inter and IBM Plex Mono fonts */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500;600&display=swap');

/*
 * BASE TYPOGRAPHY
 * ───────────────
 * Scope Inter ONLY to known text-content containers.
 * NEVER use wildcard selectors like [class*="css"] or [class*="st-"]
 * because those match Streamlit's icon <span> elements and kill
 * the Material Symbols Rounded ligature rendering.
 */
.stApp,
.stApp [data-testid="stAppViewContainer"],
.stApp [data-testid="stSidebar"],
.stApp [data-testid="stHeader"],
.stApp [data-testid="stMarkdownContainer"],
.stApp [data-testid="stMarkdownContainer"] p,
.stApp [data-testid="stText"],
.stApp [data-testid="stCaptionContainer"],
.stApp h1, .stApp h2, .stApp h3, .stApp h4, .stApp h5, .stApp h6,
.stApp label,
.stApp [data-testid="stWidgetLabel"],
.stApp input,
.stApp textarea,
.stApp [data-baseweb="select"],
.stApp [data-baseweb="input"],
.stApp [data-testid="stForm"],
.stApp [data-testid="stRadio"],
.stApp [data-testid="stCheckbox"],
.stApp [data-testid="stNumberInput"],
.stApp [data-testid="stDateInput"],
.stApp [data-testid="stTimeInput"],
.stApp [data-testid="stMultiSelect"],
.stApp [data-testid="stTextArea"],
.stApp [data-testid="stTextInput"],
.stApp [data-testid="stSelectbox"],
.stApp [data-testid="stDataFrame"],
.stApp [data-testid="stAlert"],
.stApp [data-testid="stNotification"] {
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif !important;
    letter-spacing: -0.011em !important;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}

/*
 * MATERIAL ICON PROTECTION
 * ────────────────────────
 * Streamlit 1.64 renders icons in a TWO-LAYER structure:
 *   <span class="st-emotion-cache-XXXX e1ocqwht2">    ← WRAPPER (no testid, renders text in Inter = broken)
 *     <span data-testid="stIconMaterial" class="st-emotion-cache-YYYY e1vmumty0">
 *       expand_more                                    ← ligature text (correctly renders in Material Symbols)
 *     </span>
 *   </span>
 *
 * The wrapper span's text is the same as the inner span (via DOM text content inheritance).
 * Since the wrapper gets Inter (from our typography rules), it shows "expand_more" as raw text.
 * The inner span correctly uses Material Symbols Rounded and renders the glyph.
 *
 * SOLUTION: Hide the wrapper's own text rendering (font-size:0 + color:transparent),
 * then restore visibility on the inner data-testid span only.
 */

/* Icon wrapper spans: hide their own text rendering.
 * Matched by the stable styled-component target class "e1ocqwht2"
 * and by the :has() selector (CSS4, supported in all modern browsers). */
.e1ocqwht2,
span:has(> [data-testid="stIconMaterial"]) {
    font-size: 0px !important;
    color: transparent !important;
    overflow: hidden !important;
    line-height: 0 !important;
}

/* Inner icon span: restore visibility and correct font rendering */
[data-testid="stIconMaterial"] {
    font-family: 'Material Symbols Rounded' !important;
    font-weight: 400 !important;
    font-style: normal !important;
    font-size: 1.25rem !important;
    color: inherit !important;
    letter-spacing: normal !important;
    text-transform: none !important;
    display: inline-flex !important;
    align-items: center !important;
    justify-content: center !important;
    line-height: 1 !important;
    white-space: nowrap !important;
    word-wrap: normal !important;
    direction: ltr !important;
    -webkit-font-feature-settings: 'liga' !important;
    font-feature-settings: 'liga' !important;
    -webkit-font-smoothing: antialiased !important;
    text-rendering: optimizeLegibility !important;
    overflow: visible !important;
    visibility: visible !important;
}

/* Emoji icon span */
[data-testid="stIconEmoji"] {
    font-size: 1.25rem !important;
    color: inherit !important;
    visibility: visible !important;
}

/* Expander toggle icon wrapper (class e1a0jn2t3) */
.e1a0jn2t3 {
    font-size: 0px !important;
    color: transparent !important;
    overflow: hidden !important;
}
.e1a0jn2t3 [data-testid="stIconMaterial"] {
    font-family: 'Material Symbols Rounded' !important;
    font-size: 1.25rem !important;
    color: currentColor !important;
}


/* Monospace for financial figures, metrics, and dates */
.mono-num, .metric-value, .financial-figure, [data-testid="stMetricValue"] {
    font-family: 'IBM Plex Mono', monospace !important;
    letter-spacing: -0.02em !important;
}

/* Background Atmosphere - Restrained dark slate/charcoal, no neon glow */
.stApp {
    background-color: #0F110E !important;
    color: #EDEDE8 !important;
}

/* Main Container Spacing */
.block-container {
    padding-top: 2rem !important;
    padding-bottom: 4rem !important;
    max-width: 980px !important;
}

/* Typography Hierarchy */
.page-title {
    font-size: 1.75rem;
    font-weight: 700;
    color: #F4F4F0;
    letter-spacing: -0.025em;
    margin: 0 0 0.25rem 0;
}

.page-subtitle {
    font-size: 0.88rem;
    color: #8C8B82;
    margin: 0 0 1.75rem 0;
    line-height: 1.5;
    font-weight: 400;
}

.section-title {
    font-size: 1rem;
    font-weight: 600;
    color: #EDEDE8;
    letter-spacing: -0.015em;
    margin: 1.5rem 0 0.75rem 0;
}

.section-label {
    font-size: 0.72rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: #7A7970;
    margin-bottom: 0.5rem;
}

/* Clean Editorial Card / Surface - 6px radius, thin border, no glassmorphism */
.editorial-card {
    background-color: #161815;
    border: 1px solid #232521;
    border-radius: 8px;
    padding: 1.25rem 1.4rem;
    margin-bottom: 1rem;
}

.editorial-card-bordered {
    background-color: #141613;
    border: 1px solid #262924;
    border-radius: 8px;
    padding: 1rem 1.25rem;
    margin-bottom: 0.75rem;
}

/* Stat Blocks / Key Performance Metrics */
.stat-block {
    background-color: #151714;
    border: 1px solid #232521;
    border-radius: 8px;
    padding: 1.1rem 1.25rem;
    text-align: left;
}

.stat-label {
    font-size: 0.72rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #85847B;
    margin-bottom: 0.35rem;
}

.stat-value, .stat-number {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 1.6rem;
    font-weight: 600;
    color: #F4F4F0;
    letter-spacing: -0.02em;
    margin: 0;
    line-height: 1.2;
}

.stat-subtext {
    font-size: 0.76rem;
    color: #8C8B82;
    margin-top: 0.35rem;
}

.stat-subtext-positive {
    font-size: 0.76rem;
    color: #4E8A68;
    font-weight: 500;
    margin-top: 0.35rem;
}

.stat-subtext-alert {
    font-size: 0.76rem;
    color: #C27060;
    font-weight: 500;
    margin-top: 0.35rem;
}

/* Sidebar Navigation - Understated, minimal text list */
[data-testid="stSidebar"] {
    background-color: #121411 !important;
    border-right: 1px solid #1F221D !important;
}

.sidebar-header {
    padding: 2.2rem 0.25rem 1.25rem 0.25rem; /* Generous top padding prevents sidebar collapse button collision */
    border-bottom: 1px solid #1F221D;
    margin-bottom: 1rem;
    position: relative;
}

.sidebar-app-name {
    font-size: 1.05rem;
    font-weight: 700;
    color: #F1F0EA;
    letter-spacing: -0.02em;
    margin: 0;
}

.sidebar-app-desc {
    font-size: 0.74rem;
    color: #7A7970;
    margin: 2px 0 0 0;
}

[data-testid="stSidebarCollapseButton"] {
    top: 0.75rem !important;
    color: #85847B !important;
    background: transparent !important;
    border: none !important;
    z-index: 100 !important;
}

[data-testid="stSidebarCollapseButton"]:hover {
    color: #EDEDE8 !important;
}

/* Radio Navigation Styling */
[data-testid="stSidebar"] [data-testid="stRadio"] div[role="radiogroup"] > label {
    background: transparent !important;
    border: none !important;
    border-radius: 6px !important;
    padding: 6px 10px !important;
    margin-bottom: 2px !important;
    color: #9C9B91 !important;
    font-size: 0.86rem !important;
    font-weight: 500 !important;
    transition: all 0.15s ease !important;
}

[data-testid="stSidebar"] [data-testid="stRadio"] div[role="radiogroup"] > label:hover {
    background: #191B17 !important;
    color: #EDEDE8 !important;
}

[data-testid="stSidebar"] [data-testid="stRadio"] div[role="radiogroup"] > label[data-checked="true"] {
    background: #1C201A !important;
    color: #E2EFE7 !important;
    font-weight: 600 !important;
    border-left: 2px solid #3E6B56 !important;
    border-radius: 0 6px 6px 0 !important;
}

/* Form Container Styling */
div[data-testid="stForm"] {
    background-color: #151714 !important;
    border: 1px solid #232521 !important;
    border-radius: 8px !important;
    padding: 1.5rem !important;
    box-shadow: none !important;
}

/* Expander Header & Container Layout */
div[data-testid="stExpander"] {
    background-color: #151714 !important;
    border: 1px solid #232521 !important;
    border-radius: 8px !important;
    margin-bottom: 0.75rem !important;
    overflow: hidden !important;
}

div[data-testid="stExpander"] details {
    border: none !important;
    background: transparent !important;
}

div[data-testid="stExpander"] details summary {
    display: flex !important;
    align-items: center !important;
    justify-content: space-between !important;
    padding: 0.75rem 1rem !important;
    cursor: pointer !important;
    background-color: #151714 !important;
    color: #EDEDE8 !important;
    border-radius: 8px !important;
    gap: 0.75rem !important;
    width: 100% !important;
    box-sizing: border-box !important;
}

div[data-testid="stExpander"] details summary:hover {
    background-color: #1A1D18 !important;
    color: #FFFFFF !important;
}

div[data-testid="stExpander"] details summary div[data-testid="stMarkdownContainer"] {
    flex: 1 1 auto !important;
    overflow: hidden !important;
    text-overflow: ellipsis !important;
    white-space: nowrap !important;
    min-width: 0 !important;
    text-align: left !important;
}

div[data-testid="stExpander"] details summary div[data-testid="stMarkdownContainer"] > p {
    margin: 0 !important;
    overflow: hidden !important;
    text-overflow: ellipsis !important;
    white-space: nowrap !important;
    font-weight: 500 !important;
    font-size: 0.88rem !important;
    color: #EDEDE8 !important;
}

div[data-testid="stExpander"] details summary [data-testid="stExpanderToggleIcon"] {
    flex: 0 0 auto !important;
    display: inline-flex !important;
    align-items: center !important;
    justify-content: center !important;
    margin-left: auto !important;
}

/* Buttons and Popovers - Robust flex alignment, boundaries & truncation */
button[data-testid*="stBaseButton"],
button[kind="primary"],
button[kind="secondary"],
div[data-testid="stPopover"] > button,
div[data-testid="stPopoverButton"] > button {
    display: inline-flex !important;
    align-items: center !important;
    justify-content: space-between !important;
    gap: 0.5rem !important;
    padding: 0.45rem 0.9rem !important;
    border-radius: 6px !important;
    font-weight: 500 !important;
    font-size: 0.88rem !important;
    box-sizing: border-box !important;
    max-width: 100% !important;
    min-height: 2.45rem !important;
    transition: all 0.15s ease !important;
}

/* Label text wrapper truncation inside buttons & popovers */
button[data-testid*="stBaseButton"] div[data-testid="stMarkdownContainer"],
div[data-testid="stPopover"] > button div[data-testid="stMarkdownContainer"],
div[data-testid="stPopoverButton"] > button div[data-testid="stMarkdownContainer"] {
    flex: 1 1 auto !important;
    overflow: hidden !important;
    text-overflow: ellipsis !important;
    white-space: nowrap !important;
    min-width: 0 !important;
    text-align: left !important;
}

button[data-testid*="stBaseButton"] div[data-testid="stMarkdownContainer"] > p,
div[data-testid="stPopover"] > button div[data-testid="stMarkdownContainer"] > p,
div[data-testid="stPopoverButton"] > button div[data-testid="stMarkdownContainer"] > p {
    margin: 0 !important;
    overflow: hidden !important;
    text-overflow: ellipsis !important;
    white-space: nowrap !important;
    line-height: normal !important;
}

/* Icon separation in buttons and popovers */
button [data-testid="stIconMaterial"],
div[data-testid="stPopover"] > button [data-testid="stIconMaterial"],
div[data-testid="stPopoverButton"] > button [data-testid="stIconMaterial"] {
    flex: 0 0 auto !important;
    margin-left: 0.25rem !important;
    font-size: 1.15rem !important;
}

/* Primary buttons */
button[kind="primary"], div[data-testid="stForm"] button[kind="primary"] {
    background-color: #315843 !important;
    color: #FFFFFF !important;
    border: 1px solid #3E6B56 !important;
    box-shadow: none !important;
}

button[kind="primary"]:hover, div[data-testid="stForm"] button[kind="primary"]:hover {
    background-color: #3A694F !important;
    border-color: #4B7F64 !important;
    transform: none !important;
    box-shadow: none !important;
}

/* Secondary buttons */
button[kind="secondary"],
div[data-testid="stPopover"] > button,
div[data-testid="stPopoverButton"] > button {
    background-color: transparent !important;
    color: #C5C4BA !important;
    border: 1px solid #2B2E28 !important;
}

button[kind="secondary"]:hover,
div[data-testid="stPopover"] > button:hover,
div[data-testid="stPopoverButton"] > button:hover {
    background-color: #1C1F1A !important;
    border-color: #383C34 !important;
    color: #EDEDE8 !important;
}

/* Inputs, Textareas, Selectboxes */
div[data-baseweb="input"] > div,
div[data-baseweb="select"] > div,
textarea {
    background-color: #121411 !important;
    border: 1px solid #282C25 !important;
    border-radius: 6px !important;
    color: #EDEDE8 !important;
    font-size: 0.9rem !important;
}

/* Toolbar Alignment: match exact heights of search, selectbox, and popovers */
div[data-testid="stTextInput"] div[data-baseweb="input"] > div,
div[data-testid="stSelectbox"] div[data-baseweb="select"] > div,
div[data-testid="stPopover"] > button,
div[data-testid="stPopoverButton"] > button {
    min-height: 2.45rem !important;
    height: 2.45rem !important;
    box-sizing: border-box !important;
}

div[data-baseweb="input"] > div:focus-within,
div[data-baseweb="select"] > div:focus-within,
textarea:focus {
    border-color: #4A7A60 !important;
    box-shadow: 0 0 0 1px #4A7A60 !important;
}

/* Prominent Amount Entry Field */
.amount-hero-box {
    background-color: #121411;
    border: 1px solid #292D26;
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 1.25rem;
    text-align: center;
}

.amount-hero-label {
    font-size: 0.72rem;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: #7A7970;
    font-weight: 600;
    margin-bottom: 0.25rem;
}

/* Tabs Styling - Clean underline tabs */
[data-testid="stTabs"] [role="tablist"] {
    gap: 1.5rem;
    border-bottom: 1px solid #232521;
    margin-bottom: 1.25rem;
}

[data-testid="stTabs"] [role="tab"] {
    background: transparent !important;
    border: none !important;
    padding: 0.5rem 0.25rem !important;
    font-weight: 500 !important;
    font-size: 0.88rem !important;
    color: #85847B !important;
    border-bottom: 2px solid transparent !important;
    border-radius: 0 !important;
}

[data-testid="stTabs"] [role="tab"]:hover {
    color: #D4D3CB !important;
}

[data-testid="stTabs"] [role="tab"][aria-selected="true"] {
    color: #EDEDE8 !important;
    font-weight: 600 !important;
    border-bottom: 2px solid #3E6B56 !important;
}

/* Category & Semantic Badges - Subtle, text-first, non-pill */
.subtle-tag {
    display: inline-block;
    padding: 2px 7px;
    border-radius: 4px;
    font-size: 0.72rem;
    font-weight: 500;
    background-color: #1C201A;
    color: #A3C9B3;
    border: 1px solid #28332A;
}

.subtle-tag-neutral {
    display: inline-block;
    padding: 2px 7px;
    border-radius: 4px;
    font-size: 0.72rem;
    font-weight: 500;
    background-color: #191B18;
    color: #9C9B91;
    border: 1px solid #262924;
}

.subtle-tag-warn {
    display: inline-block;
    padding: 2px 7px;
    border-radius: 4px;
    font-size: 0.72rem;
    font-weight: 500;
    background-color: #211B14;
    color: #D4A373;
    border: 1px solid #3D3020;
}

.subtle-tag-alert {
    display: inline-block;
    padding: 2px 7px;
    border-radius: 4px;
    font-size: 0.72rem;
    font-weight: 500;
    background-color: #241716;
    color: #D98880;
    border: 1px solid #452624;
}

/* Clean Tables / List Rows */
.data-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem 0.5rem;
    border-bottom: 1px solid #1D201A;
    font-size: 0.88rem;
}

.data-row:last-child {
    border-bottom: none;
}

.data-row-store {
    font-weight: 500;
    color: #EDEDE8;
}

.data-row-category {
    font-size: 0.78rem;
    color: #7D7C74;
    margin-top: 1px;
}

.data-row-amount {
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 600;
    color: #F1F0EA;
    font-size: 0.95rem;
    text-align: right;
}

.data-row-date {
    font-size: 0.75rem;
    color: #7A7970;
    text-align: right;
    margin-top: 1px;
}

/* Quick Add Shortcut List */
.quick-add-item {
    background-color: #141613;
    border: 1px solid #222520;
    border-radius: 6px;
    padding: 0.75rem 1rem;
    margin-bottom: 0.5rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.quick-add-name {
    font-weight: 500;
    font-size: 0.88rem;
    color: #EDEDE8;
}

.quick-add-meta {
    font-size: 0.76rem;
    color: #7A7970;
    margin-top: 1px;
}

.quick-add-amount {
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 600;
    font-size: 0.95rem;
    color: #E2EFE7;
    margin-right: 0.75rem;
}

/* Callout / Notice Block */
.notice-block {
    background-color: #151814;
    border-left: 2px solid #3E6B56;
    padding: 0.75rem 1rem;
    border-radius: 0 6px 6px 0;
    font-size: 0.84rem;
    color: #B5B4AB;
    margin-bottom: 1rem;
    line-height: 1.5;
}

.notice-block-warn {
    background-color: #1B1812;
    border-left: 2px solid #A87A42;
    padding: 0.75rem 1rem;
    border-radius: 0 6px 6px 0;
    font-size: 0.84rem;
    color: #C7B59D;
    margin-bottom: 1rem;
    line-height: 1.5;
}

/* Empty States - Restrained, clean, editorial */
.empty-state {
    padding: 2.5rem 1.5rem;
    text-align: center;
    border: 1px dashed #262924;
    border-radius: 8px;
    background-color: #121411;
    margin: 1.5rem 0;
}

.empty-state-title {
    font-size: 0.95rem;
    font-weight: 600;
    color: #EDEDE8;
    margin-bottom: 0.35rem;
}

.empty-state-desc {
    font-size: 0.82rem;
    color: #8C8B82;
    max-width: 420px;
    margin: 0 auto;
    line-height: 1.5;
}

/* Clean Dividers */
hr {
    border: none !important;
    border-top: 1px solid #1F221D !important;
    margin: 1.5rem 0 !important;
}

/* Mobile Responsiveness */
@media (max-width: 768px) {
    .block-container {
        padding-top: 1rem !important;
        padding-left: 1rem !important;
        padding-right: 1rem !important;
    }
    .page-title {
        font-size: 1.4rem !important;
    }
    .stat-value, .stat-number {
        font-size: 1.3rem !important;
    }
    .editorial-card {
        padding: 1rem !important;
    }
}
</style>

"""
