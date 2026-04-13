// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'حاسبة منظفات';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get continueButton => 'متابعة';

  @override
  String get tabProduction => 'الإنتاج';

  @override
  String get tabPackaging => 'التعبئة والحزم';

  @override
  String get tabReports => 'التقارير';

  @override
  String get productionHeader => 'إدارة إنتاج المنظفات';

  @override
  String get productNameLabel => 'اسم المنتج (مثال: سائل جلي)';

  @override
  String get producedQuantityLabel => 'الكمية المنتجة (كغ)';

  @override
  String get exchangeRateLabel => 'سعر الصرف';

  @override
  String get rawMaterialsTitle => 'قائمة المواد الخام';

  @override
  String get rawMaterialsHelper =>
      'أدخل السعر بجهة واحدة ليتم حساب الأخرى تلقائياً';

  @override
  String get addMaterial => 'إضافة مادة';

  @override
  String get materialName => 'اسم المادة الخام';

  @override
  String get weightLabel => 'الوزن';

  @override
  String get priceUSDLabel => 'السعر \$';

  @override
  String get priceSYPLabel => 'السعر ل.س';

  @override
  String get coreMaterialTooltip => 'المادة الفعالة الأساسية';

  @override
  String get packagingHeader => 'إعدادات التعبئة';

  @override
  String get packagingTypesTitle => 'أنواع العبوات';

  @override
  String get addPackageSize => 'إضافة حجم';

  @override
  String get sizeLabel => 'الحجم (غ)';

  @override
  String get hasCartonLabel => 'تحوي كرتونة؟';

  @override
  String get cartonDetailsTitle => 'تفاصيل الكرتونة';

  @override
  String get cartonCountLabel => 'العدد';

  @override
  String get cartonPriceEmpty => 'سعر الكرتونة فارغة \$';

  @override
  String get cartonPriceEmptySYP => 'سعر الكرتونة فارغة ل.س';

  @override
  String get labelPrice => 'سعر اللصاقة \$';

  @override
  String get labelPriceSYP => 'سعر اللصاقة ل.س';

  @override
  String get finalResultsHeader => 'النتائج النهائية المفصلة';

  @override
  String get summaryGeneral => 'ملخص الإنتاج العام';

  @override
  String get finalProductName => 'اسم المنتج النهائي';

  @override
  String get totalProducedQuantity => 'الكمية المنتجة الكلية';

  @override
  String get approvedExchangeRate => 'سعر الصرف المعتمد';

  @override
  String get costPerKgUSD => 'تكلفة الكيلو (\$)';

  @override
  String get costPerKgSYP => 'تكلفة الكيلو (ل.س)';

  @override
  String get activeIngredientsPercentage => 'نسبة المواد الفعالة';

  @override
  String get usedRawMaterials => 'المواد الخام المستخدمة';

  @override
  String get packagingDetailsTitle => 'تفاصيل العبوات والكراتين';

  @override
  String packageSizeTitle(String size) {
    return 'عبوة حجم $size غ';
  }

  @override
  String get packagePriceUSD => 'تكلفة العبوة (\$)';

  @override
  String get packagePriceSYP => 'تكلفة العبوة (ل.س)';

  @override
  String get cartonPriceUSD => 'الكرتونة (\$)';

  @override
  String get cartonPriceSYP => 'الكرتونة (ل.س)';

  @override
  String get generatePDFBtn => 'إصدار التقرير النهائي (PDF)';

  @override
  String get mainMenuTitle => 'القائمة الرئيسية';

  @override
  String get btnProductionCalc => 'حاسبة الإنتاج';

  @override
  String get btnWarehouse => 'إدارة مستودع المواد الأولية';

  @override
  String get btnSalesShop => 'متجر المبيعات';

  @override
  String get warehouseTitle => 'إدارة المستودع';

  @override
  String get shopTitle => 'متجر المبيعات';

  @override
  String get addStock => 'إضافة رصيد';

  @override
  String get removeStock => 'سحب رصيد';

  @override
  String get quantity => 'الكمية';

  @override
  String get costOptional => 'التكلفة (اختياري)';

  @override
  String get availableQuantity => 'الكمية المتوفرة';

  @override
  String get totalMaterials => 'إجمالي المواد';

  @override
  String get inventorySummary => 'ملخص المخزون';

  @override
  String get productNameLabelShop => 'اسم المنتج';

  @override
  String get sellProduct => 'بيع منتج';

  @override
  String get sellBtn => 'بيع';

  @override
  String get cancelBtn => 'إلغاء';

  @override
  String get noItemsInStock => 'لا توجد عناصر في المخزون.';

  @override
  String get addMaterialToWarehouse => 'إضافة مادة للمستودع';

  @override
  String get removeMaterialFromWarehouse => 'سحب مادة من المستودع';

  @override
  String get addProductToShop => 'إضافة منتج للمتجر';

  @override
  String get sellProductFromShop => 'بيع منتج من المتجر';

  @override
  String get unitLabel => 'الوحدة';

  @override
  String get unitKilogram => 'كيلوغرام (kg)';

  @override
  String get unitGram => 'غرام (g)';

  @override
  String get unitLiter => 'لتر (L)';

  @override
  String get unitGallon => 'غالون';

  @override
  String get unitPiece => 'قطعة';

  @override
  String get unitBox => 'علبة';

  @override
  String get unitCarton => 'كرتونة';

  @override
  String get unitPackage => 'مغلف';

  @override
  String get unitPriceLabel => 'سعر الوحدة';

  @override
  String get totalPriceLabel => 'السعر الإجمالي';

  @override
  String get manufactureBtn => 'تصنيع';

  @override
  String get manufactureDialogTitle => 'تصنيع منتج';

  @override
  String get producedQuantity => 'الكمية المنتجة';

  @override
  String get selectRawMaterials => 'حدد المواد الأولية المستخدمة';

  @override
  String get materialUsedQuantity => 'الكمية المستخدمة';

  @override
  String get manufacturedProductsTitle => 'المنتجات المصنعة';

  @override
  String get confirmBtn => 'تأكيد';

  @override
  String errorNotEnoughStock(String stock) {
    return 'رصيد غير كافٍ. المتوفر: $stock';
  }

  @override
  String get consumptionRecord => 'حركة استهلاك';

  @override
  String get totalValueLabel => 'القيمة الإجمالية';

  @override
  String get deleteBtn => 'حذف';

  @override
  String get editBtn => 'تعديل';

  @override
  String get resetSystemBtn => 'إعادة ضبط النظام';

  @override
  String get resetTargetTitle => 'اختر البيانات لإعادة الضبط';

  @override
  String get resetWarehouseBtn => 'إعادة ضبط المستودع والتصنيع';

  @override
  String get resetSalesBtn => 'إعادة ضبط متجر المبيعات';

  @override
  String get backToMainMenuBtn => 'العودة إلى الصفحة الرئيسية';

  @override
  String get backToLanguageBtn => 'العودة لاختيار اللغة';

  @override
  String get resetConfirmation =>
      'هل أنت متأكد أنك تريد إعادة ضبط هذه البيانات؟ لا يمكن التراجع عن ذلك.';

  @override
  String get resetSuccess => 'تمت إعادة ضبط النظام بنجاح';

  @override
  String get transactionRestore => 'استرداد';

  @override
  String get editManufactureTitle => 'تعديل منتج مصنع';

  @override
  String get deleteManufactureConfirm =>
      'هل أنت متأكد أنك تريد حذف سجل التصنيع هذا؟ سيؤدي ذلك إلى استعادة المواد الأولية المستخدمة في المستودع.';
}
