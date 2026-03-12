import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;

import 'package:geolocator/geolocator.dart'; // <--- ADAUGĂ ASTA

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  final LatLng _center = const LatLng(45.4375, 28.0536);
  Map<String, BitmapDescriptor> _customIcons = {};

  // Mapează tipul incidentului la iconița corespunzătoare
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'pericol':
        return Icons.report_problem_rounded;
      case 'hărțuire':
        return Icons.warning_amber_rounded;
      case 'ajutor':
        return Icons.volunteer_activism;
      case 'iluminat':
        return Icons.lightbulb_outline;
      default:
        return Icons.info_outline_rounded;
    }
  }

  // Mapează tipul incidentului la culoarea corespunzătoare
  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'pericol':
        return Colors.red;
      case 'hărțuire':
        return Colors.purple;
      case 'ajutor':
        return Colors.orange;
      case 'iluminat':
        return Colors.yellow.shade700;
      default:
        return Colors.blue;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) /
        1000; // Rezultat în km
  }

  void _showIncidentsList(List<Map<String, dynamic>> incidents) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${incidents.length} Incident(e) aici",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: incidents.length,
                itemBuilder: (context, index) {
                  final data = incidents[index];
                  final type = data['type'] ?? 'info';
                  return ListTile(
                    leading: Icon(
                      _getIconForType(type),
                      color: _getColorForType(type),
                    ),
                    title: Text(type.toString().toUpperCase()),
                    subtitle: Text(
                      "Raportat de: ${data['sender'] ?? 'Anonim'}",
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<BitmapDescriptor> _getIconMarker(
    IconData iconData,
    Color color,
  ) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = 110.0;
    final shadowPaint = Paint()..color = color.withOpacity(0.3);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, shadowPaint);
    final circlePaint = Paint()..color = color;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size * 0.4,
      circlePaint,
    );
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: iconData.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );
    final image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<void> _moveToUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15.0,
          ),
        ),
      );
    } catch (e) {
      print("Eroare la mutarea camerei: $e");
    }
  }

  Future<void> _loadMarkerIcons() async {
    Map<String, dynamic> config = {
      'pericol': {'icon': Icons.report_problem_rounded, 'color': Colors.red},
      'hărțuire': {'icon': Icons.warning_amber_rounded, 'color': Colors.purple},
      'ajutor': {'icon': Icons.volunteer_activism, 'color': Colors.orange},
      'iluminat': {
        'icon': Icons.lightbulb_outline,
        'color': Colors.yellow.shade700,
      },
      'info': {'icon': Icons.info_outline_rounded, 'color': Colors.blue},
    };
    for (var entry in config.entries) {
      final marker = await _getIconMarker(
        entry.value['icon'],
        entry.value['color'],
      );
      if (mounted) setState(() => _customIcons[entry.key] = marker);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🛡️ Harta Incidentelor Live"),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('posts').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          Map<String, List<Map<String, dynamic>>> grouped = {};
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['location'] != null) {
              GeoPoint p = data['location'];
              String key =
                  "${(p.latitude * 1000).round()}_${(p.longitude * 1000).round()}";
              grouped.putIfAbsent(key, () => []).add(data);
            }
          }

          Set<Marker> markers = grouped.entries.map((entry) {
            final incidents = entry.value;
            GeoPoint p = incidents.first['location'];
            // Dacă sunt mai multe incidente, folosim o iconiță generică de "Info" sau poți adăuga o iconiță de "Multi"
            String markerType = incidents.length > 1
                ? 'info'
                : incidents.first['type']?.toLowerCase() ?? 'info';

            return Marker(
              markerId: MarkerId(entry.key),
              position: LatLng(p.latitude, p.longitude),
              icon: _customIcons[markerType] ?? BitmapDescriptor.defaultMarker,
              onTap: () => _showIncidentsList(incidents),
            );
          }).toSet();

          return GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 13.0),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true, // Adaugă butonul de "Recenter"
            onMapCreated: (GoogleMapController controller) async {
              mapController = controller;

              // Cerem permisiunea dinamic înainte de a activa locația
              LocationPermission permission =
                  await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) {
                permission = await Geolocator.requestPermission();
              }

              if (permission == LocationPermission.always ||
                  permission == LocationPermission.whileInUse) {
                _moveToUserLocation();
              }
            },
          );
        },
      ),
    );
  }
}
