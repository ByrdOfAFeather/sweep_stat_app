import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share/share.dart';
import 'package:sweep_stat_app/experiment.dart';
import 'package:fl_chart/fl_chart.dart';

class FileNamePopup extends StatefulWidget {
  // TODO: Might not be needed since we are getting a project name and can have a generic _config _experimentube

  final Function onSave;

  FileNamePopup({Key key, this.onSave}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _FileNamePopupState();
  }
}

class _FileNamePopupState extends State<FileNamePopup> {
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  final _textController = new TextEditingController();
  bool saving = false;
  bool saveStatus;

  @override
  Widget build(BuildContext context) {
    if (saving) {
      return AlertDialog(content: CircularProgressIndicator());
    } else if (saveStatus != null) {
      if (saveStatus) {
        return AlertDialog(
          content: Column(
            children: [
              Text("Save Complete!"),
              RaisedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("Ok!"))
            ],
          ),
        );
      } else {
        return AlertDialog(
            content: Column(
              children: [
                Text("There was a problem saving!"),
                RaisedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("Ok!"))
              ],
            ));
      }
    } else {
      return AlertDialog(
        content: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: "File Name",
                  ),
                  validator: (String newText) {
                    if (newText.isNotEmpty) {
                      return null;
                    } else {
                      return "Can't have an empty file name!";
                    }
                  },
                  onSaved: (String fileName) {
                    Future<bool> saved = widget.onSave(_textController.value.toString());
                    saved.then((bool didSave) {
                      setState(() {
                        saving = false;
                        saveStatus = didSave;
                      });
                    });
                    setState(() {
                      saving = true;
                    });
                  }),
              RaisedButton(
                  onPressed: () {
                    if (_formKey.currentState.validate()) {
                      _formKey.currentState.save();
                    }
                  },
                  child: Text("Save"))
            ],
          ),
        ),
      );
    }
  }
}

class ExperimentSettingsValues extends StatelessWidget {
  final ExperimentSettings settings;

  const ExperimentSettingsValues({Key key, this.settings}) : super(key: key);

  Widget build(BuildContext context) {
    Widget settingsText(String text) {
      return Text(
        text,
        style: TextStyle(fontSize: 15),
      );
    }

    Widget settingsRow(String settingName, dynamic settingValue, String unitSymbol) {
      return Row(
          children: [Expanded(child: settingsText('$settingName')), settingsText('${settingValue} $unitSymbol'), settingsText('')],
          mainAxisAlignment: MainAxisAlignment.spaceBetween);
    }

    return Padding(
        padding: EdgeInsets.only(left: 30, right: 30),
        child: Column(
          children: [
            Text(
              "Settings",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25),
            ),
            Divider(),
            settingsRow("Initial Voltage", settings.initialVoltage, "V"),
            settingsRow("Final Voltage", settings.finalVoltage, "V"),
            settingsRow("Vertex Voltage", settings.highVoltage, "V"),
            settingsRow("Scan Rate", settings.scanRate, "V/s"),
            settingsRow("Sweep Segments", settings.sweepSegments, ""),
            settingsRow("Sample Interval", settings.sampleInterval, "V")
          ],
        ));
  }
}

class AnalysisScreen extends StatefulWidget {
  /*
    It seems like everything is through shared preferences
  */
  final Experiment experiment;

  const AnalysisScreen({Key key, this.experiment}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _AnalysisScreenState();
  }
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // TODO: Move spots to Experiment class !
  LineChartBarData data_L;
  LineChartBarData data_R;
  double i, j; // TODO temp: remove later

  Future<bool> saveLocally() async {
    return await widget.experiment.saveExperiment();
  }

  Future<bool> shareFiles() async {
    bool didSave = await saveLocally();
    if (didSave) {
      Directory experimentDir = await widget.experiment.getOrCreateCurrentDirectory();
      Share.shareFiles([
        '${experimentDir.path}/${widget.experiment.settings.projectName}_config.csv',
        '${experimentDir.path}/${widget.experiment.settings.projectName}_data.csv'
      ]);
      return true;
    } else {
      return false;
    }
  }

  void initState() {
    data_L = LineChartBarData(
      spots: widget.experiment.dataL,
      isCurved: true,
    );
    data_R = LineChartBarData(spots: widget.experiment.dataR, isCurved: true, curveSmoothness: .1, colors: [Colors.blueAccent]);
    i = widget.experiment.settings.lowVoltage; // TODO: temp remove, later
    j = widget.experiment.settings.lowVoltage;
    super.initState();
  }

  bool locki = false;
  bool lockii = false;

  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            actions: [
              IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return Dialog(
                            child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                              ExperimentSettingsValues(settings: widget.experiment.settings),
                              RaisedButton(
                                child: Text("Ok"),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              )
                            ]),
                          );
                        });
                  })
            ],
            title: Text("Analysis")),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(top: 10, left: 5),
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 22.0, bottom: 20),
                  child: LineChart(LineChartData(
                      maxX: widget.experiment.settings.highVoltage,
                      minX: widget.experiment.settings.lowVoltage,
                      clipData: FlClipData.vertical(),
                      lineBarsData: [data_L, data_R],
                      axisTitleData: FlAxisTitleData(
                        show: true,
                        leftTitle:
                        AxisTitle(showTitle: true, titleText: "Current i (AM)", textStyle: TextStyle(fontStyle: FontStyle.italic, color: Colors.black)),
                        bottomTitle:
                        AxisTitle(showTitle: true, titleText: "Potential E (V)", textStyle: TextStyle(fontStyle: FontStyle.italic, color: Colors.black)),
                        topTitle: AxisTitle(
                            showTitle: true, titleText: "Current Vs Potential", textStyle: TextStyle(fontStyle: FontStyle.italic, color: Colors.black)),
                      ))),
                ),
              ),
//              ExperimentSettingsValues(settings: widget.experiment.settings),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                RaisedButton(
                    color: Colors.blue,
                    onPressed: () async {
                      if (await saveLocally()) {
                        _scaffoldKey.currentState.showSnackBar(SnackBar(
                          content: Text("Saved successfully!"),
                          duration: Duration(seconds: 1),
                        ));
                      } else {
                        _scaffoldKey.currentState.showSnackBar(SnackBar(
                          content: Text("Failed to save, please try again!"),
                          duration: Duration(seconds: 1),
                        ));
                      }
                    },
                    child: Text(
                      "Save",
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    )),
                RaisedButton(
                    color: Colors.blue,
                    child: Text("Start", style: TextStyle(color: Colors.white, fontSize: 15)),
                    onPressed: () {
                      Timer.periodic(new Duration(milliseconds: 20), (timer) {
                        setState(() {
                          if (i > widget.experiment.settings.highVoltage) {
                            return;
                          }
                          widget.experiment.dataL.add(new FlSpot(i + 0.0, i * i));
                          widget.experiment.dataR.add(new FlSpot(j, cos(-j * j)));
                          i += .3;
                          j += .3;
                        });
                      });
                    }),
                RaisedButton(
                    color: Colors.blue,
                    onPressed: () async {
                      // showDialod
                      if (!(await shareFiles())) {
                        _scaffoldKey.currentState.showSnackBar(SnackBar(
                          content: Text("Failed to save, please try again!"),
                          duration: Duration(seconds: 3),
                        ));
                      }
                    },
                    child: Text("Share", style: TextStyle(color: Colors.white, fontSize: 15)))
              ]),
            ]),
          ),
        ));
  }
}
