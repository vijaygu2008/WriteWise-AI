import 'dart:convert';

import 'dart:math' as math;

import 'dart:ui' as ui;



import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:image_picker/image_picker.dart';



void main() {

  runApp(const WriteWiseAI());

}



// ================================================================

// APP

// ================================================================



class WriteWiseAI extends StatelessWidget {

  const WriteWiseAI({super.key});



  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: 'WriteWise AI',

      theme: ThemeData(

        useMaterial3: true,

        colorSchemeSeed: Colors.indigo,

        scaffoldBackgroundColor: const Color(0xFFF5F7FB),

      ),

      home: const HomePage(),

    );

  }

}



// ================================================================

// HOME PAGE

// ================================================================



class HomePage extends StatefulWidget {

  const HomePage({super.key});



  @override

  State<HomePage> createState() => _HomePageState();

}



class _HomePageState extends State<HomePage> {

  final ImagePicker _picker = ImagePicker();



  Uint8List? _imageBytes;



  double _imageWidth = 1;

  double _imageHeight = 1;



  bool _isProcessing = false;



  String _digitizedText = '';

  String _statusMessage = '';



  List<dynamic> _regions = [];



// ==============================================================

// API

// ==============================================================



  String get apiUrl {

    if (kIsWeb) {

      return 'http://127.0.0.1:8000/analyze';

    }




// Android Emulator -> Laptop

    return 'http://10.248.242.110:8000/analyze';

  }



// ==============================================================

// PICK IMAGE

// ==============================================================



  Future<void> _pickImage(ImageSource source) async {

    try {

      final XFile? file = await _picker.pickImage(

        source: source,

        imageQuality: 100,

      );



      if (file == null) {

        return;

      }



      final bytes = await file.readAsBytes();



      setState(() {

        _imageBytes = bytes;

        _digitizedText = '';

        _regions = [];

        _statusMessage = '';

      });



      await _loadImageSize(bytes);

    } catch (e) {

      debugPrint('IMAGE ERROR: $e');



      _showMessage(

        'Unable to select image.',

      );

    }

  }



// ==============================================================

// IMAGE SIZE

// ==============================================================



  Future<void> _loadImageSize(

      Uint8List bytes,

      ) async {

    try {

      final codec =

      await ui.instantiateImageCodec(bytes);



      final frame =

      await codec.getNextFrame();



      setState(() {

        _imageWidth =

            frame.image.width.toDouble();



        _imageHeight =

            frame.image.height.toDouble();

      });



      frame.image.dispose();

      codec.dispose();

    } catch (e) {

      debugPrint(

        'IMAGE SIZE ERROR: $e',

      );

    }

  }



// ==============================================================

// ANALYZE

// ==============================================================



  Future<void> _analyzeImage() async {

    if (_imageBytes == null) {

      _showMessage(

        'Please select a handwriting image first.',

      );

      return;

    }



    setState(() {

      _isProcessing = true;

      _digitizedText = '';

      _regions = [];

      _statusMessage =

      'Analyzing handwriting...';

    });



    try {

      debugPrint(

        'Sending image to: $apiUrl',

      );



      final request =

      http.MultipartRequest(

        'POST',

        Uri.parse(apiUrl),

      );



      request.files.add(

        http.MultipartFile.fromBytes(

          'file',

          _imageBytes!,

          filename: 'handwriting.jpg',

        ),

      );



      final streamedResponse =

      await request.send();



      final response =

      await http.Response.fromStream(

        streamedResponse,

      );



      debugPrint(

        'HTTP STATUS: ${response.statusCode}',

      );



      debugPrint(

        'SERVER RESPONSE: ${response.body}',

      );



      if (response.statusCode != 200) {

        throw Exception(

          'Server returned ${response.statusCode}',

        );

      }



      final data =

      jsonDecode(response.body);



      final rawRegions =

      data['regions'];



      setState(() {

        _digitizedText =

            data['final_text']

                ?.toString() ??

                '';



        if (rawRegions is List) {

// Preserve the model's original AI interpretation separately from later

// human edits so the comparison remains honest and visible.

          _regions = rawRegions.map((region) {

            if (region is Map) {

              final copy = Map<String, dynamic>.from(region);

              copy['ai_text'] ??= copy['final_text']?.toString() ?? '';

              return copy;

            }

            return region;

          }).toList();

        } else {

          _regions = [];

        }



        _statusMessage =

        _regions.isEmpty

            ? 'Analysis completed'

            : '${_regions.length} handwriting region(s) detected';

      });



      _showMessage(

        'Handwriting analysis completed.',

      );

    } catch (e) {

      debugPrint(

        'ANALYZE ERROR: $e',

      );



      setState(() {

        _statusMessage =

        'Analysis failed';

      });



      _showMessage(

        'Connection failed. Check FastAPI.',

      );

    } finally {

      setState(() {

        _isProcessing = false;

      });

    }

  }



// ==============================================================

// SNACKBAR

// ==============================================================



  void _showMessage(

      String message,

      ) {

    if (!mounted) {

      return;

    }



    ScaffoldMessenger.of(context)

        .showSnackBar(

      SnackBar(

        content: Text(message),

        behavior:

        SnackBarBehavior.floating,

      ),

    );

  }



// ==============================================================

// CONFIDENCE

// ==============================================================



  double _getConfidence(

      dynamic region,

      ) {

    final value =

    region['confidence'];



    if (value is num) {

      return value.toDouble();

    }



    final percent =

    region['confidence_percent'];



    if (percent is num) {

      return percent.toDouble() / 100;

    }



    return 0;

  }



// ==============================================================

// REGION COLOR

// ==============================================================



  Color _getRegionColor(

      dynamic region,

      ) {

    final confidence =

    _getConfidence(region);



    final uncertain =

        region['uncertain'] == true;



    final status =

        region['status']

            ?.toString()

            .toUpperCase() ??

            '';



    if (confidence < 0.70 ||

        status.contains('HIGH') ||

        status.contains('VERY')) {

      return Colors.red;

    }



    if (uncertain ||

        status.contains('VERIFY') ||

        confidence < 0.80) {

      return Colors.orange;

    }



    return Colors.green;

  }



// ==============================================================

// IMAGE WITH CLICKABLE BOXES

// ==============================================================



