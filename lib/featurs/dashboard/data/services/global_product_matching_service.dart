import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:fruitesdashboard/core/const/const.dart';
import 'package:fruitesdashboard/core/di/injection.dart';
import 'package:fruitesdashboard/core/repos/imag_repo/imag_repo.dart';
import 'package:xml/xml.dart';

class GlobalProductData {
  const GlobalProductData({
    required this.barcode,
    required this.name,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.rawData,
  });

  final String barcode;
  final String name;
  final String category;
  final String description;
  final String imageUrl;
  final Map<String, dynamic> rawData;

  factory GlobalProductData.fromFirestore(
    String barcode,
    Map<String, dynamic> data,
  ) {
    String readString(List<String> keys) {
      for (final key in keys) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '';
    }

    return GlobalProductData(
      barcode: barcode,
      name: readString(['name', 'product_name', 'productName']),
      category: readString(['category', 'categoryName']),
      description: readString(['description', 'desc']),
      imageUrl: readString([
        'image_url',
        'imageUrl',
        'imageurl',
        'global_image_url',
      ]),
      rawData: data,
    );
  }
}

class BulkProductMatch {
  const BulkProductMatch({
    required this.barcode,
    required this.price,
    required this.cost,
    required this.quantity,
    required this.name,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.isPrescriptionRequired,
    required this.globalProduct,
    required this.expirationDate,
    required this.rowNumber,
  });

  final String barcode;
  final num price;
  final num cost;
  final int quantity;
  final String name;
  final String category;
  final String description;
  final String imageUrl;
  final bool isPrescriptionRequired;
  final GlobalProductData? globalProduct;
  final DateTime expirationDate;
  final int rowNumber;

  String get productName => _preferSheetValue(name, globalProduct?.name ?? '');
  String get productCategory =>
      _preferSheetValue(category, globalProduct?.category ?? '');
  String get productDescription =>
      _preferSheetValue(description, globalProduct?.description ?? '');
  String get productImageUrl =>
      _preferSheetValue(imageUrl, globalProduct?.imageUrl ?? '');

  bool get isMatched => globalProduct != null || productName.isNotEmpty;

  BulkProductMatch copyWith({
    String? barcode,
    num? price,
    num? cost,
    int? quantity,
    String? name,
    String? category,
    String? description,
    String? imageUrl,
    bool? isPrescriptionRequired,
    GlobalProductData? globalProduct,
    DateTime? expirationDate,
    int? rowNumber,
  }) {
    return BulkProductMatch(
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      quantity: quantity ?? this.quantity,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isPrescriptionRequired:
          isPrescriptionRequired ?? this.isPrescriptionRequired,
      globalProduct: globalProduct ?? this.globalProduct,
      expirationDate: expirationDate ?? this.expirationDate,
      rowNumber: rowNumber ?? this.rowNumber,
    );
  }

  static String _preferSheetValue(String sheetValue, String fallback) {
    final value = sheetValue.trim();
    return value.isNotEmpty ? value : fallback.trim();
  }
}

class GlobalProductMatchingService {
  GlobalProductMatchingService({
    FirebaseFirestore? firestore,
    ImagRepo? imageRepo,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _imageRepo = imageRepo ??
            (getIt.isRegistered<ImagRepo>() ? getIt<ImagRepo>() : null);

  final FirebaseFirestore _firestore;
  final ImagRepo? _imageRepo;

  Future<GlobalProductData?> findByBarcode(String barcode) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) return null;

    final doc = await _firestore
        .collection('global_products')
        .doc(normalizedBarcode)
        .get();

    if (!doc.exists || doc.data() == null) return null;

    return GlobalProductData.fromFirestore(normalizedBarcode, doc.data()!);
  }

