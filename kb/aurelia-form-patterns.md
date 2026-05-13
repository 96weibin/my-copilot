# Aurelia Form Patterns

Common patterns and pitfalls in Aurelia-based dialog/form development (Aura / AUM projects).

---

## Pattern: Validation via `isDisabled` Computed Property (Not Input Component Limits)

### Context

Many UI components (e.g., `datetime-input`) support `start-limit` / `end-limit` bindings that physically prevent the user from entering certain values. While this seems safe, it creates a poor UX because:
- Users can't even type out-of-range values, so they don't understand *why* submission is blocked
- The disabled state of the submit button has no explanation
- It mixes constraint logic into the template (hard to test, hard to change)

### Anti-Pattern (what NOT to do)

```html
<datetime-input value.two-way="startTime"
  start-limit.bind="contextState.currentCase.startTime"
  end-limit.bind="endTime">
</datetime-input>
```

This blocks input at the component level — the user sees odd behavior with no feedback.

### Recommended Pattern

**1. Remove input constraints from the template:**

```html
<datetime-input value.two-way="startTime" format-string.bind="formatString">
</datetime-input>
```

**2. Validate in the `isDisabled` computed property, with a `disabledReason` field:**

```ts
private disabledReason: string = '';

@computedFrom('isNameValid', 'name', 'selectedSourceId', 'selectedDestinationId', 'startTime', 'endTime', 'eventTemplateId')
get isDisabled() {
    if (!this.isNameValid || !this.name) {
        this.disabledReason = Resources.flowsheet.createEventDialog.nameInvalidMessage;
        return true;
    } else if (!this.selectedSourceId || !this.selectedDestinationId) {
        this.disabledReason = Resources.flowsheet.createEventDialog.noSourceDestinationMessage;
        return true;
    } else if (this.startTime.isBefore(this.contextState.currentCase.startTime) || 
               this.startTime.isAfter(this.contextState.currentCase.endTime)) {
        this.disabledReason = Resources.flowsheet.createEventDialog.startTimeOutCaseRangeMessage;
        return true;
    } else if (this.startTime.isAfter(this.endTime) || this.startTime.isSame(this.endTime)) {
        this.disabledReason = Resources.flowsheet.createEventDialog.startTimeIsAfterEndTimeMessage;
        return true;
    } else {
        return false;
    }
}
```

**3. Add i18n messages for each specific failure:**

```json
"createEventDialog": {
  "nameInvalidMessage": "Invalid Name",
  "noSourceDestinationMessage": "Source/Destination not found",
  "startTimeOutCaseRangeMessage": "Start time is out of the case range",
  "endTimeOutCaseRangeMessage": "End time is out of the case range",
  "startTimeIsAfterEndTimeMessage": "Start time is after End time",
  "startTimeIsSameAsEndTimeMessage": "Start time is same as End time",
  "noTemplateMessage": "No template found"
}
```

**4. Optionally bind `disabled-reason` to a tooltip on the submit button:**

```html
<button disabled.bind="isDisabled" title.bind="disabledReason">Submit</button>
```

### Benefits

- User can always type any value; errors shown on submit button hover
- Each validation case has its own i18n message — easy to extend
- Computed property is unit-testable and logic is centralized in the VM

### Bug Reference

- **Defect 1264939**: "Create event in case should allow entering any date and time"
- **Fixed Build**: media 25 | **SCM**: C217415 (Jan 3, 2024)
- **Committer**: Zhao, Weibin
- Files: `create-event-dialog.{ts,html,less}`, `resources/aura.json`

---

## Pattern: `@computedFrom` Dependencies — Keep Exhaustive

When a computed getter reads multiple properties, all must appear in `@computedFrom`. Missing a dependency means the getter won't re-evaluate when that property changes.

```ts
// ✅ All read properties are listed
@computedFrom('startTime', 'endTime', 'name', 'isNameValid', 'selectedSourceId', 'selectedDestinationId', 'eventTemplateId')
get isDisabled() { ... }
```

If you add a new condition that reads a new property (e.g., `this.disabledReason`), add that property to `@computedFrom` as well.

---

## Related

- **Project KB**: `.github/kb/` (project-specific patterns)
- **ag-Grid patterns**: see `common-data-grid.md` in Aura project KB
