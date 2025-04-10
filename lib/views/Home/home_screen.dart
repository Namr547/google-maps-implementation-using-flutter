import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../api keys/api_keys.dart';


class MyHomeScreen extends StatefulWidget {
  const MyHomeScreen({super.key});

  @override
  State<MyHomeScreen> createState() => _MyHomeScreenState();
}

class _MyHomeScreenState extends State<MyHomeScreen> {
  /// Google Map controller for interacting with the map
  final Completer<GoogleMapController> _controller = Completer();

  /// Initial camera position (Islamabad, PK)
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(33.66981695950811, 72.99690837015225),
    zoom: 14,
  );

  /// All active markers on the map
  final List<Marker> myMarker = [];

  /// Predefined marker list to show on map load
  final List<Marker> markerList = [
    Marker(
      markerId: MarkerId('First'),
      position: LatLng(33.66981695950811, 72.99690837015225),
      infoWindow: InfoWindow(title: 'My Position'),
    ),
    Marker(
      markerId: MarkerId('Second'),
      position: LatLng(33.70411628085092, 73.06844962645879),
      infoWindow: InfoWindow(title: 'My Flat Position'),
    ),
    Marker(
      markerId: MarkerId('Third'),
      position: LatLng(33.70348321062971, 72.97853643835175),
      infoWindow: InfoWindow(title: 'E-11'),
    ),
  ];

  /// Controller for search text field
  final TextEditingController _searchController = TextEditingController();

  /// Places API suggestions list
  List<dynamic> suggestions = [];

  /// Session token for optimized Google Places queries
  String sessionToken = '123456';
  final uuid = Uuid();

  @override
  void initState() {
    super.initState();

    // Add predefined markers on startup
    myMarker.addAll(markerList);

    // Listen for changes in the search box
    _searchController.addListener(_onSearchChanged);

    // Get custom marker
    packDataCM();

    //show network image on custom marker
    addSingleNetworkMarker();

    //Get polygons
    _myPolygons.add(
      Polygon(polygonId: PolygonId('First'),
      points: polygonLatLngs,
      fillColor: Colors.cyan.withOpacity(0.3),
      geodesic: true,
      strokeWidth: 4,
      strokeColor: Colors.redAccent,)
    );

    //Get PolyLines
    addPolyLine();

    //themes
    DefaultAssetBundle.of(context).loadString('assets/themes/retro.json').then((value){
     themeForMap = value;
    });
  }

  /// Triggered when the user types in the search field
  void _onSearchChanged() {
    if (sessionToken == null) {
      setState(() {
        sessionToken = uuid.v4();
      });
    }
    _getSuggestions(_searchController.text);
  }

  /// Calls Google Places API to fetch autocomplete suggestions
  Future<void> _getSuggestions(String input) async {
    if (input.isEmpty) return;

    String request = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$googlePlacesApiKey&sessiontoken=$sessionToken';

    final response = await http.get(Uri.parse(request));
    if (response.statusCode == 200) {
      setState(() {
        suggestions = jsonDecode(response.body)['predictions'];
      });
    } else {
      throw Exception('Failed to load suggestions');
    }
  }

  /// Converts selected suggestion to coordinates and animates map there
  Future<void> _goToPlace(String description) async {
    final locations = await locationFromAddress(description);
    final target = LatLng(locations.first.latitude, locations.first.longitude);

    // Add a marker for the searched location
    myMarker.add(Marker(
      markerId: MarkerId(description),
      position: target,
      infoWindow: InfoWindow(title: description),
    ));

    // Animate the map to that location
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: target, zoom: 15),
    ));

    setState(() {
      suggestions.clear();
      _searchController.clear();
    });
  }

  /// Fetches the user's current GPS location
  Future<Position> getUserLocation() async {
    await Geolocator.requestPermission();
    return await Geolocator.getCurrentPosition();
  }

  /// Adds marker for user's current location and animates camera
  void packDataM() {
    getUserLocation().then((value) async {
      final currentLocation = LatLng(value.latitude, value.longitude);

      myMarker.add(Marker(
        markerId: MarkerId('CurrentLocation'),
        position: currentLocation,
        infoWindow: InfoWindow(title: 'My Location'),
      ));

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: currentLocation, zoom: 14),
      ));

      setState(() {});
    });
  }

  ///Add custom markers using assets images &&& Custom Info Window for Markers
  final CustomInfoWindowController _customInfoWindowController = CustomInfoWindowController();
  final List<Map<String, String>> customMarkerData = [
    {
      'title': 'G 11/3 G-11, Islamabad',
      'image':
      'https://irealprojects.com/wp-content/uploads/2023/05/Warda-Hamna-Residencia-apartments-by-warda-hamna-in-g-11-islamabad.jpg',
    },
    {
      'title': 'G-10 2, Islamabad',
      'image':
      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTOYlRXYlGkuKgYtayW02m6lgBU3ClTRqoryAyqtOY3cRklLQO10Teh5nYz50buQdW6if4&usqp=CAU',
    },
    {
      'title': 'G-10 Markaz, Islamabad',
      'image':
      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTSWnBQr-Bna9WtOMJsnuAbpkgJeIsLYirWjg&s',
    },
    {
      'title': 'F-11 Food Street',
      'image':
      'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/10/a7/56/fc/food-street.jpg?w=1200&h=-1&s=1',
    },
    {
      'title': 'F-9 Markaz',
      'image':
      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTOWghcE-c5JKyy_L1rCyypG8uKo-mhmfQmXg&s',
    },
    {
      'title': 'NPF E-11, Islamabad',
      'image':
      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT6GxukalPonCwBYyeQQziwVK2rwxbTpGe8WQ&s',
    },
    {
      'title': 'OPF Girls College',
      'image':
      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQcClznksQqKu28KxfFRYBTSLd9xQwUFvwz5w&s',
    },
  ];
  List<String> markerImages = [
    'assets/markerIcons/1.png',
    'assets/markerIcons/2.png',
    'assets/markerIcons/3.png',
    'assets/markerIcons/4.png',
    'assets/markerIcons/5.png',
    'assets/markerIcons/6.png',
    'assets/markerIcons/7.png',
  ];
  final List<LatLng> latLngForImage = <LatLng>[
    LatLng(33.67561255944885, 73.00097912886538),
    LatLng(33.6800409477715, 73.0123946091769),
    LatLng(33.6773982273428, 73.01488369886887),
    LatLng(33.68839712375733, 73.03479641640475),
    LatLng(33.69068243213318, 73.00544232417514),
    LatLng(33.70032290786856, 72.98243970219407),
    LatLng(33.68554040283571, 72.9832980089844),
  ];
  Future<Uint8List> getImagesFromMarker (String path, int width) async{
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),targetHeight: width);
    ui.FrameInfo frameInfo = await codec.getNextFrame();
    return (await frameInfo.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

  }
  packDataCM() async {
    for (int a = 0; a < markerImages.length; a++) {
      final Uint8List iconMaker = await getImagesFromMarker(markerImages[a], 90);

      myMarker.add(
        Marker(
          markerId: MarkerId(a.toString()),
          position: latLngForImage[a],
          icon: BitmapDescriptor.fromBytes(iconMaker),
          onTap: () {
            _customInfoWindowController.addInfoWindow!(
              Container(
                height: 150,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Image Section
                    Container(
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(customMarkerData[a]['image']!),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                    ),
                    /// Title Section
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        customMarkerData[a]['title']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              latLngForImage[a],
            );
          },
        ),
      );
    }

    setState(() {});
  }


  ///network images on custom markers
  Future<void> addSingleNetworkMarker() async {
    const String imageUrl = 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSC66X2ryAxSRvUemFd_2l_rq8aqL-OB-_owQ&s';
    final LatLng targetPosition = LatLng(33.66981695950811, 72.99690837015225);

    // Load network image
    final completer = Completer<ImageInfo>();
    final image = NetworkImage(imageUrl);
    image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) => completer.complete(info)),
    );

    final imageInfo = await completer.future;
    final ui.Image originalImage = imageInfo.image;

    // Set desired size
    const int size = 100;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..isAntiAlias = true;

    // Draw circular clip
    final Rect rect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(size / 2));
    canvas.clipRRect(rrect);

    // Draw image into clipped canvas
    paint.color = Colors.white;
    canvas.drawImageRect(
      originalImage,
      Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
      rect,
      paint,
    );

    final ui.Image roundedImage = await recorder
        .endRecording()
        .toImage(size, size);
    final ByteData? byteData = await roundedImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List roundedMarkerBytes = byteData!.buffer.asUint8List();

    // Add circular marker
    myMarker.add(
      Marker(
        markerId: MarkerId('network_image_marker'),
        position: targetPosition,
        icon: BitmapDescriptor.fromBytes(roundedMarkerBytes),
        infoWindow: InfoWindow(title: 'Network Image Marker'),
      ),
    );

    setState(() {});
  }


