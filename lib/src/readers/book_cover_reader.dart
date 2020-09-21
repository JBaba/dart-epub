import 'dart:async';

import 'package:image/image.dart' as images;

import '../ref_entities/epub_book_ref.dart';
import '../ref_entities/epub_byte_content_file_ref.dart';
import '../ref_entities/epub_image_ref.dart';
import '../schema/opf/epub_manifest_item.dart';
import '../schema/opf/epub_metadata_meta.dart';
import 'package:path/path.dart' as path;

class BookCoverReader {
  static Future<EpubImageRef> readBookCover(EpubBookRef bookRef) async {
    return searchBookCover(bookRef);
  }

  static Future<EpubImageRef> searchBookCover(EpubBookRef bookRef) async {
    return no1MetaSearch(bookRef);
  }

  static Future<EpubImageRef> no1MetaSearch(EpubBookRef bookRef) async {
    try {
      // 1. First Attempt: Try to find below record
      // <meta name="cover" content="cover-1"/>
      // meta data
      if (isMetadataMetaExits(bookRef)) {
        EpubImageRef epubImageRef = await findCoverInMetadataMeta(bookRef);
        if (epubImageRef != null) {
          return epubImageRef;
        }
      }
      return await no2CoverMenifestSearch(bookRef);
    } catch (e) {
      return await no2CoverMenifestSearch(bookRef);
    }
  }

  static Future<EpubImageRef> no2CoverMenifestSearch(
      EpubBookRef bookRef) async {
    try {
      // 2. Second Attempt: Try to find if "cover" id present in Manifest items
      EpubMetadataMeta coverMetaItem = new EpubMetadataMeta();
      coverMetaItem.Content = "cover";
      EpubImageRef epubImageRef =
          await findCoverInMenifestItems(bookRef, coverMetaItem);
      if (epubImageRef != null) {
        return epubImageRef;
      }
      return await no3CoverTxtSearch(bookRef);
    } catch (e) {
      return await no3CoverTxtSearch(bookRef);
    }
  }

  static Future<EpubImageRef> no3CoverTxtSearch(EpubBookRef bookRef) async {
    try {
      // 3. Third Attempt: Find image file contains text "cover" in it
      EpubByteContentFileRef coverFileRef = bookRef.Content.ImageFiles.values
          .firstWhere(
              (element) => element.FilePath.toLowerCase().contains("cover"),
              orElse: () => null);
      if (coverFileRef != null) {
        EpubImageRef epubImageRef = EpubImageRef();
        epubImageRef.FileName = coverFileRef.FilePath;
        epubImageRef.ContentMimeType = coverFileRef.ContentMimeType;
        epubImageRef.ContentType = coverFileRef.ContentType;
        epubImageRef.IsImageSearched = true;
        return epubImageRef;
      }
      return await no4AnyImageSearch(bookRef);
    } catch (e) {
      return await no4AnyImageSearch(bookRef);
    }
  }

  static Future<EpubImageRef> no4AnyImageSearch(EpubBookRef bookRef) async {
    // 4. Fourth Attempt: If no image entry in Menifest items Find any image in epub zip file
    if (bookRef.Content.ImageFiles.length > 0) {
      EpubByteContentFileRef coverFileRef = bookRef.Content.ImageFiles.values.first;
      if (coverFileRef != null) {
        EpubImageRef epubImageRef = EpubImageRef();
        epubImageRef.FileName = coverFileRef.FilePath;
        epubImageRef.ContentMimeType = coverFileRef.ContentMimeType;
        epubImageRef.ContentType = coverFileRef.ContentType;
        epubImageRef.IsImageSearched = true;
        return epubImageRef;
      }
    }
    throw Exception("Cover Serach didn'f found any image in archive.");
  }

  static Future<EpubImageRef> findCoverInMetadataMeta(
      EpubBookRef bookRef) async {
    List<EpubMetadataMeta> metaItems =
        bookRef.Schema.Package.Metadata.MetaItems;
    if (metaItems == null || metaItems.isEmpty) return null;

    EpubMetadataMeta coverMetaItem = metaItems.firstWhere(
        (EpubMetadataMeta metaItem) =>
            metaItem.Name != null && metaItem.Name.toLowerCase() == "cover",
        orElse: () => null);
    if (coverMetaItem == null) return null;
    if (coverMetaItem.Content == null || coverMetaItem.Content.isEmpty) {
      throw Exception(
          "Incorrect EPUB metadata: cover item content is missing.");
    }
    return await findCoverInMenifestItems(bookRef, coverMetaItem);
  }

  static Future<EpubImageRef> findCoverInMenifestItems(
      EpubBookRef bookRef, EpubMetadataMeta coverMetaItem) async {
    EpubManifestItem coverManifestItem = bookRef.Schema.Package.Manifest.Items
        .firstWhere(
            (EpubManifestItem manifestItem) =>
                manifestItem.Id.toLowerCase() ==
                coverMetaItem.Content.toLowerCase(),
            orElse: () => null);
    if (coverManifestItem == null) {
      throw Exception(
          "Incorrect EPUB manifest: item with ID = \"${coverMetaItem.Content}\" is missing.");
    }
    if (!bookRef.Content.Images.containsKey(coverManifestItem.Href)) {
      throw Exception(
          "Incorrect EPUB manifest: item with href = \"${coverManifestItem.Href}\" is missing.");
    }
    try {
      return await buildEpubImageRef(
          bookRef.Content.Images[coverManifestItem.Href]);
    } catch (e) {
      // try to find any other image mime type file name
      String fileName = path.basenameWithoutExtension(coverManifestItem.Href);
      return await buildEpubImageRef(bookRef.Content.ImageFiles[fileName]);
    }
  }

  static bool isMetadataMetaExits(EpubBookRef bookRef) {
    List<EpubMetadataMeta> metaItems =
        bookRef.Schema.Package.Metadata.MetaItems;
    return !(metaItems == null || metaItems.isEmpty);
  }

  static Future<EpubImageRef> buildEpubImageRef(
      EpubByteContentFileRef coverImageContentFileRef) async {
    EpubImageRef epubImageRef = EpubImageRef();
    epubImageRef.FileName = coverImageContentFileRef.FileName;
    epubImageRef.ContentMimeType = coverImageContentFileRef.ContentMimeType;
    epubImageRef.ContentType = coverImageContentFileRef.ContentType;
    List<int> coverImageContent =
        await coverImageContentFileRef.readContentAsBytes();
    images.Image retval = images.decodeImage(coverImageContent);
    epubImageRef.image = retval;
    return epubImageRef;
  }
}
