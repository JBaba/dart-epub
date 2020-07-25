import 'dart:async';

import 'package:image/image.dart' as images;

import '../ref_entities/epub_book_ref.dart';
import '../ref_entities/epub_byte_content_file_ref.dart';
import '../ref_entities/epub_image_ref.dart';
import '../schema/opf/epub_manifest_item.dart';
import '../schema/opf/epub_metadata_meta.dart';

class BookCoverReader {
  static Future<EpubImageRef> readBookCover(EpubBookRef bookRef) async {
    // 1. First Attempt: Try to find below record
    // <meta name="cover" content="cover-1"/>
    // meta data
    if (isMetadataMetaExits(bookRef)) {
      EpubImageRef epubImageRef = await findCoverInMetadataMeta(bookRef);
      if (epubImageRef != null) {
        return epubImageRef;
      }
    }
    // 2. Second Attempt: Try to find if "cover" id present in Manifest items
    EpubMetadataMeta coverMetaItem = new EpubMetadataMeta();
    coverMetaItem.Content = "cover";
    EpubImageRef epubImageRef =
        await findCoverInMenifestItems(bookRef, coverMetaItem);
    if (epubImageRef != null) {
      return epubImageRef;
    }
    // TODO: future
    // 3. Third Attempt: Find image file with "cover" in it
    // 4. Forth Attempt: Find Any Image in Menifest items
    // 5. Fifth Attempt: If no image entry in Menifest items Find any image in epub zip file
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
    return findCoverInMenifestItems(bookRef, coverMetaItem);
  }

  static Future<EpubImageRef> findCoverInMenifestItems(
      EpubBookRef bookRef, EpubMetadataMeta coverMetaItem) {
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
    return buildEpubImageRef(bookRef.Content.Images[coverManifestItem.Href]);
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
