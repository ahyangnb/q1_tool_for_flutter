import 'package:dart_style/dart_style.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cURL to Dart Tool',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CurlToDartConverter(),
    );
  }
}

class CurlToDartConverter extends StatefulWidget {
  @override
  _CurlToDartConverterState createState() => _CurlToDartConverterState();
}

class _CurlToDartConverterState extends State<CurlToDartConverter> {
  String curlCommand = '';
  String generatedDartCode = '';

  String _getRequestMethod() {
    // Extract the request method from the cURL command
    // Example: -X POST -> POST
    final RegExp methodRegex = RegExp(r"-X ([A-Z]+)");
    final match = methodRegex.firstMatch(curlCommand);
    return match?.group(1)?.toUpperCase() ?? 'GET';
  }

  String capitalizeFirstLetter(String input) {
    if (input.isEmpty) return input;

    return input[0].toUpperCase() + input.substring(1);
  }

  String lowercaseFirstLetter(String input) {
    if (input.isEmpty) return input;

    return input[0].toLowerCase() + input.substring(1);
  }

  String _generateClassName(String baseUrl, String methodLowerStr) {
    Uri uri = Uri.parse(baseUrl);

    // Define a regular expression pattern to match the desired part
    RegExp regex = RegExp(r'/([^/]+)/([^/]+)/([^/]+)/([^/]+)$');

    RegExpMatch regExpMatch = regex.firstMatch(uri.path)!;

    // Use the first capturing group from the matched result
    String extractedPart =
        "${capitalizeFirstLetter(regExpMatch.group(2)!)}${capitalizeFirstLetter(regExpMatch.group(3)!)}";

    return capitalizeFirstLetter(methodLowerStr) + extractedPart;
  }

  bool pathContainsParam(String path) {
    RegExp paramPattern = RegExp(
        r'/[a-f\d-]+$'); // Match UUID-like strings at the end of the path
    return paramPattern.hasMatch(path);
  }

  String extractParamValueFromPath(String path) {
    RegExp paramPattern = RegExp(
        r'/([a-f\d-]+)$'); // Match and capture UUID-like strings at the end of the path
    Match? match = paramPattern.firstMatch(path);
    return match?.group(1) ?? 'No param found';
  }

  void convertToDartCode() {
    final RegExp urlRegex = RegExp(r"'(https?://[^']+)'");
    final RegExp dataRegex = RegExp(r"--data-raw '([^']*)'");

    final RegExpMatch? urlMatch = urlRegex.firstMatch(curlCommand);
    if (urlMatch == null) {
      print("urlMatch == null");
      return;
    }

    final String baseUrl = urlMatch.group(1)!;
    final String methodLowerStr = _getRequestMethod().toLowerCase();

    final String className = _generateClassName(baseUrl, methodLowerStr);
    Uri uri = Uri.parse(baseUrl);
    String path = uri.path;

    final bool paramFromPath = pathContainsParam(path);
    if (paramFromPath) {
      path = "${path.replaceAll(extractParamValueFromPath(path), "")}\$id";
    }

    final Map<String, dynamic> data = {};

    print("data::${data.toString()}");

    dataRegex.allMatches(curlCommand).forEach((match) {
      data['data'] = match.group(1)!;
    });
    final String requestModelName = '${className}RequestModel';

    final String generatedCode = '''
class $requestModelName extends BaseRequest {
  ${paramFromPath ? "final String id;" : ""}

  $requestModelName(${paramFromPath ? "this.id," : ""});
  
  @override
  String url() => '$path';${data.isEmpty ? "" : """
  
  @override
  Map<String, dynamic> toJson() {
    return {}; 
  }"""}
}

Future<ResponseModel> ${lowercaseFirstLetter(className)}(BuildContext? context,{${paramFromPath ? "required final String id," : ""}}) async {
  return $requestModelName(${paramFromPath?"id":""}).sendApiAction(context, reqType: ReqType.$methodLowerStr)
      .then((rep) {
    // Parse the response using appropriate logic
    // Replace with your code to handle the response
    return ResponseModel.fromSuccess(rep);
  }).catchError((e) {
    return throwError(e);
  }).onError((error, stackTrace) {
    return onError(error, stackTrace);
  });
}
''';

    DartFormatter formatter = DartFormatter();
    setState(() {
      generatedDartCode = formatter.format(generatedCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                onChanged: (value) {
                  setState(() {
                    curlCommand = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Enter cURL Command',
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  convertToDartCode();
                },
                child: Text('Convert to Dart Code'),
              ),
              SizedBox(height: 16),
              Text(
                'Generated Dart Code:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(generatedDartCode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}