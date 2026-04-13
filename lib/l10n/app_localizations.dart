import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Detergent Calculator'**
  String get appTitle;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @tabProduction.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get tabProduction;

  /// No description provided for @tabPackaging.
  ///
  /// In en, this message translates to:
  /// **'Packaging'**
  String get tabPackaging;

  /// No description provided for @tabReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get tabReports;

  /// No description provided for @productionHeader.
  ///
  /// In en, this message translates to:
  /// **'Detergent Production Management'**
  String get productionHeader;

  /// No description provided for @productNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Name (e.g. Dish soap)'**
  String get productNameLabel;

  /// No description provided for @producedQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Produced Quantity (kg)'**
  String get producedQuantityLabel;

  /// No description provided for @exchangeRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Exchange Rate'**
  String get exchangeRateLabel;

  /// No description provided for @rawMaterialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Raw Materials'**
  String get rawMaterialsTitle;

  /// No description provided for @rawMaterialsHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter price on one side to calculate automatically'**
  String get rawMaterialsHelper;

  /// No description provided for @addMaterial.
  ///
  /// In en, this message translates to:
  /// **'Add Material'**
  String get addMaterial;

  /// No description provided for @materialName.
  ///
  /// In en, this message translates to:
  /// **'Material Name'**
  String get materialName;

  /// No description provided for @weightLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightLabel;

  /// No description provided for @priceUSDLabel.
  ///
  /// In en, this message translates to:
  /// **'Price \$'**
  String get priceUSDLabel;

  /// No description provided for @priceSYPLabel.
  ///
  /// In en, this message translates to:
  /// **'Price SYP'**
  String get priceSYPLabel;

  /// No description provided for @coreMaterialTooltip.
  ///
  /// In en, this message translates to:
  /// **'Core Active Material'**
  String get coreMaterialTooltip;

  /// No description provided for @packagingHeader.
  ///
  /// In en, this message translates to:
  /// **'Packaging Settings'**
  String get packagingHeader;

  /// No description provided for @packagingTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'Packaging Types'**
  String get packagingTypesTitle;

  /// No description provided for @addPackageSize.
  ///
  /// In en, this message translates to:
  /// **'Add Size'**
  String get addPackageSize;

  /// No description provided for @sizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size (g)'**
  String get sizeLabel;

  /// No description provided for @hasCartonLabel.
  ///
  /// In en, this message translates to:
  /// **'Has Carton?'**
  String get hasCartonLabel;

  /// No description provided for @cartonDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Carton Details'**
  String get cartonDetailsTitle;

  /// No description provided for @cartonCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get cartonCountLabel;

  /// No description provided for @cartonPriceEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty Carton Price \$'**
  String get cartonPriceEmpty;

  /// No description provided for @cartonPriceEmptySYP.
  ///
  /// In en, this message translates to:
  /// **'Empty Carton Price SYP'**
  String get cartonPriceEmptySYP;

  /// No description provided for @labelPrice.
  ///
  /// In en, this message translates to:
  /// **'Label Price \$'**
  String get labelPrice;

  /// No description provided for @labelPriceSYP.
  ///
  /// In en, this message translates to:
  /// **'Label Price SYP'**
  String get labelPriceSYP;

  /// No description provided for @finalResultsHeader.
  ///
  /// In en, this message translates to:
  /// **'Final Detailed Results'**
  String get finalResultsHeader;

  /// No description provided for @summaryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General Production Summary'**
  String get summaryGeneral;

  /// No description provided for @finalProductName.
  ///
  /// In en, this message translates to:
  /// **'Final Product Name'**
  String get finalProductName;

  /// No description provided for @totalProducedQuantity.
  ///
  /// In en, this message translates to:
  /// **'Total Produced Quantity'**
  String get totalProducedQuantity;

  /// No description provided for @approvedExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Approved Exchange Rate'**
  String get approvedExchangeRate;

  /// No description provided for @costPerKgUSD.
  ///
  /// In en, this message translates to:
  /// **'Cost per Kg (\$)'**
  String get costPerKgUSD;

  /// No description provided for @costPerKgSYP.
  ///
  /// In en, this message translates to:
  /// **'Cost per Kg (SYP)'**
  String get costPerKgSYP;

  /// No description provided for @activeIngredientsPercentage.
  ///
  /// In en, this message translates to:
  /// **'Active Ingredients %'**
  String get activeIngredientsPercentage;

  /// No description provided for @usedRawMaterials.
  ///
  /// In en, this message translates to:
  /// **'Used Raw Materials'**
  String get usedRawMaterials;

  /// No description provided for @packagingDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Packaging & Cartons Details'**
  String get packagingDetailsTitle;

  /// No description provided for @packageSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Package Size {size} g'**
  String packageSizeTitle(String size);

  /// No description provided for @packagePriceUSD.
  ///
  /// In en, this message translates to:
  /// **'Package Cost (\$)'**
  String get packagePriceUSD;

  /// No description provided for @packagePriceSYP.
  ///
  /// In en, this message translates to:
  /// **'Package Cost (SYP)'**
  String get packagePriceSYP;

  /// No description provided for @cartonPriceUSD.
  ///
  /// In en, this message translates to:
  /// **'Carton Price (\$)'**
  String get cartonPriceUSD;

  /// No description provided for @cartonPriceSYP.
  ///
  /// In en, this message translates to:
  /// **'Carton Price (SYP)'**
  String get cartonPriceSYP;

  /// No description provided for @generatePDFBtn.
  ///
  /// In en, this message translates to:
  /// **'Generate Final Report (PDF)'**
  String get generatePDFBtn;

  /// No description provided for @mainMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Main Menu'**
  String get mainMenuTitle;

  /// No description provided for @btnProductionCalc.
  ///
  /// In en, this message translates to:
  /// **'Production Calculator'**
  String get btnProductionCalc;

  /// No description provided for @btnWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Raw Materials Warehouse'**
  String get btnWarehouse;

  /// No description provided for @btnSalesShop.
  ///
  /// In en, this message translates to:
  /// **'Sales Shop'**
  String get btnSalesShop;

  /// No description provided for @warehouseTitle.
  ///
  /// In en, this message translates to:
  /// **'Warehouse Management'**
  String get warehouseTitle;

  /// No description provided for @shopTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales Shop System'**
  String get shopTitle;

  /// No description provided for @addStock.
  ///
  /// In en, this message translates to:
  /// **'Add Stock'**
  String get addStock;

  /// No description provided for @removeStock.
  ///
  /// In en, this message translates to:
  /// **'Remove Stock'**
  String get removeStock;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @costOptional.
  ///
  /// In en, this message translates to:
  /// **'Cost (optional)'**
  String get costOptional;

  /// No description provided for @availableQuantity.
  ///
  /// In en, this message translates to:
  /// **'Available Quantity'**
  String get availableQuantity;

  /// No description provided for @totalMaterials.
  ///
  /// In en, this message translates to:
  /// **'Total Materials'**
  String get totalMaterials;

  /// No description provided for @inventorySummary.
  ///
  /// In en, this message translates to:
  /// **'Inventory Summary'**
  String get inventorySummary;

  /// No description provided for @productNameLabelShop.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get productNameLabelShop;

  /// No description provided for @sellProduct.
  ///
  /// In en, this message translates to:
  /// **'Sell Product'**
  String get sellProduct;

  /// No description provided for @sellBtn.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sellBtn;

  /// No description provided for @cancelBtn.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelBtn;

  /// No description provided for @noItemsInStock.
  ///
  /// In en, this message translates to:
  /// **'No items in stock.'**
  String get noItemsInStock;

  /// No description provided for @addMaterialToWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Add material to warehouse'**
  String get addMaterialToWarehouse;

  /// No description provided for @removeMaterialFromWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Remove material from warehouse'**
  String get removeMaterialFromWarehouse;

  /// No description provided for @addProductToShop.
  ///
  /// In en, this message translates to:
  /// **'Add product to shop'**
  String get addProductToShop;

  /// No description provided for @sellProductFromShop.
  ///
  /// In en, this message translates to:
  /// **'Sell product from shop'**
  String get sellProductFromShop;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitLabel;

  /// No description provided for @unitKilogram.
  ///
  /// In en, this message translates to:
  /// **'Kilogram (kg)'**
  String get unitKilogram;

  /// No description provided for @unitGram.
  ///
  /// In en, this message translates to:
  /// **'Gram (g)'**
  String get unitGram;

  /// No description provided for @unitLiter.
  ///
  /// In en, this message translates to:
  /// **'Liter (L)'**
  String get unitLiter;

  /// No description provided for @unitGallon.
  ///
  /// In en, this message translates to:
  /// **'Gallon'**
  String get unitGallon;

  /// No description provided for @unitPiece.
  ///
  /// In en, this message translates to:
  /// **'Piece'**
  String get unitPiece;

  /// No description provided for @unitBox.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get unitBox;

  /// No description provided for @unitCarton.
  ///
  /// In en, this message translates to:
  /// **'Carton'**
  String get unitCarton;

  /// No description provided for @unitPackage.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get unitPackage;

  /// No description provided for @unitPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit Price'**
  String get unitPriceLabel;

  /// No description provided for @totalPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Price'**
  String get totalPriceLabel;

  /// No description provided for @manufactureBtn.
  ///
  /// In en, this message translates to:
  /// **'Manufacture'**
  String get manufactureBtn;

  /// No description provided for @manufactureDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Manufacture Product'**
  String get manufactureDialogTitle;

  /// No description provided for @producedQuantity.
  ///
  /// In en, this message translates to:
  /// **'Produced Quantity'**
  String get producedQuantity;

  /// No description provided for @selectRawMaterials.
  ///
  /// In en, this message translates to:
  /// **'Select Raw Materials Used'**
  String get selectRawMaterials;

  /// No description provided for @materialUsedQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity Used'**
  String get materialUsedQuantity;

  /// No description provided for @manufacturedProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manufactured Products'**
  String get manufacturedProductsTitle;

  /// No description provided for @confirmBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmBtn;

  /// No description provided for @errorNotEnoughStock.
  ///
  /// In en, this message translates to:
  /// **'Not enough stock. Available: {stock}'**
  String errorNotEnoughStock(String stock);

  /// No description provided for @consumptionRecord.
  ///
  /// In en, this message translates to:
  /// **'Consumption Transaction'**
  String get consumptionRecord;

  /// No description provided for @totalValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Value'**
  String get totalValueLabel;

  /// No description provided for @deleteBtn.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteBtn;

  /// No description provided for @editBtn.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editBtn;

  /// No description provided for @resetSystemBtn.
  ///
  /// In en, this message translates to:
  /// **'Reset System'**
  String get resetSystemBtn;

  /// No description provided for @resetTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Data to Reset'**
  String get resetTargetTitle;

  /// No description provided for @resetWarehouseBtn.
  ///
  /// In en, this message translates to:
  /// **'Reset Warehouse & Manufacturing'**
  String get resetWarehouseBtn;

  /// No description provided for @resetSalesBtn.
  ///
  /// In en, this message translates to:
  /// **'Reset Sales Shop'**
  String get resetSalesBtn;

  /// No description provided for @backToMainMenuBtn.
  ///
  /// In en, this message translates to:
  /// **'Back to Main Menu'**
  String get backToMainMenuBtn;

  /// No description provided for @backToLanguageBtn.
  ///
  /// In en, this message translates to:
  /// **'Back to Language Selection'**
  String get backToLanguageBtn;

  /// No description provided for @resetConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset this data? This cannot be undone.'**
  String get resetConfirmation;

  /// No description provided for @resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'System reset successfully'**
  String get resetSuccess;

  /// No description provided for @transactionRestore.
  ///
  /// In en, this message translates to:
  /// **'RESTORE'**
  String get transactionRestore;

  /// No description provided for @editManufactureTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Manufactured Product'**
  String get editManufactureTitle;

  /// No description provided for @deleteManufactureConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this manufacturing record? This will restore the used raw materials into the warehouse.'**
  String get deleteManufactureConfirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
