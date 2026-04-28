import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';

class CsvService {
  /// Opens a file picker and returns a list of product maps
  static Future<List<Map<String, dynamic>>?> pickAndParseCsv() async {
    try {
      // 1. Pick the file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // Required for web to get the bytes
      );

      if (result != null && result.files.single.bytes != null) {
        // 2. Decode the bytes to a String
        final bytes = result.files.single.bytes!;
        final csvString = utf8.decode(bytes);

        // 3. Convert CSV String to a List of Lists
        List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);

        // 4. Map the rows to our Product structure
        // We assume the first row is a header (Name, Category, Quantity)
        List<Map<String, dynamic>> products = [];
        for (var i = 1; i < csvData.length; i++) {
          final row = csvData[i];
          if (row.length >= 3) {
            products.add({
              'name': row[0].toString().trim(),
              'category': row[1].toString().trim(),
              'quantity': int.tryParse(row[2].toString()) ?? 0,
            });
          }
        }
        return products;
      }
    } catch (e) {
      debugPrint("Error picking/parsing CSV: $e");
    }
    return null;
  }
}