  Widget _buildImageWithBoundingBoxes() {

    if (_imageBytes == null) {

      return const SizedBox.shrink();

    }



    return LayoutBuilder(

      builder: (

          context,

          constraints,

          ) {

        final availableWidth =

            constraints.maxWidth;



        if (availableWidth <= 0 ||

            _imageWidth <= 0 ||

            _imageHeight <= 0) {

          return const SizedBox.shrink();

        }



        final naturalHeight =

            availableWidth *

                (_imageHeight /

                    _imageWidth);



        final displayHeight =

        math.min(

          430.0,

          naturalHeight,

        );



        final scale =

        math.min(

          availableWidth /

              _imageWidth,

          displayHeight /

              _imageHeight,

        );



        final displayWidth =

            _imageWidth * scale;



        final actualHeight =

            _imageHeight * scale;



        return Center(

          child: SizedBox(

            width: displayWidth,

            height: actualHeight,

            child: Stack(

              fit: StackFit.expand,

              children: [

// ORIGINAL IMAGE

                Image.memory(

                  _imageBytes!,

                  fit: BoxFit.fill,

                ),



// CLICKABLE OVERLAY

                GestureDetector(

                  behavior:

                  HitTestBehavior.translucent,

                  onTapUp: (details) {

                    _handleRegionTap(

                      details.localPosition,

                      displayWidth,

                      actualHeight,

                    );

                  },

                  child: CustomPaint(

                    painter:

                    HandwritingBoxPainter(

                      regions: _regions,

                      imageWidth:

                      _imageWidth,

                      imageHeight:

                      _imageHeight,

                    ),

                  ),

                ),

              ],

            ),

          ),

        );

      },

    );

  }



// ==============================================================

// TAP REGION

// ==============================================================



  void _handleRegionTap(

      Offset position,

      double displayWidth,

      double displayHeight,

      ) {

    if (_regions.isEmpty) {

      return;

    }



    final scaleX =

        _imageWidth /

            displayWidth;



    final scaleY =

        _imageHeight /

            displayHeight;



    final imageX =

        position.dx * scaleX;



    final imageY =

        position.dy * scaleY;



    for (int i = 0;

    i < _regions.length;

    i++) {

      final region =

      _regions[i];



      if (region is! Map) {

        continue;

      }



      final rect =

      _extractRect(

        region['box'],

      );



      if (rect == null) {

        continue;

      }



      if (rect.contains(

        Offset(

          imageX,

          imageY,

        ),

      )) {

        _openRegionVerification(

          region,

          i,

        );



        return;

      }

    }

  }



// ==============================================================

// EXTRACT RECTANGLE

// ==============================================================



  Rect? _extractRect(

      dynamic box,

      ) {

    if (box == null) {

      return null;

    }



// [x1,y1,x2,y2]



    if (box is List &&

        box.length >= 4 &&

        box[0] is num &&

        box[1] is num &&

        box[2] is num &&

        box[3] is num) {

      final x1 =

      (box[0] as num).toDouble();



      final y1 =

      (box[1] as num).toDouble();



      final x2 =

      (box[2] as num).toDouble();



      final y2 =

      (box[3] as num).toDouble();



      return Rect.fromLTRB(

        math.min(x1, x2),

        math.min(y1, y2),

        math.max(x1, x2),

        math.max(y1, y2),

      );

    }



// Polygon



    if (box is List &&

        box.isNotEmpty) {

      final points =

      <Offset>[];



      for (final point in box) {

        if (point is List &&

            point.length >= 2 &&

            point[0] is num &&

            point[1] is num) {

          points.add(

            Offset(

              (point[0] as num)

                  .toDouble(),

              (point[1] as num)

                  .toDouble(),

            ),

          );

        }

      }



      if (points.isNotEmpty) {

        double minX =

            points.first.dx;



        double maxX =

            points.first.dx;



        double minY =

            points.first.dy;



        double maxY =

            points.first.dy;



        for (final point

        in points) {

          minX = math.min(

            minX,

            point.dx,

          );



          maxX = math.max(

            maxX,

            point.dx,

          );



          minY = math.min(

            minY,

            point.dy,

          );



          maxY = math.max(

            maxY,

            point.dy,

          );

        }



        return Rect.fromLTRB(

          minX,

          minY,

          maxX,

          maxY,

        );

      }

    }



    return null;

  }



// ==============================================================

// OPEN REGION VERIFICATION

// ==============================================================



