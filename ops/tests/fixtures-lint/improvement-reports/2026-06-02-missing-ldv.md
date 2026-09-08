---
recommendation: stable
---

# Improvement Report — lint fixture: live_data_validation absent

Deliberately carries `recommendation` but NOT `live_data_validation`. The lint
must FAIL on it. Without this fixture the `live_data_validation` spec could be
deleted from the improvement-reports branch entirely and every assertion would
still pass — the positive fixture's OK line comes from the evidence-table block,
which does not depend on `specs`.
