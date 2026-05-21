# Aura Defect Patterns

Reusable patterns extracted from Aura defect fixes.

---

## Pattern 1: Normalize Plan Units To Report UOM Before Comparing Plan vs Actual

**Related defects:** 1737343
**Related changesets:** 240567, 240571, 240578, 240594, 240602, 240613

### Context

The Plan vs Actual report was fragile because plan values and actual values were compared in whatever unit happened to be present on the source records. The fix normalized planned mass and volume into the report UOM first, skipped rows with no target and no actuals, and merged repeated material rows by resolved material name.

### Anti-pattern

```cs
if (target != null && massValue != null && !string.IsNullOrEmpty(target.UOMWgt) && !string.IsNullOrEmpty(massValue.Uom))
{
    var planMassMeasure = CalculatorHelper.GetUnitMeasure(target.UOMWgt);
    var actualMassMeasure = CalculatorHelper.GetUnitMeasure(massValue.Uom);
    valueList.PlanMassValue = AuraValue.FromAuraValues(new AuraValue(0.0, actualMassMeasure), new AuraValue(targetValue.massValue, planMassMeasure)).NumericValue;
    valueList.PlanMassUOM = valueList.ActualMassUOM;
}
```

### Recommended pattern

```cs
var model = transaction.EntityTransaction.AuraModel();
var template = transaction.EntityTransaction.Select<StreamTemplate>().FirstOrDefault();
var mUOM = CalculatorHelper.GetUnitMeasure(model, template?.GetAttribute(AttributeSetUsage.ReconciledMass)?.PropertyDefinition?.PropertyDefinition);
var vUOM = CalculatorHelper.GetUnitMeasure(model, template?.GetAttribute(AttributeSetUsage.ReconciledVolume)?.PropertyDefinition?.PropertyDefinition);

if (planMassMeasure != null && mUOM != null)
{
    valueList.PlanMassValue = AuraValue.FromAuraValues(new AuraValue(0.0, mUOM), new AuraValue(targetValue.massValue, planMassMeasure)).NumericValue;
    valueList.PlanMassUOM = mUOM.Name;
}
```

### Rule

When a report compares plan and actual values, convert both sides into a single report-level UOM before aggregation. Also key aggregation on a resolved business name, not a raw source name that may vary across catalog/material mappings.

---

## Pattern 2: Preserve License Error State Instead Of Collapsing It Into Empty Trend Data

**Related defects:** 1418984
**Related changesets:** 239877, 240085, 240243

### Context

The trend pane treated any dataset whose points all had `errorCode` as null-data and cleared the point list. That hid the specific "Unable to acquire license" state, so the user saw an empty trend instead of a meaningful license failure condition.

### Anti-pattern

```ts
let isNullData = dataPointers.every(i => i.points.every(p => p.errorCode != null));
if (isNullData) { dataPointers.forEach(s => s.points = []); }
```

### Recommended pattern

```ts
let isNullData = dataPointers.every(i =>
    i.points.every(p => p.errorCode != null && !p.qualityStatus.includes("Unable to acquire license"))
);
if (isNullData) { dataPointers.forEach(s => s.points = []); }
```

### Rule

Do not fold diagnostic error states into generic empty data. If the backend provides a specific recoverable or actionable status such as license exhaustion, preserve that signal for the UI instead of erasing the series.

---

## Pattern 3: Apply Negative-Value Correction Only In Measurement Flows

**Related defects:** 1732066
**Related changesets:** 240442, 240535

### Context

The reconciliation generator corrected negative measured values by converting them to absolute values, but it did so too broadly. That caused non-measurement flows to inherit measurement-only logic and produced inconsistent reconciled output.

### Anti-pattern

```cs
if (measMass?.NumericValue < 0)
    sam = AuraValue.FromObject(Math.Abs(measMass.Value.NumericValue.Value), measMass?.GetUnitMeasure());
```

### Recommended pattern

```cs
if (flow.Measurement && measMass?.NumericValue < 0)
    sam = AuraValue.FromObject(Math.Abs(measMass.Value.NumericValue.Value), measMass?.GetUnitMeasure());
```

### Rule

When patching numerical cleanup logic, guard it with the exact domain predicate that makes the transformation valid. A mathematically safe transformation is still wrong if it crosses entity-type boundaries.

---

## Pattern 4: Separate Import Semantics For New Events, Existing Events, And Formula Attributes

**Related defects:** 1737290, 1737304
**Related changesets:** 239946, 239978

### Context

Import logic previously chose between regular set and override based only on whether a formula existed. That lost two important cases: existing events need override to highlight changes, and new events with formulas need override so the calculator does not wipe imported values.

### Anti-pattern

```cs
if (string.IsNullOrEmpty(eventProxy.ResolveFormula(auraAttr)))
    trans.AnalysisCase.SetEntityAttributeValue(eventProxy.Id, auraAttr, auraVal);
else
    trans.AnalysisCase.SetEntityAttributeOverride(eventProxy.Id, auraAttr, auraVal, reason);
```

### Recommended pattern

```cs
if (isNewEvent && string.IsNullOrEmpty(eventProxy.ResolveFormula(auraAttr)))
    trans.AnalysisCase.SetEntityAttributeValue(eventProxy.Id, auraAttr, auraVal);
else
    trans.AnalysisCase.SetEntityAttributeOverride(eventProxy.Id, auraAttr, auraVal, reason);
```

### Rule

Import/update logic should branch on business state first, not just field metadata. Distinguish at least these cases: new entity vs existing entity, formula-backed field vs plain field, and whether change-highlighting is expected.

---

## Pattern 5: Deduplicate Time-Keyed Inputs Before Validation And Movement Expansion

**Related defects:** 1737167
**Related changesets:** 239947

### Context

Cutoffs with the same `EventTime` were expanded independently, which duplicated movements and let invalid movements bypass single-cutoff checks. The fix deduplicated the cutoff list at the boundary before downstream processing.

### Anti-pattern

```cs
if (cutoffs == null || !cutoffs.Any())
{
    warnings?.Add($"No cutoffs for the period {caseStartTime} - {caseEndTime}");
}
return cutoffs;
```

### Recommended pattern

```cs
if (cutoffs == null || !cutoffs.Any())
{
    warnings?.Add($"No cutoffs for the period {caseStartTime} - {caseEndTime}");
    return cutoffs;
}
return cutoffs.GroupBy(c => c.EventTime).Select(g => g.First()).ToList();
```

### Rule

When downstream logic assumes uniqueness on a business key such as timestamp, enforce that uniqueness at the boundary. Validation after expansion is too late because duplicate fan-out already polluted the result set.