  void _openRegionVerification(

      dynamic region,

      int index,

      ) {

    final confidence =

    _getConfidence(region);



    final color =

    _getRegionColor(region);



    final ocrText =

        region['ocr_text']

            ?.toString() ??

            '';



    final finalText =

        region['final_text']

            ?.toString() ??

            '';



    final aiText =

        region['ai_text']?.toString() ?? finalText;



    final humanVerified =

        region['status']?.toString().toUpperCase() == 'HUMAN_VERIFIED';



    final candidates =

    region['candidates'];



    String initialText =

    finalText.isNotEmpty

        ? finalText

        : ocrText;



    final controller =

    TextEditingController(

      text: initialText,

    );



    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor:

      Colors.transparent,

      builder: (context) {

        return Container(

          decoration:

          const BoxDecoration(

            color: Colors.white,

            borderRadius:

            BorderRadius.vertical(

              top: Radius.circular(28),

            ),

          ),

          padding: EdgeInsets.only(

            left: 20,

            right: 20,

            top: 20,

            bottom:

            MediaQuery.of(context)

                .viewInsets

                .bottom +

                20,

          ),

          child:

          SingleChildScrollView(

            child: Column(

              crossAxisAlignment:

              CrossAxisAlignment.start,

              children: [

// HEADER

                Row(

                  children: [

                    Container(

                      width: 42,

                      height: 42,

                      alignment:

                      Alignment.center,

                      decoration:

                      BoxDecoration(

                        color: color,

                        shape:

                        BoxShape.circle,

                      ),

                      child: Text(

                        '${index + 1}',

                        style:

                        const TextStyle(

                          color:

                          Colors.white,

                          fontWeight:

                          FontWeight.bold,

                          fontSize: 18,

                        ),

                      ),

                    ),



                    const SizedBox(

                      width: 12,

                    ),



                    const Expanded(

                      child: Text(

                        'Verification Required',

                        style:

                        TextStyle(

                          fontSize: 21,

                          fontWeight:

                          FontWeight.bold,

                        ),

                      ),

                    ),



                    IconButton(

                      onPressed: () {

                        Navigator.pop(

                            context);

                      },

                      icon: const Icon(

                        Icons.close,

                      ),

                    ),

                  ],

                ),



                const SizedBox(

                  height: 15,

                ),



// CONFIDENCE

                Container(

                  width:

                  double.infinity,

                  padding:

                  const EdgeInsets.all(

                    14,

                  ),

                  decoration:

                  BoxDecoration(

                    color: color

                        .withValues(

                      alpha: 0.08,

                    ),

                    borderRadius:

                    BorderRadius

                        .circular(

                      14,

                    ),

                    border:

                    Border.all(

                      color: color

                          .withValues(

                        alpha: 0.3,

                      ),

                    ),

                  ),

                  child: Row(

                    children: [

                      Icon(

                        Icons.warning_amber,

                        color: color,

                      ),

                      const SizedBox(

                        width: 10,

                      ),

                      Expanded(

                        child: Text(

                          confidence <

                              0.70

                              ? 'Highly uncertain handwriting'

                              : 'This region needs verification',

                          style:

                          TextStyle(

                            color: color,

                            fontWeight:

                            FontWeight

                                .bold,

                          ),

                        ),

                      ),

                      Text(

                        '${(confidence * 100).toStringAsFixed(1)}%',

                        style:

                        TextStyle(

                          color: color,

                          fontWeight:

                          FontWeight.bold,

                          fontSize: 17,

                        ),

                      ),

                    ],

                  ),

                ),



                const SizedBox(

                  height: 18,

                ),



// OCR TEXT

                const Text(

                  'Original OCR',

                  style:

                  TextStyle(

                    fontWeight:

                    FontWeight.bold,

                    fontSize: 14,

                  ),

                ),



                const SizedBox(

                  height: 6,

                ),



                Container(

                  width:

                  double.infinity,

                  padding:

                  const EdgeInsets.all(

                    12,

                  ),

                  decoration:

                  BoxDecoration(

                    color:

                    Colors.grey.shade100,

                    borderRadius:

                    BorderRadius

                        .circular(

                      12,

                    ),

                  ),

                  child: Text(

                    ocrText.isEmpty

                        ? 'No OCR text'

                        : ocrText,

                    style:

                    const TextStyle(

                      fontSize: 14,

                    ),

                  ),

                ),



                const SizedBox(

                  height: 18,

                ),



// AI TEXT

                const Text(

                  'AI Interpretation',

                  style:

                  TextStyle(

                    fontWeight:

                    FontWeight.bold,

                    fontSize: 14,

                  ),

                ),



                const SizedBox(

                  height: 6,

                ),



                Container(

                  width:

                  double.infinity,

                  padding:

                  const EdgeInsets.all(

                    12,

                  ),

                  decoration:

                  BoxDecoration(

                    color:

                    Colors.indigo.shade50,

                    borderRadius:

                    BorderRadius

                        .circular(

                      12,

                    ),

                  ),

                  child: Text(

                    aiText.isEmpty

                        ? 'No AI interpretation'

                        : aiText,

                    style:

                    const TextStyle(

                      fontSize: 14,

                    ),

                  ),

                ),



                if (humanVerified) ...[

                  const SizedBox(height: 18),

                  const Text(

                    'Human-Verified Text',

                    style: TextStyle(

                      fontWeight: FontWeight.bold,

                      fontSize: 14,

                    ),

                  ),

                  const SizedBox(height: 6),

                  Container(

                    width: double.infinity,

                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(

                      color: Colors.green.shade50,

                      borderRadius: BorderRadius.circular(12),

                      border: Border.all(color: Colors.green.shade200),

                    ),

                    child: Text(

                      finalText.isEmpty ? 'No verified text' : finalText,

                      style: const TextStyle(fontSize: 14),

                    ),

                  ),

                ],



// CANDIDATES

                if (candidates is List &&

                    candidates.isNotEmpty) ...[

                  const SizedBox(

                    height: 18,

                  ),



                  const Text(

                    'AI Suggestions',

                    style:

                    TextStyle(

                      fontWeight:

                      FontWeight.bold,

                      fontSize: 14,

                    ),

                  ),



                  const SizedBox(

                    height: 8,

                  ),



                  ...List.generate(

                    math.min(

                      candidates.length,

                      5,

                    ),

                        (candidateIndex) {

                      final candidate =

                      candidates[

                      candidateIndex];



                      final text =

                      candidate

                          .toString();



                      return InkWell(

                        onTap: () {

                          controller

                              .text =

                              text;



                          controller.selection =

                              TextSelection

                                  .fromPosition(

                                TextPosition(

                                  offset:

                                  controller

                                      .text

                                      .length,

                                ),

                              );

                        },

                        child:

                        Container(

                          width:

                          double.infinity,

                          margin:

                          const EdgeInsets

                              .only(

                            bottom: 7,

                          ),

                          padding:

                          const EdgeInsets

                              .all(

                            11,

                          ),

                          decoration:

                          BoxDecoration(

                            border:

                            Border.all(

                              color: Colors

                                  .indigo

                                  .shade100,

                            ),

                            borderRadius:

                            BorderRadius

                                .circular(

                              10,

                            ),

                          ),

                          child:

                          Text(

                            '${candidateIndex + 1}. $text',

                            style:

                            const TextStyle(

                              fontSize:

                              13,

                            ),

                          ),

                        ),

                      );

                    },

                  ),

                ],



                const SizedBox(

                  height: 18,

                ),



// EDIT

                const Text(

                  'Correct the text',

                  style:

                  TextStyle(

                    fontWeight:

                    FontWeight.bold,

                    fontSize: 14,

                  ),

                ),



                const SizedBox(

                  height: 8,

                ),



                TextField(

                  controller:

                  controller,

                  maxLines: 4,

                  decoration:

                  InputDecoration(

                    hintText:

                    'Enter the correct handwriting...',

                    border:

                    OutlineInputBorder(

                      borderRadius:

                      BorderRadius

                          .circular(

                        14,

                      ),

                    ),

                  ),

                ),



                const SizedBox(

                  height: 18,

                ),



// SAVE

                SizedBox(

                  width:

                  double.infinity,

                  height: 50,

                  child:

                  ElevatedButton.icon(

                    onPressed: () {

                      final corrected =

                      controller

                          .text

                          .trim();



                      if (corrected

                          .isEmpty) {

                        return;

                      }



                      _updateRegionText(

                        index,

                        corrected,

                      );



                      Navigator.pop(

                        context,

                      );



                      _showMessage(

                        'Region ${index + 1} corrected successfully.',

                      );

                    },

                    icon: const Icon(

                      Icons.check,

                    ),

                    label:

                    const Text(

                      'Save Correction',

                    ),

                  ),

                ),

              ],

            ),

          ),

        );

      },

    );

  }



// ==============================================================

// UPDATE REGION

