import '../entities/epub_content_type.dart';
import '../ref_entities/epub_book_ref.dart';
import '../ref_entities/epub_byte_content_file_ref.dart';
import '../ref_entities/epub_content_file_ref.dart';
import '../ref_entities/epub_content_ref.dart';
import '../ref_entities/epub_text_content_file_ref.dart';
import '../schema/opf/epub_manifest_item.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

class ContentReader {
  static EpubContentRef parseContentMap(EpubBookRef bookRef) {
    EpubContentRef result = EpubContentRef();
    result.Html = Map<String, EpubTextContentFileRef>();
    result.Css = Map<String, EpubTextContentFileRef>();
    result.Images = Map<String, EpubByteContentFileRef>();
    result.Fonts = Map<String, EpubByteContentFileRef>();
    result.AllFiles = Map<String, EpubContentFileRef>();

    bookRef.Schema.Package.Manifest.Items
        .forEach((EpubManifestItem manifestItem) {
      String fileName = manifestItem.Href;
      String contentMimeType = manifestItem.MediaType;
      EpubContentType contentType =
          getContentTypeByContentMimeType(contentMimeType);
      switch (contentType) {
        case EpubContentType.XHTML_1_1:
        case EpubContentType.CSS:
        case EpubContentType.OEB1_DOCUMENT:
        case EpubContentType.OEB1_CSS:
        case EpubContentType.XML:
        case EpubContentType.DTBOOK:
        case EpubContentType.DTBOOK_NCX:
          EpubTextContentFileRef epubTextContentFile =
              EpubTextContentFileRef(bookRef);
          {
            epubTextContentFile.FileName = Uri.decodeFull(fileName);
            epubTextContentFile.ContentMimeType = contentMimeType;
            epubTextContentFile.ContentType = contentType;
          }
          ;
          switch (contentType) {
            case EpubContentType.XHTML_1_1:
              result.Html[fileName] = epubTextContentFile;
              break;
            case EpubContentType.CSS:
              result.Css[fileName] = epubTextContentFile;
              break;
            case EpubContentType.DTBOOK:
            case EpubContentType.DTBOOK_NCX:
            case EpubContentType.OEB1_DOCUMENT:
            case EpubContentType.XML:
            case EpubContentType.OEB1_CSS:
            case EpubContentType.IMAGE_GIF:
            case EpubContentType.IMAGE_JPEG:
            case EpubContentType.IMAGE_JPG:
            case EpubContentType.IMAGE_PNG:
            case EpubContentType.IMAGE_SVG:
            case EpubContentType.FONT_TRUETYPE:
            case EpubContentType.FONT_OPENTYPE:
            case EpubContentType.OTHER:
              break;
          }
          result.AllFiles[fileName] = epubTextContentFile;
          break;
        default:
          EpubByteContentFileRef epubByteContentFile =
              EpubByteContentFileRef(bookRef);
          {
            epubByteContentFile.FileName = Uri.decodeFull(fileName);
            epubByteContentFile.ContentMimeType = contentMimeType;
            epubByteContentFile.ContentType = contentType;
          }
          ;
          switch (contentType) {
            case EpubContentType.IMAGE_GIF:
            case EpubContentType.IMAGE_JPEG:
            case EpubContentType.IMAGE_JPG:
            case EpubContentType.IMAGE_PNG:
            case EpubContentType.IMAGE_SVG:
              result.Images[fileName] = epubByteContentFile;
              break;
            case EpubContentType.FONT_TRUETYPE:
            case EpubContentType.FONT_OPENTYPE:
              result.Fonts[fileName] = epubByteContentFile;
              break;
            case EpubContentType.CSS:
            case EpubContentType.XHTML_1_1:
            case EpubContentType.DTBOOK:
            case EpubContentType.DTBOOK_NCX:
            case EpubContentType.OEB1_DOCUMENT:
            case EpubContentType.XML:
            case EpubContentType.OEB1_CSS:
            case EpubContentType.OTHER:
              break;
          }
          result.AllFiles[fileName] = epubByteContentFile;
          break;
      }
    });
    return result;
  }

