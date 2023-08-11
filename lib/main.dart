import 'dart:convert';

import 'package:dart_style/dart_style.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uri/uri.dart';

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

  Map<String, dynamic> extractQueryParams(String url) {
    Uri uri = Uri.parse(url);
    Map<String, dynamic> queryParams = {};

    uri.queryParameters.forEach((key, value) {
      queryParams[key] = value;
    });

    return queryParams;
  }

  Future convertToDartCode() async {
    final RegExp urlRegex = RegExp(r"'(https?://[^']+)'");
    final RegExp dataRegex = RegExp(r"--data-raw '([^']*)'");

    final RegExpMatch? urlMatch = urlRegex.firstMatch(curlCommand);
    if (urlMatch == null) {
      print("urlMatch == null");
      return;
    }

    final String baseUrl = urlMatch.group(1)!;
    final String methodLowerStr = _getRequestMethod().toLowerCase();

    Uri uri = Uri.parse(baseUrl);
    String path = uri.path;
    final pathSplit = path.split('/');
    final String className =
        "${capitalizeFirstLetter(pathSplit[pathSplit.length - 2])}${capitalizeFirstLetter(pathSplit.last)}";

    final bool paramFromPath = pathContainsParam(path);
    if (paramFromPath) {
      path = "${path.replaceAll(extractParamValueFromPath(path), "")}\$id";
    }

    // final Map<String, dynamic> data = {};

    print("curlCommand::$curlCommand");

    // dataRegex.allMatches(curlCommand).forEach((match) {
    //   data['data'] = match.group(1)!;
    // });

    Map<String, dynamic> queryParams = extractQueryParams(baseUrl);

    print('baseUrl : $baseUrl');
    print('queryParams : $queryParams');
    // print("data::${data.toString()}");

    final String requestModelName = '${className}RequestModel';

    final methodRecieve =
        ''',{${paramFromPath ? "required final String id," : ""}
${queryParams.isNotEmpty ? queryParams.keys.map((e) => 'required final ${queryParams[e].runtimeType} $e,').join('') : ""}}''';

    final String generatedCode = '''
class $requestModelName extends BaseRequest {
  ${paramFromPath ? "final String id;" : ""}
  ${queryParams.isNotEmpty ? queryParams.keys.map((e) {
              return "final String $e;";
            }).toList().join('') : ""}

  $requestModelName(${paramFromPath ? "this.id," : ""}${queryParams.isNotEmpty ? queryParams.keys.map((e) {
              return "this.$e,";
            }).toList().join('') : ""});
  
  @override
  String url() => '$path';${queryParams.isEmpty ? "" : """
  
  @override
  Map<String, dynamic> toJson() {
    return ${queryParams.isNotEmpty ? "{${queryParams.keys.map((e) => '"$e": this.$e,').join('')}}" : "{}"}; 
  }"""}
}

Future<ResponseModel> ${lowercaseFirstLetter(className)}(BuildContext? context${queryParams.isNotEmpty ? methodRecieve : ""}) async {
  return $requestModelName(${paramFromPath ? "id" : ""}
  ${queryParams.isNotEmpty ? queryParams.keys.map((e) => '$e,').join('') : ""}).sendApiAction(context, reqType: ReqType.$methodLowerStr)
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

    final classNameOfEntity =
        "${capitalizeFirstLetter(pathSplit[pathSplit.length - 2])}${capitalizeFirstLetter(pathSplit.last)}Entity";

    final modelString = await tryGetRsp(
        methodLowerStr, baseUrl, classNameOfEntity, {}, queryParams);

    DartFormatter formatter = DartFormatter();
    setState(() {
      try {
        String resultCode = generatedCode + modelString;
        if (modelString.isNotEmpty) {
          resultCode = resultCode.replaceAll('return ResponseModel.fromSuccess(rep);',
              '''
    $classNameOfEntity entity = $classNameOfEntity.fromJson(rep);
    return ResponseModel.fromSuccess(entity);''');
        }
        generatedDartCode = formatter.format(resultCode);
      } catch (e) {
        generatedDartCode = generatedCode;
      }
    });
  }

  String generateDartClass(String className, Map<String, dynamic> jsonMap) {
    StringBuffer buffer = StringBuffer();

    buffer.writeln('class $className {');

    jsonMap.forEach((key, value) {
      buffer.writeln('  final ${_getType(value)} $key;');
    });

    buffer.writeln('\n  $className({');

    jsonMap.forEach((key, value) {
      buffer.writeln('    required this.$key,');
    });

    buffer.writeln('  });\n');

    buffer
        .writeln('  factory $className.fromJson(Map<String, dynamic> json) {');
    buffer.writeln('    return $className(');

    jsonMap.forEach((key, value) {
      buffer.writeln('      $key: json[\'$key\'],');
    });

    buffer.writeln('    );');
    buffer.writeln('  }\n');

    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    return {');

    jsonMap.forEach((key, value) {
      buffer.writeln('      \'$key\': $key,');
    });

    buffer.writeln('    };');
    buffer.writeln('  }');

    buffer.writeln('}\n');

    return buffer.toString();
  }

  String _getType(dynamic value) {
    if (value is int) {
      return 'int';
    } else if (value is double) {
      return 'double';
    } else if (value is String) {
      return 'String';
    } else if (value is bool) {
      return 'bool';
    } else {
      return 'dynamic';
    }
  }

  Future<String> tryGetRsp(
      String methodLowerStr,
      String baseUrl,
      String classNameOfEntity,
      Map<String, dynamic>? headers,
      Map<String, dynamic> queryParams) async {
    try {
      Dio dio = Dio();
      Response rsp;
      dio.options.headers = headers;
      if (methodLowerStr == "get") {
        rsp = await dio.get(baseUrl,
            queryParameters: queryParams, data: queryParams);
      } else if (methodLowerStr == "post") {
        rsp = await dio.post(baseUrl, data: queryParams);
      } else {
        print("Unknown request type");
        return "";
      }
      print("REQUEST::RESPOSE::${json.encode(rsp.data)}");
      final data = rsp.data['data'];
      print("tryGetRsp::$data");

      return generateDartClass(classNameOfEntity, data);
    } catch (e) {
      print("tryGetRsp::error:$e");
      return "";
    }
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