// ==============================================================



  void _updateRegionText(

      int index,

      String correctedText,

      ) {

    if (index < 0 ||

        index >= _regions.length) {

      return;

    }



    final updated =

    Map<String, dynamic>.from(

      _regions[index],

    );



    updated['final_text'] =

        correctedText;



    updated['uncertain'] =

    false;



    updated['status'] =

    'HUMAN_VERIFIED';



    updated['confidence'] =

    1.0;



    setState(() {

      _regions[index] =

          updated;



      _rebuildFinalText();

    });

  }



// ==============================================================

// REBUILD FINAL TEXT

// ==============================================================



  void _rebuildFinalText() {

    final verifiedTexts =

    <String>[];



    for (final region

    in _regions) {

      if (region is Map) {

        final text =

            region['final_text']

                ?.toString()

                .trim() ??

                '';



        if (text.isNotEmpty) {

          verifiedTexts.add(

            text,

          );

        }

      }

    }



    if (verifiedTexts.isNotEmpty) {

      _digitizedText =

          verifiedTexts.join(' ');

    }

  }



// ==============================================================

// SAVE FINAL TEXT

// ==============================================================



  void _saveVerifiedText() {

    if (_digitizedText

        .trim()

        .isEmpty) {

      _showMessage(

        'There is no text to save.',

      );

      return;

    }



    _showMessage(

      'Verified text saved successfully.',

    );

  }



// ==============================================================

// FULL TEXT VERIFICATION

// ==============================================================



  void _openFullVerification() {

    final controller =

    TextEditingController(

      text: _digitizedText,

    );



    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor:

      Colors.transparent,

      builder: (context) {

        return Container(

          decoration:

          const BoxDecoration(

            color: Colors.white,

            borderRadius:

            BorderRadius.vertical(

              top: Radius.circular(28),

            ),

          ),

          padding: EdgeInsets.only(

            left: 20,

            right: 20,

            top: 20,

            bottom:

            MediaQuery.of(context)

                .viewInsets

                .bottom +

                20,

          ),

          child:

          SingleChildScrollView(

            child: Column(

              crossAxisAlignment:

              CrossAxisAlignment.start,

              children: [

                Row(

                  children: [

                    const Expanded(

                      child: Text(

                        'Human Verification',

                        style:

                        TextStyle(

                          fontSize: 21,

                          fontWeight:

                          FontWeight.bold,

                        ),

                      ),

                    ),

                    IconButton(

                      onPressed: () {

                        Navigator.pop(

                            context);

                      },

                      icon: const Icon(

                        Icons.close,

                      ),

                    ),

                  ],

                ),



                const SizedBox(

                  height: 8,

                ),



                Text(

                  'Review and correct the complete AI result before saving.',

                  style: TextStyle(

                    color:

                    Colors.grey.shade600,

                  ),

                ),



                const SizedBox(

                  height: 18,

                ),



                TextField(

                  controller:

                  controller,

                  maxLines: 10,

                  decoration:

                  InputDecoration(

                    labelText:

                    'Verified Text',

                    alignLabelWithHint:

                    true,

                    border:

                    OutlineInputBorder(

                      borderRadius:

                      BorderRadius

                          .circular(

                        14,

                      ),

                    ),

                  ),

                ),



                const SizedBox(

                  height: 15,

                ),



                SizedBox(

                  width:

                  double.infinity,

                  height: 50,

                  child:

                  ElevatedButton.icon(

                    onPressed: () {

                      setState(() {

                        _digitizedText =

                            controller

                                .text

                                .trim();

                      });



                      Navigator.pop(

                          context);



                      _showMessage(

                        'Verified text saved successfully.',

                      );

                    },

                    icon: const Icon(

                      Icons.check,

                    ),

                    label:

                    const Text(

                      'Confirm & Save',

                    ),

                  ),

                ),

              ],

            ),

          ),

        );

      },

    );

  }



// ==============================================================

// IMAGE SECTION

// ==============================================================



  Widget _buildImageSection() {

    if (_imageBytes == null) {

      return Container(

        width: double.infinity,

        padding:

        const EdgeInsets.all(

          35,

        ),

        decoration:

        BoxDecoration(

          color: Colors.white,

          borderRadius:

          BorderRadius.circular(

            20,

          ),

          border:

          Border.all(

            color:

            Colors.indigo.shade100,

            width: 1.5,

          ),

        ),

        child: Column(

          children: [

            Icon(

              Icons

                  .document_scanner_outlined,

              size: 65,

              color:

              Colors.indigo.shade400,

            ),

            const SizedBox(

              height: 15,

            ),

            const Text(

              'No handwriting selected',

              style:

              TextStyle(

                fontSize: 18,

                fontWeight:

                FontWeight.bold,

              ),

            ),

            const SizedBox(

              height: 8,

            ),

            Text(

              'Upload or capture difficult handwriting.',

              textAlign:

              TextAlign.center,

              style: TextStyle(

                color:

                Colors.grey.shade600,

              ),

            ),

          ],

        ),

      );

    }



    return Container(

      width: double.infinity,

      padding:

      const EdgeInsets.all(

        12,

      ),

      decoration:

      BoxDecoration(

        color: Colors.white,

        borderRadius:

        BorderRadius.circular(

          20,

        ),

        border:

        Border.all(

          color:

          Colors.indigo.shade100,

        ),

      ),

      child: Column(

        crossAxisAlignment:

        CrossAxisAlignment.start,

        children: [

          const Padding(

            padding:

            EdgeInsets.only(

              left: 5,

              bottom: 10,

            ),

            child: Text(

              'Handwriting Analysis',

              style:

              TextStyle(

                fontSize: 17,

                fontWeight:

                FontWeight.bold,

              ),

            ),

          ),



          ClipRRect(

            borderRadius:

            BorderRadius.circular(

              14,

            ),

            child:

            _buildImageWithBoundingBoxes(),

          ),



          if (_regions.isNotEmpty) ...[

            const SizedBox(

              height: 12,

            ),

            _buildLegend(),

          ],

        ],

      ),

    );

  }



// ==============================================================

// LEGEND

// ==============================================================



  Widget _buildLegend() {

    return Wrap(

      spacing: 14,

      runSpacing: 8,

      children: [

        _legendItem(

          Colors.green,

          'Accepted',

        ),

        _legendItem(

          Colors.orange,

          'Verify',

        ),

        _legendItem(

          Colors.red,

          'Highly Uncertain',

        ),

      ],

    );

  }



  Widget _legendItem(

      Color color,

      String text,

      ) {

    return Row(

      mainAxisSize:

      MainAxisSize.min,

      children: [

        Container(

          width: 14,

          height: 14,

          decoration:

          BoxDecoration(

            color: color,

            borderRadius:

            BorderRadius.circular(

              4,

            ),

          ),

        ),

        const SizedBox(

          width: 6,

        ),

        Text(

          text,

          style:

          const TextStyle(

            fontSize: 12,

            fontWeight:

            FontWeight.w600,

          ),

        ),

      ],

    );

  }



