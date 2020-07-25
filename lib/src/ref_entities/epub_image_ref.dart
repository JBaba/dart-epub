import '../entities/epub_content_type.dart';
import 'package:image/image.dart' as images;

class EpubImageRef {
  String FileName;
  EpubContentType ContentType;
  String ContentMimeType;
  images.Image image;
  EpubImageRef();
}