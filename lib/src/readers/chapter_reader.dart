import 'package:epub/src/schema/opf/epub_spine_item_ref.dart';

import '../ref_entities/epub_book_ref.dart';
import '../ref_entities/epub_chapter_ref.dart';
import '../ref_entities/epub_text_content_file_ref.dart';
import '../schema/navigation/epub_navigation_point.dart';

class ChapterReader {
  static Map<String, String> manifestItemIdHrefKey = {};
  static Map<String, List<EpubChapterRef>> ncxRefs = {};

  static List<EpubChapterRef> getChapters(EpubBookRef bookRef) {
    if (bookRef.Schema.Navigation == null) {
      return List<EpubChapterRef>();
    }
    ncxRefs = {};
    manifestItemIdHrefKey = {};
    List<EpubChapterRef> result =
    getChaptersImpl(bookRef, bookRef.Schema.Navigation.NavMap.Points);
    // create map
    populateManifest(bookRef);
    populateMissingChaptersFromSpine(bookRef);
    return result;
  }

  static populateManifest(EpubBookRef bookRef) {
    bookRef.Schema.Package.Manifest.Items.forEach((element) {
      manifestItemIdHrefKey.putIfAbsent(element.Id, () => element.Href);
    });
  }

  static List<EpubChapterRef> getChaptersImpl(EpubBookRef bookRef,
      List<EpubNavigationPoint> navigationPoints) {
    List<EpubChapterRef> result = List<EpubChapterRef>();
    var navLen = navigationPoints.length;
    for (var i = 0; i < navLen; i++) {
      EpubNavigationPoint navigationPoint = navigationPoints[i];
      String contentFileName;
      String anchor;
      int contentSourceAnchorCharIndex =
      navigationPoint.Content.Source.indexOf('#');
      if (contentSourceAnchorCharIndex == -1) {
        contentFileName = navigationPoint.Content.Source;
        anchor = null;
      } else {
        contentFileName = navigationPoint.Content.Source
            .substring(0, contentSourceAnchorCharIndex);
        anchor = navigationPoint.Content.Source
            .substring(contentSourceAnchorCharIndex + 1);
      }

      EpubTextContentFileRef htmlContentFileRef;
      if (!bookRef.Content.Html.containsKey(contentFileName)) {
        throw Exception(
            "Incorrect EPUB manifest: item with href = \"${contentFileName}\" is missing.");
      }

      htmlContentFileRef = bookRef.Content.Html[contentFileName];
      EpubChapterRef chapterRef = EpubChapterRef(htmlContentFileRef);
      chapterRef.ContentFileName = contentFileName;
      chapterRef.Anchor = anchor;
      chapterRef.Title = navigationPoint.NavigationLabels.first.Text;
      chapterRef.SubChapters =
          getChaptersImpl(bookRef, navigationPoint.ChildNavigationPoints);
      result.add(chapterRef);
      ncxRefs.putIfAbsent(chapterRef.ContentFileName, () => result);
    }
    return result;
  }

  // Bug Description:
  // ----------------
  // getChapters ingores following use cases which are not addressed,
  // 1. Chapters sometimes gets split into multiple html files in
  //    this situations NCX does't have navpoint for split files
  //    as they are not seperate chapters. But in .opf reading order
  //    We can see the entry for html page.
  //    But this lib ignores (Bug) such pages and getChapters
  //    is broken for such use cases as sections goes missing.
  // ------------------ Enhancments ---------------------------------
  // 2. Spine can have multiple html pages at the begging
  //    Like. Cover, Copyrights and others....
  //    Create EpubChapterRef for those front pages
  // 3. Same as point 1 but consider html pages at the end
  //
  // Bug fix:
  // --------
  // Consider spin element from .opf and .NCX both and populate missing
  // html pages
  static populateMissingChaptersFromSpine(EpubBookRef bookRef) {
    bool isFirstMissing = true;
    List<EpubChapterRef> frontPages = new List();
    var lastFound = '';
    for (var i = 0; i < bookRef.Schema.Package.Spine.Items.length; i++) {
      EpubSpineItemRef element = bookRef.Schema.Package.Spine.Items[i];
      var contentFileName = manifestItemIdHrefKey[element.IdRef];
      if(!ncxRefs.containsKey(contentFileName)){
        if(isFirstMissing) {
          frontPages.add(createMissingChapterRef(bookRef, contentFileName));
        } else {
          if(lastFound.isNotEmpty) {
            addChapterAtEnd(bookRef, contentFileName, ncxRefs[lastFound]);
          }
        }
      } else {
        if(isFirstMissing) {
          addChaptersAtFront(frontPages, ncxRefs[contentFileName]);
          isFirstMissing = false;
        }
        lastFound = contentFileName;
      }
    }
  }
  
  static EpubChapterRef createMissingChapterRef(EpubBookRef bookRef, var contentFileName) {
    EpubTextContentFileRef htmlContentFileRef;
    if (!bookRef.Content.Html.containsKey(contentFileName)) {
      throw Exception(
          "Incorrect EPUB manifest: item with href = \"${contentFileName}\" is missing.");
    }
    htmlContentFileRef = bookRef.Content.Html[contentFileName];
    EpubChapterRef epubChapterRef = EpubChapterRef(htmlContentFileRef);
    epubChapterRef.isPartOfNcx = false;
    epubChapterRef.ContentFileName = contentFileName;
    epubChapterRef.SubChapters = new List();
    return epubChapterRef;
  }

  static void addChaptersAtFront(List<EpubChapterRef> frontPages, List<EpubChapterRef> ncxRefs) {
    ncxRefs.insertAll(0, frontPages);
  }

  static void addChapterAtEnd(EpubBookRef bookRef, String contentFileName, List<EpubChapterRef> ncxRefs) {
    var index = 0;
    for (var i = 0; i < ncxRefs.length; i++) {
      if(ncxRefs[i].ContentFileName == contentFileName) {
        break;
      }
      index++;
    };
    ncxRefs.insert(index, createMissingChapterRef(bookRef, contentFileName));
  }
}