// ==============================================================

// ANALYSIS SUMMARY

// ==============================================================



  Widget _buildAnalysisSummary() {

    if (_regions.isEmpty) {

      return const SizedBox.shrink();

    }



    int highConfidence = 0;

    int needsVerification = 0;

    int humanVerified = 0;



    for (final region in _regions) {

      if (region is! Map) continue;



      final status = region['status']?.toString().toUpperCase() ?? '';

      final uncertain = region['uncertain'] == true;

      final confidence = _getConfidence(region);



      if (status == 'HUMAN_VERIFIED') {

        humanVerified++;

      } else if (uncertain || status.contains('VERIFY') ||

          status.contains('HIGH') || confidence < 0.80) {

        needsVerification++;

      } else {

        highConfidence++;

      }

    }



    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.indigo.shade100),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Icon(Icons.analytics_outlined, color: Colors.indigo.shade600),

              const SizedBox(width: 8),

              const Text(

                'Analysis Summary',

                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),

              ),

            ],

          ),

          const SizedBox(height: 15),

          Row(

            children: [

              Expanded(child: _summaryCard('${_regions.length}', 'Regions', Colors.indigo, Icons.text_fields)),

              const SizedBox(width: 8),

              Expanded(child: _summaryCard('$highConfidence', 'High Confidence', Colors.green, Icons.check_circle_outline)),

            ],

          ),

          const SizedBox(height: 8),

          Row(

            children: [

              Expanded(child: _summaryCard('$needsVerification', 'Needs Verify', Colors.orange, Icons.warning_amber_outlined)),

              const SizedBox(width: 8),

              Expanded(child: _summaryCard('$humanVerified', 'Human Verified', Colors.blue, Icons.verified_outlined)),

            ],

          ),

        ],

      ),

    );

  }



  Widget _summaryCard(String value, String label, Color color, IconData icon) {

    return Container(

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(

        color: color.withValues(alpha: 0.07),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: color.withValues(alpha: 0.22)),

      ),

      child: Column(

        children: [

          Icon(icon, color: color, size: 22),

          const SizedBox(height: 5),

          Text(value, style: TextStyle(color: color, fontSize: 21, fontWeight: FontWeight.bold)),

          const SizedBox(height: 2),

          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),

        ],

      ),

    );

  }



// ==============================================================

// ORIGINAL vs AI vs HUMAN-VERIFIED COMPARISON

// ================================================================



  Widget _buildComparisonSection() {

    if (_regions.isEmpty) {

      return const SizedBox.shrink();

    }



    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.indigo.shade100),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Icon(Icons.compare_arrows, color: Colors.indigo.shade600),

              const SizedBox(width: 8),

              const Expanded(

                child: Text(

                  'Original vs AI vs Verified',

                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),

                ),

              ),

            ],

          ),

          const SizedBox(height: 6),

          Text(

            'Compare each region and check which text still needs human review.',

            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),

          ),

          const SizedBox(height: 15),

          ...List.generate(_regions.length, (index) {

            final region = _regions[index];

            if (region is! Map) return const SizedBox.shrink();

            final original = region['ocr_text']?.toString() ?? '';

            final ai = region['ai_text']?.toString() ?? region['final_text']?.toString() ?? '';

            final finalText = region['final_text']?.toString() ?? '';

            final verified = region['status']?.toString().toUpperCase() == 'HUMAN_VERIFIED';

            final confidence = _getConfidence(region);

            final statusColor = verified ? Colors.green : _getRegionColor(region);



            Widget comparisonRow(String label, String value, Color color, IconData icon) {

              return Container(

                width: double.infinity,

                margin: const EdgeInsets.only(top: 8),

                padding: const EdgeInsets.all(11),

                decoration: BoxDecoration(

                  color: color.withValues(alpha: 0.06),

                  borderRadius: BorderRadius.circular(10),

                  border: Border.all(color: color.withValues(alpha: 0.22)),

                ),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Row(

                      children: [

                        Icon(icon, size: 16, color: color),

                        const SizedBox(width: 6),

                        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),

                      ],

                    ),

                    const SizedBox(height: 5),

                    Text(value.isEmpty ? 'No text available' : value, style: const TextStyle(fontSize: 14, height: 1.35)),

                  ],

                ),

              );

            }



            return Container(

              margin: const EdgeInsets.only(bottom: 14),

              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(

                color: const Color(0xFFFAFBFF),

                borderRadius: BorderRadius.circular(14),

                border: Border.all(color: Colors.indigo.shade50),

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(

                    children: [

                      Expanded(child: Text('Region ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),

                      if (verified)

                        const Text('HUMAN VERIFIED', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold))

                      else

                        Text('${(confidence * 100).toStringAsFixed(1)}% confidence', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),

                    ],

                  ),

                  comparisonRow('ORIGINAL OCR', original, Colors.blueGrey, Icons.text_fields),

                  comparisonRow('AI INTERPRETATION', ai, Colors.indigo, Icons.auto_awesome),

                  if (verified)

                    comparisonRow('HUMAN-VERIFIED TEXT', finalText, Colors.green, Icons.verified),

                  if (!verified)

                    Align(

                      alignment: Alignment.centerRight,

                      child: TextButton.icon(

                        onPressed: () => _openRegionVerification(region, index),

                        icon: const Icon(Icons.edit, size: 16),

                        label: const Text('Review this region'),

                      ),

                    ),

                ],

              ),

            );

          }),

        ],

      ),

    );

  }



// ================================================================

// RESULT SECTION