  Future<List<BulkProductMatch>> matchExcelBytes(Uint8List bytes) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) return const [];

      final firstSheet = excel.tables.values.first;
      final rows = firstSheet.rows;
      if (rows.isEmpty) return const [];

      return _matchExcelRows(
        rows: rows,
        looksLikeHeader: _looksLikeHeader,
        readString: _cellToString,
        readNum: _cellToNum,
        readDate: _cellToDate,
      );
    } catch (_) {
      final rows = _readRowsFromXlsx(bytes);
      if (rows.isEmpty) return const [];

      return _matchExcelRows(
        rows: rows,
        looksLikeHeader: _stringRowLooksLikeHeader,
        readString: _stringCell,
        readNum: _stringCellToNum,
        readDate: _stringCellToDate,
      );
    }
  }

  Future<List<BulkProductMatch>> _matchExcelRows<T>({
    required List<T> rows,
    required bool Function(T row) looksLikeHeader,
    required String Function(T row, int index) readString,
    required num Function(T row, int index) readNum,
    required DateTime? Function(T row, int index) readDate,
  }) async {
    final headerMap = looksLikeHeader(rows.first)
        ? _buildHeaderMap(rows.first, readString)
        : const <String, int>{};
    final startIndex = headerMap.isNotEmpty ? 1 : 0;
    final matches = <BulkProductMatch>[];

    for (var index = startIndex; index < rows.length; index++) {
      final row = rows[index];
      final barcode = _readByHeader(
        row,
        headerMap,
        readString,
        const ['barcode', 'bar code', 'code', 'كود', 'باركود'],
        0,
      );
      if (barcode.isEmpty) continue;

      final name = _readByHeader(
        row,
        headerMap,
        readString,
        const ['name', 'product name', 'product_name', 'productname', 'اسم'],
        -1,
      );
      final category = _readByHeader(
        row,
        headerMap,
        readString,
        const ['category', 'category name', 'category_name', 'تصنيف'],
        -1,
      );
      final description = _readByHeader(
        row,
        headerMap,
        readString,
        const ['description', 'desc', 'وصف'],
        -1,
      );
      final imageUrl = _readByHeader(
        row,
        headerMap,
        readString,
        const [
          'image_url',
          'image url',
          'imageurl',
          'image',
          'global_image_url',
          'productimageurl',
          'product image url',
          'صورة',
        ],
        -1,
      );
      final prescriptionText = _readByHeader(
        row,
        headerMap,
        readString,
        const [
          'is_prescription',
          'is prescription',
          'isprescription',
          'is_prescription_required',
          'is prescription required',
          'isprescriptionrequired',
          'prescription',
          'روشتة',
        ],
        -1,
      );

      final price = _readNumByHeader(
        row,
        headerMap,
        readNum,
        const ['price', 'sellingprice', 'selling price', 'السعر'],
        headerMap.isEmpty ? 1 : -1,
      );
      final cost = _readNumByHeader(
        row,
        headerMap,
        readNum,
        const ['cost', 'costprice', 'cost price', 'التكلفة'],
        headerMap.isEmpty ? 2 : -1,
      );
      final quantity = _readNumByHeader(
        row,
        headerMap,
        readNum,
        const ['quantity', 'qty', 'unitamount', 'unit amount', 'الكمية'],
        headerMap.isEmpty ? 3 : -1,
      ).toInt();
      final expirationDate = _readDateByHeader(
            row,
            headerMap,
            readDate,
            const ['expirationdate', 'expiration date', 'expirydate', 'expiry date'],
            headerMap.isEmpty ? 4 : -1,
          ) ??
          DateTime.now();
      final globalProduct = await findByBarcode(barcode);

      matches.add(BulkProductMatch(
        barcode: barcode,
        price: price,
        cost: cost,
        quantity: quantity,
        name: name,
        category: category,
        description: description,
        imageUrl: imageUrl,
        isPrescriptionRequired: _parseBool(prescriptionText),
        expirationDate: expirationDate,
        globalProduct: globalProduct,
        rowNumber: index + 1,
      ));
    }

    return matches;
  }

  Map<String, int> _buildHeaderMap<T>(
    T row,
    String Function(T row, int index) readString,
  ) {
    final headers = <String, int>{};
    for (var index = 0; index < 80; index++) {
      final header = _normalizeHeader(readString(row, index));
      if (header.isNotEmpty) {
        headers[header] = index;
      }
    }
    return headers;
  }

  String _readByHeader<T>(
    T row,
    Map<String, int> headerMap,
    String Function(T row, int index) readString,
    List<String> aliases,
    int fallbackIndex,
  ) {
    for (final alias in aliases) {
      final index = headerMap[_normalizeHeader(alias)];
      if (index != null) return readString(row, index).trim();
    }
    if (fallbackIndex < 0) return '';
    return readString(row, fallbackIndex).trim();
  }

  num _readNumByHeader<T>(
    T row,
    Map<String, int> headerMap,
    num Function(T row, int index) readNum,
    List<String> aliases,
    int fallbackIndex,
  ) {
    for (final alias in aliases) {
      final index = headerMap[_normalizeHeader(alias)];
      if (index != null) return readNum(row, index);
    }
    if (fallbackIndex < 0) return 0;
    return readNum(row, fallbackIndex);
  }

  DateTime? _readDateByHeader<T>(
    T row,
    Map<String, int> headerMap,
    DateTime? Function(T row, int index) readDate,
    List<String> aliases,
    int fallbackIndex,
  ) {
    for (final alias in aliases) {
      final index = headerMap[_normalizeHeader(alias)];
      if (index != null) return readDate(row, index);
    }
    if (fallbackIndex < 0) return null;
    return readDate(row, fallbackIndex);
  }

  Future<void> commitMatchedProducts({
    required String pharmacyId,
    required String pharmacyName,
    required double pharmacyLat,
    required double pharmacyLng,
    required List<BulkProductMatch> matches,
  }) async {
    final matchedRows = matches.where((match) => match.isMatched).toList();
    if (matchedRows.isEmpty) return;

    WriteBatch batch = _firestore.batch();
    var operationCount = 0;
    final uploadedImageUrls = <String, String>{};

    Future<void> commitIfFull() async {
      if (operationCount < 450) return;
      await batch.commit();
      batch = _firestore.batch();
      operationCount = 0;
    }

    for (final match in matchedRows) {
      final productDocId = '${match.barcode}_$pharmacyId';
      final imageUrl = await _siphonImageToSupabase(
        match.productImageUrl,
        uploadedImageUrls,
      );
      final productName = match.productName;
      final productCategory = match.productCategory;
      final productDescription = match.productDescription;
      final productData = {
        'name': productName,
        'price': match.price,
        'cost': match.cost,
        'sellingcount': 0,
        'code': match.barcode,
        'description': productDescription,
        'imageurl': imageUrl,
        'global_image_url': imageUrl,
        'averageRating': 0,
        'ratingcount': 0,
        'expirationDate': Timestamp.fromDate(match.expirationDate),
        'unitAmount': match.quantity,
        'reviews': const [],
        'hasDiscount': false,
        'discountPercentage': 0,
        'pharmacyId': pharmacyId,
        'isAvailable': true,
        'category': productCategory,
        'isPrescriptionRequired': match.isPrescriptionRequired,
        'pharmacyName': pharmacyName,
        'pharmacyLat': pharmacyLat,
        'pharmacyLng': pharmacyLng,
        'globalProductId': match.barcode,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final pharmacyProductRef = _firestore
          .collection('pharmacies')
          .doc(pharmacyId)
          .collection('products')
          .doc(match.barcode);
      final legacyProductRef =
          _firestore.collection('products').doc(productDocId);
      final inventoryRef = _firestore.collection('inventory').doc(productDocId);

      batch.set(pharmacyProductRef, productData, SetOptions(merge: true));
      batch.set(legacyProductRef, productData, SetOptions(merge: true));
      batch.set(inventoryRef, {
        'productId': productDocId,
        'productName': productName,
        'quantity': FieldValue.increment(match.quantity),
        'pharmacyId': pharmacyId,
        'category': productCategory,
        'expiryDate': Timestamp.fromDate(match.expirationDate),
        'costPrice': match.cost,
        'sellingPrice': match.price,
        'productImageUrl': imageUrl,
        'code': match.barcode,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      operationCount += 3;
      await commitIfFull();
    }

    if (operationCount > 0) {
      await batch.commit();
    }
  }

  Future<String> _siphonImageToSupabase(
    String imageUrl,
    Map<String, String> uploadedImageUrls,
  ) async {
    final normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty || _isSupabaseStorageUrl(normalizedUrl)) {
      return normalizedUrl;
    }

    // Browser apps cannot read bytes from many external CDNs because of CORS.
    // Keep the original URL instead of failing the whole bulk import.
    if (kIsWeb) {
      return normalizedUrl;
    }

    final cachedUrl = uploadedImageUrls[normalizedUrl];
    if (cachedUrl != null) return cachedUrl;

    final imageRepo = _imageRepo;
    if (imageRepo == null) {
      return normalizedUrl;
    }

    final uploadResult = await imageRepo.uploadImageFromUrl(normalizedUrl);
    return uploadResult.fold(
      (failure) => normalizedUrl,
      (supabaseUrl) {
        uploadedImageUrls[normalizedUrl] = supabaseUrl;
        return supabaseUrl;
      },
    );
  }

  bool _isSupabaseStorageUrl(String imageUrl) {
    return imageUrl.startsWith(supabaseUrl) &&
        imageUrl.contains('/storage/v1/object/public/');
  }

  bool _looksLikeHeader(List<Data?> row) {
    final firstCell = _cellToString(row, 0).toLowerCase();
    return firstCell == 'barcode' ||
        firstCell == 'bar code' ||
        firstCell == 'code' ||
        firstCell == 'كود' ||
        firstCell == 'باركود';
  }

  bool _stringRowLooksLikeHeader(List<String> row) {
    final firstCell = _stringCell(row, 0).toLowerCase();
    return firstCell == 'barcode' ||
        firstCell == 'bar code' ||
        firstCell == 'code' ||
        firstCell == 'كود' ||
        firstCell == 'باركود';
  }

  String _cellToString(List<Data?> row, int index) {
    if (index >= row.length) return '';
    final value = row[index]?.value;
    return switch (value) {
      null => '',
      TextCellValue() => value.value.toString().trim(),
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toStringAsFixed(0),
      BoolCellValue() => value.value.toString(),
      FormulaCellValue() => value.formula.trim(),
      DateCellValue() => value.toString(),
      DateTimeCellValue() => value.toString(),
      TimeCellValue() => value.toString(),
    };
  }

  DateTime? _cellToDate(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final value = row[index]?.value;
    return switch (value) {
      null => null,
      DateCellValue() => DateTime.tryParse(value.toString().trim()),
      DateTimeCellValue() => DateTime.tryParse(value.toString().trim()),
      TextCellValue() => _parseDate(value.value.toString()),
      FormulaCellValue() => DateTime.tryParse(value.formula.trim()),
      _ => null,
    };
  }

  num _cellToNum(List<Data?> row, int index) {
    if (index >= row.length) return 0;
    final value = row[index]?.value;
    return switch (value) {
      null => 0,
      IntCellValue() => value.value,
      DoubleCellValue() => value.value,
      TextCellValue() => _parseNum(value.value.toString()),
      FormulaCellValue() => num.tryParse(value.formula.trim()) ?? 0,
      BoolCellValue() => value.value ? 1 : 0,
      DateCellValue() => 0,
      DateTimeCellValue() => 0,
      TimeCellValue() => 0,
    };
  }

  List<List<String>> _readRowsFromXlsx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final workbookXml = _archiveText(archive, 'xl/workbook.xml');
    final workbookRelsXml = _archiveText(archive, 'xl/_rels/workbook.xml.rels');

    if (workbookXml == null || workbookRelsXml == null) return const [];

    final workbook = XmlDocument.parse(workbookXml);
    final rels = XmlDocument.parse(workbookRelsXml);
    final firstSheet = _firstOrNull(workbook.findAllElements('sheet'));
    if (firstSheet == null) return const [];

    final relationId = firstSheet.getAttribute(
          'id',
          namespace: 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
        ) ??
        firstSheet.getAttribute('r:id');
    if (relationId == null) return const [];

    final relationship = _firstOrNull(
      rels
          .findAllElements('Relationship')
          .where((node) => node.getAttribute('Id') == relationId),
    );
    final target = relationship?.getAttribute('Target');
    if (target == null) return const [];

    final sheetPath = _resolveXlsxPath('xl', target);
    final sheetXml = _archiveText(archive, sheetPath);
    if (sheetXml == null) return const [];

    final sharedStrings = _readSharedStrings(archive);
    final sheet = XmlDocument.parse(sheetXml);
    final parsedRows = <List<String>>[];

    for (final rowNode in sheet.findAllElements('row')) {
      final row = <String>[];
      var fallbackColumnIndex = 0;

      for (final cellNode in rowNode.findElements('c')) {
        final cellRef = cellNode.getAttribute('r');
        final columnIndex = cellRef == null
            ? fallbackColumnIndex
            : _cellRefColumnIndex(cellRef);

        while (row.length <= columnIndex) {
          row.add('');
        }

        row[columnIndex] = _readXlsxCell(cellNode, sharedStrings);
        fallbackColumnIndex = columnIndex + 1;
      }

      if (row.any((cell) => cell.trim().isNotEmpty)) {
        parsedRows.add(row);
      }
    }

    return parsedRows;
  }

  String? _archiveText(Archive archive, String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    if (!file.isFile) return null;
    file.decompress();
    return utf8.decode(file.content as List<int>, allowMalformed: true);
  }

  String _resolveXlsxPath(String baseDir, String target) {
    if (target.startsWith('/')) return target.substring(1);
    if (target.startsWith('xl/')) return target;
    return '$baseDir/$target';
  }

  List<String> _readSharedStrings(Archive archive) {
    final xml = _archiveText(archive, 'xl/sharedStrings.xml');
    if (xml == null) return const [];

    final document = XmlDocument.parse(xml);
    return document.findAllElements('si').map((node) {
      return node.findAllElements('t').map((text) => text.innerText).join();
    }).toList();
  }

  String _readXlsxCell(XmlElement cellNode, List<String> sharedStrings) {
    final type = cellNode.getAttribute('t');
    if (type == 'inlineStr') {
      return cellNode.findAllElements('t').map((node) => node.innerText).join();
    }

    final rawValue = _firstOrNull(cellNode.findElements('v'))?.innerText ?? '';
    if (type == 's') {
      final index = int.tryParse(rawValue);
      if (index == null || index < 0 || index >= sharedStrings.length) {
        return '';
      }
      return sharedStrings[index].trim();
    }

    return rawValue.trim();
  }

  int _cellRefColumnIndex(String cellRef) {
    var columnIndex = 0;
    for (final codeUnit in cellRef.toUpperCase().codeUnits) {
      if (codeUnit < 65 || codeUnit > 90) break;
      columnIndex = (columnIndex * 26) + (codeUnit - 64);
    }
    return columnIndex - 1;
  }

  String _stringCell(List<String> row, int index) {
    if (index >= row.length) return '';
    return row[index].trim();
  }

  num _stringCellToNum(List<String> row, int index) {
    return _parseNum(_stringCell(row, index));
  }

  DateTime? _stringCellToDate(List<String> row, int index) {
    return _parseDate(_stringCell(row, index));
  }

  num _parseNum(String value) {
    final normalized = value.trim().replaceAll(',', '');
    return num.tryParse(normalized) ?? 0;
  }

  DateTime? _parseDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;

    final parsedDate = DateTime.tryParse(normalized);
    if (parsedDate != null) return parsedDate;

    final serial = num.tryParse(normalized);
    if (serial == null || serial < 1) return null;
    return DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
  }

  bool _parseBool(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y' ||
        normalized == 'required' ||
        normalized == 'مطلوب' ||
        normalized == 'نعم';
  }

  String _normalizeHeader(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_\-]+'), '');
  }

  T? _firstOrNull<T>(Iterable<T> values) {
    final iterator = values.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
