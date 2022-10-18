import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';

class DepthARWidget extends StatefulWidget {
  DepthARWidget({Key key}) : super(key: key);
  @override
  _DepthARWidgetState createState() => _DepthARWidgetState();
}

class _DepthARWidgetState extends State<DepthARWidget> {
  ARSessionManager arSessionManager;
  ARObjectManager arObjectManager;
  bool _showAnimatedGuide = false;
  bool _showPlanes = false;
  bool _handleDepth = true;

  @override
  void dispose() {
    super.dispose();
    arSessionManager.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('AR Depth'),
        ),
        body: Container(
            child: Stack(children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
            showPlatformType: true,
          ),
        ])));
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;

    this.arSessionManager.onInitialize(
          showPlanes: _showPlanes,
          showAnimatedGuide: _showAnimatedGuide,
          handleDepth: _handleDepth,
        );
    this.arObjectManager.onInitialize();
  }

  void updateSessionSettings() {
    this.arSessionManager.onInitialize(
          showPlanes: _showPlanes,
          showAnimatedGuide: _showAnimatedGuide,
          handleDepth: _handleDepth,
        );
  }
}