// ================================================================



  Widget _buildResultSection() {

    if (_digitizedText

        .trim()

        .isEmpty) {

      return const SizedBox.shrink();

    }



    final uncertainCount =

        _regions.where(

              (region) {

            if (region is! Map) {

              return false;

            }



            return region['uncertain'] ==

                true;

          },

        ).length;



    return Container(

      width: double.infinity,

      padding:

      const EdgeInsets.all(

        18,

      ),

      decoration:

      BoxDecoration(

        color: Colors.white,

        borderRadius:

        BorderRadius.circular(

          20,

        ),

        border:

        Border.all(

          color:

          Colors.indigo.shade100,

        ),

      ),

      child: Column(

        crossAxisAlignment:

        CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Icon(

                Icons.auto_awesome,

                color:

                Colors.indigo.shade600,

              ),

              const SizedBox(

                width: 8,

              ),

              const Text(

                'AI Digitized Text',

                style:

                TextStyle(

                  fontSize: 18,

                  fontWeight:

                  FontWeight.bold,

                ),

              ),

            ],

          ),



          const SizedBox(

            height: 15,

          ),



          Container(

            width: double.infinity,

            padding:

            const EdgeInsets.all(

              15,

            ),

            decoration:

            BoxDecoration(

              color:

              const Color(

                0xFFF5F7FF,

              ),

              borderRadius:

              BorderRadius.circular(

                14,

              ),

            ),

            child: Text(

              _digitizedText,

              style:

              const TextStyle(

                fontSize: 16,

                height: 1.6,

              ),

            ),

          ),



          const SizedBox(

            height: 12,

          ),



          if (uncertainCount > 0)

            Container(

              width:

              double.infinity,

              padding:

              const EdgeInsets.all(

                12,

              ),

              decoration:

              BoxDecoration(

                color:

                Colors.orange.withValues(

                  alpha: 0.08,

                ),

                borderRadius:

                BorderRadius.circular(

                  12,

                ),

                border:

                Border.all(

                  color:

                  Colors.orange.withValues(

                    alpha: 0.3,

                  ),

                ),

              ),

              child: Row(

                children: [

                  const Icon(

                    Icons.warning_amber,

                    color:

                    Colors.orange,

                  ),

                  const SizedBox(

                    width: 8,

                  ),

                  Expanded(

                    child: Text(

                      '$uncertainCount region(s) require human verification.',

                      style:

                      const TextStyle(

                        fontWeight:

                        FontWeight.w600,

                      ),

                    ),

                  ),

                ],

              ),

            ),



          const SizedBox(

            height: 15,

          ),



          SizedBox(

            width: double.infinity,

            child:

            ElevatedButton.icon(

              onPressed:

              _openFullVerification,

              icon: const Icon(

                Icons.edit,

              ),

              label:

              const Text(

                'Verify & Edit Full Text',

              ),

            ),

          ),



          const SizedBox(

            height: 8,

          ),



          SizedBox(

            width: double.infinity,

            child:

            OutlinedButton.icon(

              onPressed:

              _saveVerifiedText,

              icon: const Icon(

                Icons.save,

              ),

              label:

              const Text(

                'Save Verified Text',

              ),

            ),

          ),

        ],

      ),

    );

  }



// ==============================================================

// REGION LIST

// ==============================================================



  Widget _buildRegionResults() {

    if (_regions.isEmpty) {

      return const SizedBox.shrink();

    }



    return Container(

      width: double.infinity,

      padding:

      const EdgeInsets.all(

        18,

      ),

      decoration:

      BoxDecoration(

        color: Colors.white,

        borderRadius:

        BorderRadius.circular(

          20,

        ),

        border:

        Border.all(

          color:

          Colors.indigo.shade100,

        ),

      ),

      child: Column(

        crossAxisAlignment:

        CrossAxisAlignment.start,

        children: [

          const Text(

            'Recognition Regions',

            style:

            TextStyle(

              fontSize: 18,

              fontWeight:

              FontWeight.bold,

            ),

          ),



          const SizedBox(

            height: 6,

          ),



          Text(

            'Tap an orange or red region on the image to verify it.',

            style: TextStyle(

              color:

              Colors.grey.shade600,

              fontSize: 13,

            ),

          ),



          const SizedBox(

            height: 15,

          ),



          ...List.generate(

            _regions.length,

                (index) {

              return _buildRegionCard(

                _regions[index],

                index,

              );

            },

          ),

        ],

      ),

    );

  }



// ==============================================================

// REGION CARD

// ==============================================================



  Widget _buildRegionCard(

      dynamic region,

      int index,

      ) {

    final confidence =

    _getConfidence(region);



    final color =

    _getRegionColor(region);



    final uncertain =

        region['uncertain'] == true;



    String label;



    if (confidence < 0.70) {

      label = 'HIGHLY UNCERTAIN';

    } else if (uncertain ||

        confidence < 0.80) {

      label = 'VERIFY';

    } else {

      label = 'ACCEPTED';

    }



    final ocrText =

        region['ocr_text']

            ?.toString() ??

            '';



    final finalText =

        region['final_text']

            ?.toString() ??

            '';



    return InkWell(

      onTap: () {

        _openRegionVerification(

          region,

          index,

        );

      },

      borderRadius:

      BorderRadius.circular(

        14,

      ),

      child: Container(

        margin:

        const EdgeInsets.only(

          bottom: 12,

        ),

        padding:

        const EdgeInsets.all(

          14,

        ),

        decoration:

        BoxDecoration(

          color:

          color.withValues(

            alpha: 0.06,

          ),

          borderRadius:

          BorderRadius.circular(

            14,

          ),

          border:

          Border.all(

            color:

            color.withValues(

              alpha: 0.35,

            ),

          ),

        ),

        child: Column(

          crossAxisAlignment:

          CrossAxisAlignment.start,

          children: [

            Row(

              children: [

                Container(

                  width: 30,

                  height: 30,

                  alignment:

                  Alignment.center,

                  decoration:

                  BoxDecoration(

                    color: color,

                    shape:

                    BoxShape.circle,

                  ),

                  child: Text(

                    '${index + 1}',

                    style:

                    const TextStyle(

                      color:

                      Colors.white,

                      fontWeight:

                      FontWeight.bold,

                    ),

                  ),

                ),



                const SizedBox(

                  width: 10,

                ),



                Expanded(

                  child: Text(

                    label,

                    style:

                    TextStyle(

                      color: color,

                      fontWeight:

                      FontWeight.bold,

                    ),

                  ),

                ),



                Text(

                  '${(confidence * 100).toStringAsFixed(1)}%',

                  style:

                  TextStyle(

                    color: color,

                    fontWeight:

                    FontWeight.bold,

                  ),

                ),

              ],

            ),



            const SizedBox(

              height: 12,

            ),



            Text(

              'OCR: $ocrText',

              style:

              const TextStyle(

                fontSize: 14,

              ),

            ),



            if (finalText

                .isNotEmpty) ...[

              const SizedBox(

                height: 5,

              ),

              Text(

                'AI: $finalText',

                style:

                const TextStyle(

                  fontSize: 14,

                  fontWeight:

                  FontWeight.w600,

                ),

              ),

            ],



            const SizedBox(

              height: 8,

            ),



            Row(

              children: [

                Icon(

                  Icons.touch_app,

                  size: 16,

                  color: color,

                ),

                const SizedBox(

                  width: 5,

                ),

                Text(

                  'Tap to verify',

                  style:

                  TextStyle(

                    color: color,

                    fontSize: 12,

                    fontWeight:

                    FontWeight.w600,

                  ),

                ),

              ],

            ),

          ],

        ),

      ),

    );

  }



