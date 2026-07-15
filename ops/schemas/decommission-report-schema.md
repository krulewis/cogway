---
schema: decommission-report
version: 1
decommission_approved: null | true | false
---

# Decommission Report — {Initiative Slug}

**initiative_id:** INI-{NNN}
**feature_id:** FEA-{NNN}
**date:** YYYY-MM-DD

---

## Kill Case

**Usage trend:** {declining / flat / never gained traction}
**Maintenance cost:** {high / medium / low — describe}
**Strategic alignment:** {no longer aligned / never aligned / deprioritised}
**Opportunity cost:** {what we could be building instead}

## Recommendation

**recommendation:** kill | defer | repurpose
**analyst_rationale:** {evidence-based reasoning}

---

## Human Gate 3/4

**decision_date:** YYYY-MM-DD
**decision_rationale:** {why}

---

## Cleanup Plan

*(Populated by decommission-executor after approval)*

**What to remove:**
- {item}

**Migration path:** {how existing users/dependents are handled}

**Comms required:** {who needs to be notified and how}
