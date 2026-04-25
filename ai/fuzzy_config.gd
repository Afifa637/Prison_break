extends Resource
class_name FuzzyConfig

# ── Distance membership breakpoints ────────────────────────────────────────────
@export var dist_close:  float = 3.0   # NEAR_FULL  — fully "near" up to here
@export var dist_near_zero: float = 5.5  # NEAR_ZERO  — "near" drops to 0 here
@export var dist_medium_low:  float = 3.5
@export var dist_medium_peak: float = 6.5
@export var dist_medium_high: float = 10.0
@export var dist_far_zero: float = 6.25  # FAR_ZERO  — "far" starts rising here
@export var dist_far:    float = 11.0  # FAR_FULL  — fully "far" from here

# ── Alert level thresholds ─────────────────────────────────────────────────────
@export var alert_suspicious: float = 0.35  # ALERT_SUSPICIOUS_THRESHOLD
@export var alert_alarmed:    float = 0.50  # ALERT_ALARMED_THRESHOLD

# ── Behaviour score weights (applied as multipliers) ──────────────────────────
@export var w_chase:     float = 1.25
@export var w_investigate: float = 1.0
@export var w_intercept: float = 1.0
@export var w_patrol:    float = 1.0

# ── Alert-level influence on chase score ──────────────────────────────────────
# Added to chase_score as:  alert_level * alert_chase_weight
# Replaces the hard early-return bypasses (Critical #3 fix).
@export var alert_chase_weight:     float = 0.80
@export var alert_chase_base_bias:  float = 0.40

# ── Legacy visibility / noise / threat fields (kept for compatibility) ─────────
@export var vis_low: float    = 0.2
@export var vis_medium: float = 0.5
@export var vis_high: float   = 0.8

@export var noise_quiet:  float = 2.0
@export var noise_medium: float = 5.0
@export var noise_loud:   float = 8.0

@export var threat_low:    float = 2.0
@export var threat_medium: float = 5.0
@export var threat_high:   float = 8.0
