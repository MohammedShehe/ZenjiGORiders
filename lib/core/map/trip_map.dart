import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../utils/directions_service.dart';
import 'map_markers.dart';
import 'map_motion.dart';
import 'map_style.dart';
import 'map_widgets.dart';
import 'route_utils.dart';

/// A self-contained, styled trip map: pickup + destination pins and the road route between
/// them (white casing + coloured core), fitted to the available space. Optionally shows a
/// moving vehicle. Used for ride history and the simple tracking screen.
class TripRouteMap extends StatefulWidget {
  final gmaps.LatLng from;
  final gmaps.LatLng to;
  final bool isDark;
  final EdgeInsets padding;
  final MovingPoint? vehicle;
  final ValueChanged<RouteResult>? onRoute;
  final bool showInfoChip;
  final bool interactive;

  const TripRouteMap({
    super.key,
    required this.from,
    required this.to,
    required this.isDark,
    this.padding = EdgeInsets.zero,
    this.vehicle,
    this.onRoute,
    this.showInfoChip = true,
    this.interactive = true,
  });

  @override
  State<TripRouteMap> createState() => _TripRouteMapState();
}

class _TripRouteMapState extends State<TripRouteMap> {
  gmaps.GoogleMapController? _ctrl;
  RouteResult? _route;
  MapMarkerSet? _markers;
  bool _fitted = false;
  final ValueNotifier<MovingFrame?> _noVehicle = ValueNotifier<MovingFrame?>(null);

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void dispose() {
    _noVehicle.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_markers == null) {
      MapMarkers.load(View.of(context).devicePixelRatio).then((m) {
        if (mounted) setState(() => _markers = m);
      });
    }
  }

  @override
  void didUpdateWidget(covariant TripRouteMap old) {
    super.didUpdateWidget(old);
    if (old.from != widget.from || old.to != widget.to) {
      _route = null;
      _fitted = false;
      _loadRoute();
    } else if (old.padding != widget.padding) {
      _fitted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  Future<void> _loadRoute() async {
    final r = await DirectionsService.fetch(
      originLat: widget.from.latitude,
      originLng: widget.from.longitude,
      destLat: widget.to.latitude,
      destLng: widget.to.longitude,
    );
    if (!mounted) return;
    setState(() => _route = r);
    widget.onRoute?.call(r);
    _fit();
  }

  Future<void> _fit() async {
    final c = _ctrl;
    if (c == null || _fitted) return;
    final bounds = GeoUtils.boundsOf([
      ...?_route?.points,
      widget.from,
      widget.to,
    ]);
    if (bounds == null) return;
    try {
      await c.animateCamera(gmaps.CameraUpdate.newLatLngBounds(bounds, 48));
      _fitted = true;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final m = _markers;
    final dark = widget.isDark;

    return Stack(
      children: [
        ValueListenableBuilder<MovingFrame?>(
          valueListenable: widget.vehicle?.frame ?? _noVehicle,
          builder: (context, frame, _) => gmaps.GoogleMap(
            style: MapStyles.forBrightness(dark),
            padding: widget.padding,
            initialCameraPosition: gmaps.CameraPosition(target: widget.from, zoom: 13.5),
            onMapCreated: (c) {
              _ctrl = c;
              _fit();
            },
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            buildingsEnabled: false,
            scrollGesturesEnabled: widget.interactive,
            zoomGesturesEnabled: widget.interactive,
            // Lets the map be panned even when it sits inside a scrolling list.
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
            polylines: route == null
                ? const {}
                : route.followsRoads
                    ? MapUi.routeLine(id: 'trip', points: route.points, isDark: dark)
                    : MapUi.secondaryLine(id: 'trip', points: route.points, isDark: dark),
            markers: {
              gmaps.Marker(
                markerId: const gmaps.MarkerId('from'),
                position: widget.from,
                icon: m?.pickup ?? gmaps.BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 0.5),
                zIndexInt: 2,
              ),
              gmaps.Marker(
                markerId: const gmaps.MarkerId('to'),
                position: widget.to,
                icon: m?.destination ?? gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueOrange),
                anchor: const Offset(0.5, 0.95),
                zIndexInt: 3,
              ),
              if (frame != null && m != null)
                gmaps.Marker(
                  markerId: const gmaps.MarkerId('vehicle'),
                  position: frame.position,
                  icon: m.driverArrow,
                  rotation: frame.heading,
                  flat: true,
                  anchor: const Offset(0.5, 0.5),
                  zIndexInt: 5,
                ),
            },
          ),
        ),
        if (widget.showInfoChip && route != null)
          Positioned(
            left: 10,
            top: 10 + widget.padding.top,
            child: RouteInfoChip(
              duration: route.durationLabel,
              distance: route.distanceLabel,
              isDark: dark,
              approximate: !route.followsRoads,
            ),
          ),
      ],
    );
  }
}
