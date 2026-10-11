# Packaging costing guide — Windows 1.0.5

The production workspace calculates cost estimates from entered ingredients and output. It does not post stock valuation or cost of goods sold. Continue to use Operations and transfers for physical stock movements and Finance for posted journals.

## Explicit fill units

Select g, kg, ml or L for each packaging row. The size label and report use the selected unit. Mass fills need no density: grams / 1000 = kilograms. Volume fills require your measured product density in kg/L: liters × density = kilograms. No density is assumed automatically. The density applies to the product in the current costing draft.

Old packaging drafts used size / 1000 without recording a unit. Their values are preserved, but their units are unconfirmed after upgrade. Confirm grams if that is what you entered, or select the appropriate volume/mass unit. Reports remain blocked until the unit is confirmed, size is positive and any required density is entered.

## Worked example

- Product: Cleaner; output: 10 kg.
- Ingredient: 2 kg of concentrate costing $10/kg. Total ingredient estimate: $20; liquid cost: $2/kg.
- Bottle fill: 500 ml; measured density: 1.2 kg/L.
- Fill mass: 0.5 L × 1.2 = 0.6 kg. Liquid cost per bottle: $1.20.
- Empty container: $0.20; label: $0.10. Filled bottle estimate: $1.50.
- Six bottles per carton; empty carton: $0.60. Total carton estimate: $9.60.

With 500 g instead, fill mass is 0.5 kg and the bottle estimate is $1.30. That difference is why the unit and density must be explicit.

Label costs can be entered whether or not a carton is selected. Unit totals include liquid, empty container and label. Carton totals multiply unit cost by bottle count and add the empty-carton cost. Labor, overhead, waste and accounting valuation are not included in these estimates yet.

## Completeness and currency

A report needs a product name, positive output in kilograms and named ingredients with positive quantities. Incomplete or out-of-range inputs produce guidance instead of misleading zero costs or an overflowing calculation. A zero ingredient price remains valid if that input actually has no cost.

Enter a positive exchange rate before editing SYP conversion fields. Without one, USD estimates remain available and SYP report amounts show an em dash. No zero converted value is presented as an actual cost. The USD monetary total is an estimate rounded for display; posted purchase/sales documents continue to use exact integer monetary amounts.

## Upgrade and testing

Inventory schema remains v12. Packaging drafts now use v2, including fill unit, confirmation and density. Older v1 drafts/backups remain readable. Export a business backup before upgrading and keep matching older data with an older executable if rollback is necessary; older builds cannot read new draft fields safely.

Automated checks cover equivalent mass/volume fills, measured density, invalid/overflow quantities, carton totals, v1 migration, persisted density/units, schema validation and English/Arabic operation at 320/1280 logical pixels. Verify the resulting PDF on your physical printer as part of business acceptance.
