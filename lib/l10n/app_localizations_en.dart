// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Detergent Calculator';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get continueButton => 'Continue';

  @override
  String get tabProduction => 'Production';

  @override
  String get tabPackaging => 'Packaging';

  @override
  String get tabReports => 'Reports';

  @override
  String get productionHeader => 'Detergent Production Management';

  @override
  String get productNameLabel => 'Product Name (e.g. Dish soap)';

  @override
  String get producedQuantityLabel => 'Produced Quantity (kg)';

  @override
  String get exchangeRateLabel => 'Exchange Rate';

  @override
  String get rawMaterialsTitle => 'Raw Materials';

  @override
  String get rawMaterialsHelper =>
      'Enter price on one side to calculate automatically';

  @override
  String get addMaterial => 'Add Material';

  @override
  String get materialName => 'Material Name';

  @override
  String get weightLabel => 'Weight';

  @override
  String get priceUSDLabel => 'Price \$';

  @override
  String get priceSYPLabel => 'Price SYP';

  @override
  String get coreMaterialTooltip => 'Core Active Material';

  @override
  String get packagingHeader => 'Packaging Settings';

  @override
  String get packagingTypesTitle => 'Packaging Types';

  @override
  String get addPackageSize => 'Add Size';

  @override
  String get sizeLabel => 'Size (g)';

  @override
  String get hasCartonLabel => 'Has Carton?';

  @override
  String get cartonDetailsTitle => 'Carton Details';

  @override
  String get cartonCountLabel => 'Count';

  @override
  String get cartonPriceEmpty => 'Empty Carton Price \$';

  @override
  String get cartonPriceEmptySYP => 'Empty Carton Price SYP';

  @override
  String get labelPrice => 'Label Price \$';

  @override
  String get labelPriceSYP => 'Label Price SYP';

  @override
  String get finalResultsHeader => 'Final Detailed Results';

  @override
  String get summaryGeneral => 'General Production Summary';

  @override
  String get finalProductName => 'Final Product Name';

  @override
  String get totalProducedQuantity => 'Total Produced Quantity';

  @override
  String get approvedExchangeRate => 'Approved Exchange Rate';

  @override
  String get costPerKgUSD => 'Cost per Kg (\$)';

  @override
  String get costPerKgSYP => 'Cost per Kg (SYP)';

  @override
  String get activeIngredientsPercentage => 'Active Ingredients %';

  @override
  String get usedRawMaterials => 'Used Raw Materials';

  @override
  String get packagingDetailsTitle => 'Packaging & Cartons Details';

  @override
  String packageSizeTitle(String size) {
    return 'Package Size $size g';
  }

  @override
  String get packagePriceUSD => 'Package Cost (\$)';

  @override
  String get packagePriceSYP => 'Package Cost (SYP)';

  @override
  String get cartonPriceUSD => 'Carton Price (\$)';

  @override
  String get cartonPriceSYP => 'Carton Price (SYP)';

  @override
  String get generatePDFBtn => 'Generate Final Report (PDF)';

  @override
  String get mainMenuTitle => 'Main Menu';

  @override
  String get btnProductionCalc => 'Production Calculator';

  @override
  String get btnWarehouse => 'Raw Materials Warehouse';

  @override
  String get btnSalesShop => 'Sales Shop';

  @override
  String get warehouseTitle => 'Warehouse Management';

  @override
  String get shopTitle => 'Sales Shop System';

  @override
  String get addStock => 'Add Stock';

  @override
  String get removeStock => 'Remove Stock';

  @override
  String get quantity => 'Quantity';

  @override
  String get costOptional => 'Cost (optional)';

  @override
  String get availableQuantity => 'Available Quantity';

  @override
  String get totalMaterials => 'Total Materials';

  @override
  String get inventorySummary => 'Inventory Summary';

  @override
  String get productNameLabelShop => 'Product Name';

  @override
  String get sellProduct => 'Sell Product';

  @override
  String get sellBtn => 'Sell';

  @override
  String get cancelBtn => 'Cancel';

  @override
  String get noItemsInStock => 'No items in stock.';

  @override
  String get addMaterialToWarehouse => 'Add material to warehouse';

  @override
  String get removeMaterialFromWarehouse => 'Remove material from warehouse';

  @override
  String get addProductToShop => 'Add product to shop';

  @override
  String get sellProductFromShop => 'Sell product from shop';

  @override
  String get unitLabel => 'Unit';

  @override
  String get unitKilogram => 'Kilogram (kg)';

  @override
  String get unitGram => 'Gram (g)';

  @override
  String get unitLiter => 'Liter (L)';

  @override
  String get unitGallon => 'Gallon';

  @override
  String get unitPiece => 'Piece';

  @override
  String get unitBox => 'Box';

  @override
  String get unitCarton => 'Carton';

  @override
  String get unitPackage => 'Package';

  @override
  String get unitPriceLabel => 'Unit Price';

  @override
  String get totalPriceLabel => 'Total Price';

  @override
  String get manufactureBtn => 'Manufacture';

  @override
  String get manufactureDialogTitle => 'Manufacture Product';

  @override
  String get producedQuantity => 'Produced Quantity';

  @override
  String get selectRawMaterials => 'Select Raw Materials Used';

  @override
  String get materialUsedQuantity => 'Quantity Used';

  @override
  String get manufacturedProductsTitle => 'Manufactured Products';

  @override
  String get confirmBtn => 'Confirm';

  @override
  String errorNotEnoughStock(String stock) {
    return 'Not enough stock. Available: $stock';
  }

  @override
  String get consumptionRecord => 'Consumption Transaction';

  @override
  String get totalValueLabel => 'Total Value';

  @override
  String get deleteBtn => 'Delete';

  @override
  String get editBtn => 'Edit';

  @override
  String get resetSystemBtn => 'Reset System';

  @override
  String get resetTargetTitle => 'Select Data to Reset';

  @override
  String get resetWarehouseBtn => 'Reset Warehouse & Manufacturing';

  @override
  String get resetSalesBtn => 'Reset Sales Shop';

  @override
  String get backToMainMenuBtn => 'Back to Main Menu';

  @override
  String get backToLanguageBtn => 'Back to Language Selection';

  @override
  String get resetConfirmation =>
      'Are you sure you want to reset this data? This cannot be undone.';

  @override
  String get resetSuccess => 'System reset successfully';

  @override
  String get transactionRestore => 'RESTORE';

  @override
  String get editManufactureTitle => 'Edit Manufactured Product';

  @override
  String get deleteManufactureConfirm =>
      'Are you sure you want to delete this manufacturing record? This will restore the used raw materials into the warehouse.';
}
