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
        // Normalize line endings to work on all platforms
        final rawCsvString = utf8.decode(bytes);
        final csvString = rawCsvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        
        debugPrint("Raw CSV Content: \n$csvString");

        // 3. Convert CSV String to a List of Lists
        List<List<dynamic>> csvData = const CsvToListConverter(
          eol: '\n', // Explicitly look for the newline character we just normalized
          shouldParseNumbers: true,
          allowInvalid: true,
        ).convert(csvString);
        
        debugPrint("CSV Data rows found: ${csvData.length}");

        List<Map<String, dynamic>> products = [];
        // We start from 0 if there's no header, but usually 1
        for (var i = 0; i < csvData.length; i++) {
          final row = csvData[i];
          
          // Skip the header row if it's the first one
          if (i == 0 && row[0].toString().toLowerCase().contains("name")) {
            debugPrint("Skipping header row");
            continue;
          }

          if (row.length >= 3) {
            products.add({
              'name': row[0].toString().trim(),
              'category': row[1].toString().trim(),
              'quantity': int.tryParse(row[2].toString()) ?? 0,
            });
          }
        }
        debugPrint("Successfully mapped ${products.length} products");
        return products;
      }
    } catch (e) {
      debugPrint("Error picking/parsing CSV: $e");
    }
    return null;
  }
}