  static EpubContentType getContentTypeByContentMimeType(
      String contentMimeType) {
    switch (contentMimeType.toLowerCase()) {
      case "application/xhtml+xml":
        return EpubContentType.XHTML_1_1;
      case "application/x-dtbook+xml":
        return EpubContentType.DTBOOK;
      case "application/x-dtbncx+xml":
        return EpubContentType.DTBOOK_NCX;
      case "text/x-oeb1-document":
        return EpubContentType.OEB1_DOCUMENT;
      case "application/xml":
        return EpubContentType.XML;
      case "text/css":
        return EpubContentType.CSS;
      case "text/x-oeb1-css":
        return EpubContentType.OEB1_CSS;
      case "image/gif":
        return EpubContentType.IMAGE_GIF;
      case "image/jpeg":
        return EpubContentType.IMAGE_JPEG;
      case "image/jpg":
        return EpubContentType.IMAGE_JPG;
      case "image/png":
        return EpubContentType.IMAGE_PNG;
      case "image/svg+xml":
        return EpubContentType.IMAGE_SVG;
      case "font/truetype":
        return EpubContentType.FONT_TRUETYPE;
      case "font/opentype":
        return EpubContentType.FONT_OPENTYPE;
      case "application/vnd.ms-opentype":
        return EpubContentType.FONT_OPENTYPE;
      default:
        return EpubContentType.OTHER;
    }
  }

  static bool isImageFile(String ext) {
    if (ext.toLowerCase() == ".png") {
      return true;
    }
    if (ext.toLowerCase() == ".gif") {
      return true;
    }
    if (ext.toLowerCase() == ".jpeg") {
      return true;
    }
    if (ext.toLowerCase() == ".jpg") {
      return true;
    }
    if (ext.toLowerCase() == ".svg") {
      return true;
    }
    return false;
  }

  static Map<String, EpubByteContentFileRef> parseImages(EpubBookRef bookRef, Archive epubArchive) {
    Map<String, EpubByteContentFileRef> Images =
        Map<String, EpubByteContentFileRef>();
    epubArchive.files.forEach((ArchiveFile archiveFile) {
      String ext = path.extension(archiveFile.name);
      if (isImageFile(ext)) {
        String fileName = path.basename(archiveFile.name);
        EpubByteContentFileRef epubByteContentFile =
            EpubByteContentFileRef(bookRef);
        epubByteContentFile.FileName = fileName;
        epubByteContentFile.FileNameWithOutExt = path.basenameWithoutExtension(archiveFile.name);
        epubByteContentFile.FilePath = archiveFile.name;
        // file types
        if (ext.toLowerCase() == ".png") {
          epubByteContentFile.ContentType = EpubContentType.IMAGE_PNG;
          epubByteContentFile.ContentMimeType = "image/png";
        }
        if (ext.toLowerCase() == ".gif") {
          epubByteContentFile.ContentType = EpubContentType.IMAGE_GIF;
          epubByteContentFile.ContentMimeType = "image/gif";
        }
        if (ext.toLowerCase() == ".jpeg") {
          epubByteContentFile.ContentType = EpubContentType.IMAGE_JPEG;
          epubByteContentFile.ContentMimeType = "image/jpeg";
        }
        if (ext.toLowerCase() == ".jpg") {
          epubByteContentFile.ContentType = EpubContentType.IMAGE_JPG;
          epubByteContentFile.ContentMimeType = "image/jpg";
        }
        if (ext.toLowerCase() == ".svg") {
          epubByteContentFile.ContentType = EpubContentType.IMAGE_SVG;
          epubByteContentFile.ContentMimeType = "image/svg+xml";
        }
        Images[path.basenameWithoutExtension(archiveFile.name)] = epubByteContentFile;
      }
    });
    return Images;
  }

  static createEpubByteContentFile(
      ArchiveFile archiveFile, EpubContentType epubContentType) {}
}