///Draw polygon
final Set<Polygon> _myPolygons = HashSet<Polygon>();
  List<LatLng> polygonLatLngs = [
    LatLng(33.683371701027625, 72.9895247440526),
    LatLng(33.681273708490274, 73.00126157872869),
    LatLng(33.67273652121729, 72.98483001018218),
    LatLng(33.67794575324375, 72.98365632671457),
    LatLng(33.68293763780681, 72.98778595373022),
  ];

  ///Draw Polyline
  final Set<Marker> polyLineMarker = {};
  final Set<Polyline> _myPolyLine = {};
  List<LatLng> polyLineLatLngs = [
    ///for multiple lines add multiple ltlng
LatLng(33.66981695950811, 72.99690837015225),
    LatLng(33.70348321062971, 72.97853643835175),
  ];
  addPolyLine() {
    for (int a = 0; a < polyLineLatLngs.length; a++)
      {
        polyLineMarker.add(
          Marker(
            markerId: MarkerId(a.toString()),
            position: polyLineLatLngs[a],
            icon: BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(
            title: 'Adventure Place',
              snippet: '10 out of 10 star'
            ),
          ),
          );
          setState(() {

        });
          _myPolyLine.add(
    Polyline(polylineId: PolylineId('First'),
    points: polyLineLatLngs,
    color: Colors.green,
    width: 4,
    ),
    );
      }
  }