// ==============================================================

// HOW IT WORKS

// ==============================================================



  Widget _buildHowItWorks() {

    return Container(

      width: double.infinity,

      padding:

      const EdgeInsets.all(

        18,

      ),

      decoration:

      BoxDecoration(

        color:

        Colors.indigo.shade50,

        borderRadius:

        BorderRadius.circular(

          20,

        ),

      ),

      child: Column(

        crossAxisAlignment:

        CrossAxisAlignment.start,

        children: [

          const Text(

            'How WriteWise AI Works',

            style:

            TextStyle(

              fontSize: 18,

              fontWeight:

              FontWeight.bold,

            ),

          ),



          const SizedBox(

            height: 15,

          ),



          _step(

            '1',

            'Capture',

            'Upload or capture difficult handwriting.',

          ),



          _step(

            '2',

            'Recognize',

            'AI extracts the handwritten text.',

          ),



          _step(

            '3',

            'Analyze',

            'Confidence and uncertain regions are detected.',

          ),



          _step(

            '4',

            'Verify',

            'Tap uncertain regions and correct them.',

          ),

        ],

      ),

    );

  }



  Widget _step(

      String number,

      String title,

      String description,

      ) {

    return Padding(

      padding:

      const EdgeInsets.only(

        bottom: 14,

      ),

      child: Row(

        crossAxisAlignment:

        CrossAxisAlignment.start,

        children: [

          Container(

            width: 30,

            height: 30,

            alignment:

            Alignment.center,

            decoration:

            BoxDecoration(

              color:

              Colors.indigo,

              borderRadius:

              BorderRadius.circular(

                9,

              ),

            ),

            child: Text(

              number,

              style:

              const TextStyle(

                color:

                Colors.white,

                fontWeight:

                FontWeight.bold,

              ),

            ),

          ),



          const SizedBox(

            width: 12,

          ),



          Expanded(

            child: Column(

              crossAxisAlignment:

              CrossAxisAlignment.start,

              children: [

                Text(

                  title,

                  style:

                  const TextStyle(

                    fontWeight:

                    FontWeight.bold,

                  ),

                ),

                const SizedBox(

                  height: 2,

                ),

                Text(

                  description,

                  style: TextStyle(

                    color:

                    Colors.grey.shade700,

                    fontSize: 13,

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }



// ==============================================================

// MAIN UI

// ==============================================================



  @override

  Widget build(

      BuildContext context,

      ) {

    return Scaffold(

      appBar: AppBar(

        title: const Text(

          'WriteWise AI',

          style:

          TextStyle(

            fontWeight:

            FontWeight.bold,

          ),

        ),

        centerTitle: true,

      ),



      body: SafeArea(

        child:

        SingleChildScrollView(

          padding:

          const EdgeInsets.all(

            16,

          ),

          child: Column(

            crossAxisAlignment:

            CrossAxisAlignment

                .stretch,

            children: [

// HEADER

              Container(

                padding:

                const EdgeInsets.all(

                  22,

                ),

                decoration:

                BoxDecoration(

                  gradient:

                  LinearGradient(

                    colors: [

                      Colors.indigo

                          .shade700,

                      Colors.indigo

                          .shade400,

                    ],

                  ),

                  borderRadius:

                  BorderRadius.circular(

                    24,

                  ),

                ),

                child: const Column(

                  children: [

                    Icon(

                      Icons.edit_note,

                      size: 55,

                      color:

                      Colors.white,

                    ),

                    SizedBox(

                      height: 8,

                    ),

                    Text(

                      'WriteWise AI',

                      style:

                      TextStyle(

                        color:

                        Colors.white,

                        fontSize: 28,

                        fontWeight:

                        FontWeight.bold,

                      ),

                    ),

                    SizedBox(

                      height: 5,

                    ),

                    Text(

                      'Extreme Bad-Handwriting Digitizing Stack',

                      textAlign:

                      TextAlign.center,

                      style:

                      TextStyle(

                        color:

                        Colors.white70,

                        fontSize: 13,

                      ),

                    ),

                  ],

                ),

              ),



              const SizedBox(

                height: 18,

              ),



// CAMERA + GALLERY

              Row(

                children: [

                  Expanded(

                    child:

                    ElevatedButton.icon(

                      onPressed:

                      _isProcessing

                          ? null

                          : () {

                        _pickImage(

                          ImageSource

                              .camera,

                        );

                      },

                      icon: const Icon(

                        Icons.camera_alt,

                      ),

                      label:

                      const Text(

                        'Camera',

                      ),

                    ),

                  ),



                  const SizedBox(

                    width: 12,

                  ),



                  Expanded(

                    child:

                    OutlinedButton

                        .icon(

                      onPressed:

                      _isProcessing

                          ? null

                          : () {

                        _pickImage(

                          ImageSource

                              .gallery,

                        );

                      },

                      icon: const Icon(

                        Icons

                            .photo_library,

                      ),

                      label:

                      const Text(

                        'Gallery',

                      ),

                    ),

                  ),

                ],

              ),



              const SizedBox(

                height: 18,

              ),



// IMAGE

              _buildImageSection(),



              const SizedBox(

                height: 18,

              ),



// ANALYZE BUTTON

              SizedBox(

                height: 52,

                child:

                ElevatedButton.icon(

                  onPressed:

                  _isProcessing ||

                      _imageBytes ==

                          null

                      ? null

                      : _analyzeImage,

                  icon: _isProcessing

                      ? const SizedBox(

                    width: 20,

                    height: 20,

                    child:

                    CircularProgressIndicator(

                      strokeWidth: 2,

                      color:

                      Colors.white,

                    ),

                  )

                      : const Icon(

                    Icons

                        .auto_awesome,

                  ),

                  label: Text(

                    _isProcessing

                        ? 'Analyzing...'

                        : 'Analyze Handwriting',

                  ),

                ),

              ),



              if (_statusMessage

                  .isNotEmpty) ...[

                const SizedBox(

                  height: 10,

                ),

                Center(

                  child: Text(

                    _statusMessage,

                    style:

                    TextStyle(

                      color:

                      Colors.grey

                          .shade700,

                      fontWeight:

                      FontWeight.w500,

                    ),

                  ),

                ),

              ],



              const SizedBox(

                height: 18,

              ),



// ANALYSIS SUMMARY

              _buildAnalysisSummary(),



              const SizedBox(

                height: 18,

              ),



// RESULT

              _buildResultSection(),



              const SizedBox(

                height: 18,

              ),



// ORIGINAL vs AI vs HUMAN-VERIFIED COMPARISON

              _buildComparisonSection(),



              const SizedBox(

                height: 18,

              ),



// REGIONS

              _buildRegionResults(),



              const SizedBox(

                height: 18,

              ),



// HOW IT WORKS

              _buildHowItWorks(),



              const SizedBox(

                height: 25,

              ),



              const Center(

                child: Text(

                  'WriteWise AI • HACKNEX 2026',

                  style:

                  TextStyle(

                    color:

                    Colors.grey,

                    fontSize: 12,

                  ),

                ),

              ),



              const SizedBox(

                height: 20,

              ),

            ],

          ),

        ),

      ),

    );

  }

}



// ==================================================================

// BOUNDING BOX PAINTER

// ==================================================================



class HandwritingBoxPainter

    extends CustomPainter {

  final List<dynamic> regions;



  final double imageWidth;

  final double imageHeight;



  HandwritingBoxPainter({

    required this.regions,

    required this.imageWidth,

    required this.imageHeight,

  });



  @override

  void paint(

      Canvas canvas,

      Size size,

      ) {

    if (imageWidth <= 0 ||

        imageHeight <= 0) {

      return;

    }



    final scaleX =

        size.width / imageWidth;



    final scaleY =

        size.height / imageHeight;



    for (int i = 0;

    i < regions.length;

    i++) {

      final region =

      regions[i];



      if (region is! Map) {

        continue;

      }



      final rect =

      _extractRect(

        region['box'],

      );



      if (rect == null) {

        continue;

      }



      final confidence =

      _getConfidence(

        region,

      );



      final uncertain =

          region['uncertain'] ==

              true;



      final status =

          region['status']

              ?.toString()

              .toUpperCase() ??

              '';



      Color color;



// RED

      if (confidence < 0.70 ||

          status.contains('HIGH') ||

          status.contains('VERY')) {

        color = Colors.red;

      }



// ORANGE

      else if (uncertain ||

          status.contains('VERIFY') ||

          confidence < 0.80) {

        color = Colors.orange;

      }



// GREEN

      else {

        color = Colors.green;

      }



      final scaledRect =

      Rect.fromLTRB(

        rect.left * scaleX,

        rect.top * scaleY,

        rect.right * scaleX,

        rect.bottom * scaleY,

      );



// FILL

      final fillPaint =

      Paint()

        ..color =

        color.withValues(

          alpha: 0.12,

        )

        ..style =

            PaintingStyle.fill;



      canvas.drawRRect(

        RRect.fromRectAndRadius(

          scaledRect,

          const Radius.circular(

            5,

          ),

        ),

        fillPaint,

      );



// BORDER

      final borderPaint =

      Paint()

        ..color = color

        ..strokeWidth = 3

        ..style =

            PaintingStyle.stroke;



      canvas.drawRRect(

        RRect.fromRectAndRadius(

          scaledRect,

          const Radius.circular(

            5,

          ),

        ),

        borderPaint,

      );



// NUMBER LABEL

      final label =

          '${i + 1}';



      final textPainter =

      TextPainter(

        text: TextSpan(

          text: label,

          style:

          const TextStyle(

            color:

            Colors.white,

            fontSize: 11,

            fontWeight:

            FontWeight.bold,

          ),

        ),

        textDirection:

        TextDirection.ltr,

      );



      textPainter.layout();



      final labelWidth =

          textPainter.width +

              8;



      final labelHeight =

          textPainter.height +

              4;



      final labelX =

          scaledRect.left;



      final labelY =

      math

          .max(

        0.0,

        scaledRect.top -

            labelHeight,

      )

          .toDouble();



      final labelPaint =

      Paint()

        ..color = color

        ..style =

            PaintingStyle.fill;



      canvas.drawRRect(

        RRect.fromRectAndRadius(

          Rect.fromLTWH(

            labelX,

            labelY,

            labelWidth,

            labelHeight,

          ),

          const Radius.circular(

            4,

          ),

        ),

        labelPaint,

      );



      textPainter.paint(

        canvas,

        Offset(

          labelX + 4,

          labelY + 2,

        ),

      );

    }

  }



// ==============================================================

// EXTRACT RECT

// ==============================================================



  Rect? _extractRect(

      dynamic box,

      ) {

    if (box == null) {

      return null;

    }



// [x1,y1,x2,y2]



    if (box is List &&

        box.length >= 4 &&

        box[0] is num &&

        box[1] is num &&

        box[2] is num &&

        box[3] is num) {

      final x1 =

      (box[0] as num)

          .toDouble();



      final y1 =

      (box[1] as num)

          .toDouble();



      final x2 =

      (box[2] as num)

          .toDouble();



      final y2 =

      (box[3] as num)

          .toDouble();



      return Rect.fromLTRB(

        math.min(x1, x2),

        math.min(y1, y2),

        math.max(x1, x2),

        math.max(y1, y2),

      );

    }



// POLYGON



    if (box is List &&

        box.isNotEmpty) {

      final points =

      <Offset>[];



      for (final point in box) {

        if (point is List &&

            point.length >= 2 &&

            point[0] is num &&

            point[1] is num) {

          points.add(

            Offset(

              (point[0] as num)

                  .toDouble(),

              (point[1] as num)

                  .toDouble(),

            ),

          );

        }

      }



      if (points.isNotEmpty) {

        double minX =

            points.first.dx;



        double maxX =

            points.first.dx;



        double minY =

            points.first.dy;



        double maxY =

            points.first.dy;



        for (final point

        in points) {

          minX =

              math.min(

                minX,

                point.dx,

              );



          maxX =

              math.max(

                maxX,

                point.dx,

              );



          minY =

              math.min(

                minY,

                point.dy,

              );



          maxY =

              math.max(

                maxY,

                point.dy,

              );

        }



        return Rect.fromLTRB(

          minX,

          minY,

          maxX,

          maxY,

        );

      }

    }



    return null;

  }



// ==============================================================

// CONFIDENCE

// ==============================================================



  double _getConfidence(

      Map region,

      ) {

    final confidence =

    region['confidence'];



    if (confidence is num) {

      return confidence

          .toDouble();

    }



    final percent =

    region[

    'confidence_percent'];



    if (percent is num) {

      return percent

          .toDouble() /

          100;

    }



    return 0;

  }



  @override

  bool shouldRepaint(

      covariant

      HandwritingBoxPainter

      oldDelegate,

      ) {

    return oldDelegate.regions !=

        regions ||

        oldDelegate.imageWidth !=

            imageWidth ||

        oldDelegate.imageHeight !=

            imageHeight;

  }

}
