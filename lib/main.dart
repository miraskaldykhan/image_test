import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CroppedFile? _croppedFile;
  ui.Image? image;
  bool isImageLoaded = false;
  ui.Image? imageToResize;

  Future pickImageFromCamera() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
    );
    _croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile!.path,
        compressFormat: ImageCompressFormat.png,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
        ],
        cropStyle: CropStyle.circle,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarColor: Colors.blue,
            toolbarTitle: 'Crop image',
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          )
        ]);
    if (_croppedFile != null) {
      setState(() {
        init();
      });
    }
  }

  Future pickImageFromGallery() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    _croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile!.path,
        compressFormat: ImageCompressFormat.png,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
        ],
        cropStyle: CropStyle.circle,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarColor: Colors.blue,
            toolbarTitle: 'Crop image',
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          )
        ]);
    if (_croppedFile != null) {
      setState(() {
        init();
      });
    }
  }

  Future init() async {
    File resizeImageFile =
        File("${(await getApplicationDocumentsDirectory()).path}/image.png");
    imageToResize = await getUiImage(_croppedFile!, 600, 600);
    final data1 =
        await imageToResize!.toByteData(format: ui.ImageByteFormat.png);
    resizeImageFile = await resizeImageFile
        .writeAsBytes(data1!.buffer.asUint8List(), flush: true);

    File _newFile = File(resizeImageFile.path);
    Uint8List bytes = _newFile.readAsBytesSync();
    final ByteData data = ByteData.view(bytes.buffer);
    image = await loadImage(Uint8List.view(data.buffer));

    PngImagePainter(image: image!)._saveCanvas(const Size(50, 50));
  }

  Future<ui.Image> loadImage(Uint8List img) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(img, (ui.Image img) {
      setState(() {
        isImageLoaded = true;
      });
      return completer.complete(img);
    });
    return completer.future;
  }

  Future<ui.Image> getUiImage(
      CroppedFile croppedFile, int height, int width) async {
    File _newFile = File(croppedFile.path);
    Uint8List bytes = _newFile.readAsBytesSync();
    img.Image? baseSizeImage = img.decodeImage(bytes);
    img.Image resizeImage =
        img.copyResize(baseSizeImage!, height: height, width: width);
    ui.Codec codec =
        await ui.instantiateImageCodec(img.encodePng(resizeImage) as Uint8List);
    ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cropping"),
      ),
      body: Center(
        child: Column(children: [
          image != null
              ? Text(
                  "height equal to ${image!.height} \n width equal to ${image!.width}")
              : const Text("Please select the image"),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width / 3,
                  child: ElevatedButton(
                    onPressed: pickImageFromCamera,
                    child: const Icon(Icons.camera_alt),
                  ),
                ),
                const SizedBox(width: 10,),
                SizedBox(
                  width: MediaQuery.of(context).size.width / 3,
                  child: ElevatedButton(
                    onPressed: pickImageFromGallery,
                    child: const Icon(Icons.image),
                  ),
                ),
              ],
            ),
          )
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (image != null) {
            image = null;
            _croppedFile = null;
            isImageLoaded = false;
          }
          pickImageFromCamera();
        },
        child: const Icon(Icons.camera_alt_outlined),
      ),
    );
  }
}

class PngImagePainter extends CustomPainter {
  PngImagePainter({this.image});

  ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    _saveCanvas(size);
  }

  Canvas _drawCanvas(Size size, Canvas canvas) {
    double drawImageWidth = 0.0;
    var drawImageHeight = 0.0;

    Path path = Path();
    path.addOval(Rect.fromLTWH(drawImageWidth, drawImageHeight,
        image!.width.toDouble(), image!.height.toDouble()));
    canvas.clipPath(path);

    canvas.drawImage(image!, Offset(drawImageWidth, drawImageHeight), Paint());
    return canvas;
  }

  _saveCanvas(Size size) async {
    var pictureRecorder = ui.PictureRecorder();
    var canvas = Canvas(pictureRecorder);
    var paint = Paint();
    paint.isAntiAlias = true;

    _drawCanvas(size, canvas);

    var pic = pictureRecorder.endRecording();
    ui.Image img = await pic.toImage(image!.width, image!.height);
    var byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    var buffer = byteData!.buffer.asUint8List();

    var documentDirectory = await getApplicationDocumentsDirectory();
    File file = File(join(documentDirectory.path,
        '${DateTime.now().toUtc().toIso8601String()}.png'));
    file.writeAsBytesSync(buffer);

    await GallerySaver.saveImage(file.path);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