///Themes for map
  String themeForMap = '';


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search location...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white60),
          ),
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: Colors.teal,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              final controller = await _controller.future;
              String style = await DefaultAssetBundle.of(context).loadString('assets/themes/$value.json');
              controller.setMapStyle(style);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'dark',
                child: Text('Dark'),
              ),
              PopupMenuItem(
                value: 'retro',
                child: Text('Retro'),
              ),
              PopupMenuItem(
                value: 'night',
                child: Text('Night'),
              ),
              PopupMenuItem(
                value: 'silver',
                child: Text('Silver'),
              ),
            ],
          )



        ],
      ),

      body: Stack(
        children: [
          /// Google Map widget
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            mapType: MapType.normal,
            markers: Set<Marker>.of(myMarker),
            polygons: _myPolygons,
            polylines: _myPolyLine,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              controller.setMapStyle(themeForMap);
              _customInfoWindowController.googleMapController = controller;

            },
            onTap: (position)
            {
              _customInfoWindowController.hideInfoWindow!();
            },
            onCameraMove: (position)
            {
              _customInfoWindowController.onCameraMove!();
            },

          ),
          ///Custom info window
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 150,
            width: 200,
            offset: 40,
          ),
          /// Show suggestions below AppBar if available
          if (suggestions.isNotEmpty)
            Positioned(
              top: kToolbarHeight,
              left: 10,
              right: 10,
              child: Card(
                elevation: 4,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(suggestions[index]['description']),
                      onTap: () {
                        _goToPlace(suggestions[index]['description']);
                      },
                    );
                  },
                ),
              ),
            )
        ],
      ),

      /// Floating action buttons for camera actions
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        buttonSize: const Size(56, 56),
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        children: [
          /// Move camera to predefined LatLng
          SpeedDialChild(
            child: Icon(Icons.location_searching),
            backgroundColor: Colors.redAccent,
            label: 'Animate to Location',
            labelStyle: TextStyle(fontSize: 14.0),
            onTap: () async {
              final controller = await _controller.future;
              controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(33.70348321062971, 72.97853643835175),
                    zoom: 14,
                  ),
                ),
              );
            },
          ),

          /// Get user location and update map
          SpeedDialChild(
            child: Icon(Icons.my_location),
            backgroundColor: Colors.greenAccent,
            label: 'Get User Location',
            labelStyle: TextStyle(fontSize: 14.0),
            onTap: packDataM,
          ),
        ],
      ),
    );
  }
}
