import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:paperless_app/routes/server_details_route.dart';
import 'package:paperless_app/routes/settings_route.dart';
import 'package:paperless_app/widgets/correspondent_widget.dart';
import 'package:paperless_app/widgets/ink_wrapper.dart';
import 'package:paperless_app/widgets/online_pdf_dialog.dart';
import 'package:paperless_app/widgets/search_app_bar.dart';
import 'package:paperless_app/widgets/select_order_route.dart';
import 'package:paperless_app/widgets/tag_widget.dart';
import 'package:paperless_app/i18n.dart';

import '../api.dart';

class DocumentsRoute extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _DocumentsRouteState();
}

class _DocumentsRouteState extends State<DocumentsRoute> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  ResponseList<Document> documents;
  ResponseList<Tag> tags;
  ResponseList<Correspondent> correspondents;
  ScrollController scrollController;
  bool requesting = true;
  DateFormat dateFormat;
  String ordering = "-created";
  String searchString;
  bool invertDocumentPreview = true;

  final List<double> invertMatrix = [
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0, //
  ];

  final List<double> identityMatrix = [
    1, 0, 0, 0, //
    0, 0, 1, 0, //
    0, 0, 0, 0, //
    1, 0, 0, 0, //
    0, 0, 1, 0, //
  ];

  Future<void> setOrdering(String ordering) async {
    this.ordering = ordering;
    reloadDocuments();
  }

  void showDocumentPdf(Document doc) {
    showDialog(
      context: context,
      builder: (BuildContext context) => OnlinePdfDialog(doc),
    );
  }

  Future<void> searchDocument(String searchString) async {
    if (searchString == this.searchString) {
      return;
    }
    this.searchString = searchString;
    await reloadDocuments();
  }

  Future<void> reloadDocuments() async {
    setState(() {
      requesting = true;
      documents = null;
    });
    try {
      var _documents = await API.instance
          .getDocuments(ordering: ordering, search: searchString);

      setState(() {
        documents = _documents;
        requesting = false;
      });
    } catch (e) {
      showDialog(
          context: _scaffoldKey.currentContext,
          builder: (BuildContext context) {
            return AlertDialog(
                title: Text("Error while connecting to server".i18n),
                content: Text(e.toString()),
                actions: <Widget>[
                  new FlatButton(
                      onPressed: reloadDocuments, child: Text("Retry".i18n)),
                  new FlatButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ServerDetailsRoute()),
                        );
                      },
                      child: Text("Edit Server Details".i18n))
                ]);
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool showDark =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    bool invertDocument = showDark && invertDocumentPreview;
    Color bg = showDark ? Colors.black : Colors.white;
    Color fg = showDark ? Colors.white : Colors.black;
    return Scaffold(
      key: _scaffoldKey,
      appBar: SearchAppBar(
          leading: Padding(
              child: SvgPicture.asset("assets/logo.svg", color: Colors.white),
              padding: EdgeInsets.all(13)),
          title: Text(
            "My Documents".i18n,
          ),
          searchListener: searchDocument,
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.sort_by_alpha),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) => SelectOrderRoute(
                    setOrdering: setOrdering,
                    ordering: ordering,
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              onSelected: (String selected) async {
                if (selected == "settings") {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsRoute()),
                  );
                  loadSettings();
                }
              },
              itemBuilder: (BuildContext context) {
                return <PopupMenuItem<String>>[
                  PopupMenuItem<String>(
                      value: "settings", child: Text("Settings".i18n))
                ];
              },
            )
          ]),
      body: Stack(
        children: <Widget>[
          Center(
            child: documents != null
                ? RefreshIndicator(
                    onRefresh: reloadDocuments,
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: documents.results.length,
                      itemBuilder: (context, index) {
                        List<TagWidget> tagWidgets = documents
                            .results[index].tags
                            .map((t) => TagWidget.fromTagId(t, tags))
                            .toList();
                        return Card(
                          margin: EdgeInsets.all(10),
                          child: InkWrapper(
                            splashColor: Colors.greenAccent.withOpacity(1 / 2),
                            onTap: () =>
                                showDocumentPdf(documents.results[index]),
                            child: Column(
                              children: <Widget>[
                                Stack(children: <Widget>[
                                  ColorFiltered(
                                      colorFilter: ColorFilter.matrix(
                                          invertDocument
                                              ? invertMatrix
                                              : identityMatrix),
                                      child: CachedNetworkImage(
                                        fit: BoxFit.cover,
                                        height: 200,
                                        width: double.infinity,
                                        imageUrl: API.instance.baseURL +
                                            documents
                                                .results[index].thumbnailUrl,
                                        httpHeaders: {
                                          "Authorization":
                                              API.instance.authString
                                        },
                                        placeholder: (context, url) =>
                                            CircularProgressIndicator(),
                                        errorWidget: (context, url, error) =>
                                            Icon(Icons.error),
                                      )),
                                  Container(
                                    padding: EdgeInsets.all(5.0),
                                    height: 200,
                                    alignment: Alignment.bottomCenter,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: <Color>[
                                          bg.withAlpha(0),
                                          bg.withAlpha(0),
                                          bg.withAlpha(130),
                                          bg,
                                          bg,
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      '${documents.results[index].title}',
                                      textAlign: TextAlign.start,
                                      style: TextStyle(fontSize: 20, color: fg),
                                    ),
                                  ),
                                ]),
                                Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(
                                          '${dateFormat.format(documents.results[index].created)}',
                                          textAlign: TextAlign.left),
                                      CorrespondentWidget.fromCorrespondentId(
                                          documents
                                              .results[index].correspondent,
                                          correspondents),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: tagWidgets,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ))
                : Container(),
          ),
          PreferredSize(
            child: requesting ? LinearProgressIndicator() : Container(),
            preferredSize: Size.fromHeight(5),
          ),
        ],
      ),
    );
  }

  void loadTags() async {
    var _tags = await API.instance.getTags();
    while (_tags.hasMoreData()) {
      var moreTags = await _tags.getNext();
      _tags.next = moreTags.next;
      _tags.results.addAll(moreTags.results);
    }
    setState(() {
      tags = _tags;
    });
  }

  void loadCorrespondents() async {
    var _correspondents = await API.instance.getCorrespondents();
    while (_correspondents.hasMoreData()) {
      var moreCorrespondents = await _correspondents.getNext();
      _correspondents.next = moreCorrespondents.next;
      _correspondents.results.addAll(moreCorrespondents.results);
    }
    setState(() {
      correspondents = _correspondents;
    });
  }

  void loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      invertDocumentPreview = prefs.getBool("invert_document_preview") ?? true;
    });
  }

  @override
  void initState() {
    reloadDocuments();
    loadTags();
    loadCorrespondents();
    initializeDateFormatting();
    loadSettings();
    dateFormat = new DateFormat.yMMMMd();
    scrollController = new ScrollController()..addListener(_scrollListener);
    super.initState();
  }

  @override
  void dispose() {
    scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() async {
    if (scrollController.position.extentAfter < 900 &&
        !requesting &&
        documents.hasMoreData()) {
      setState(() {
        requesting = true;
      });
      var _documents = await documents.getNext();
      setState(() {
        documents.next = _documents.next;
        documents.results.addAll(_documents.results);
        requesting = false;
      });
    }
  }
}
