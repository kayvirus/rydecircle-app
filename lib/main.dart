// ─────────────────────────────────────────────────────────────────────────────
// RydeCircle — Rider App
// Flutter single-file entry point
//
// Screens
//   Auth         : Login  ·  Register (2-step)  ·  Forgot Password
//   Home tabs    : Browse Trips  ·  My Bookings  ·  Support  ·  Profile
//   Profile      : View  ·  Edit (NIN + NIN image + emergency contact + photo)
//                  Change Password
//   Booking      : Trip detail  ·  Seat picker  ·  Paystack checkout
//                  Booking confirmed  ·  Confirm dropoff
//
// Backend routes consumed (users.js)
//   POST   /api/users/register
//   POST   /api/users/auth/login
//   POST   /api/users/auth/forgot-password   (if added to backend)
//   GET    /api/users/me
//   PATCH  /api/users/me/profile
//   PATCH  /api/users/me/password
//
//   GET    /api/trips                         (public browse)
//   GET    /api/bookings                      (rider's own bookings)
//   POST   /api/bookings
//   POST   /api/drivers/me/trips/:id/bookings/:bid/passenger-confirm
//   GET    /api/support/tickets
//   POST   /api/support/tickets
//
//   POST   /api/upload/image                  (multipart, returns { url })
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeline_tile/timeline_tile.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  // Pass --dart-define=PAYSTACK_PUBLIC_KEY=pk_test_xxx at build time
  runApp(const RydeCircleApp());
}

// ─── Config ───────────────────────────────────────────────────────────────────
class AppConfig {
  static const apiBase = String.fromEnvironment(
      'API_BASE_URL', defaultValue: 'https://rydecircle-api.onrender.com');
  static const paystackKey = String.fromEnvironment('PAYSTACK_PUBLIC_KEY', defaultValue: '');
}

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF090D12);
const _kCard     = Color(0xFF111720);
const _kCardEl   = Color(0xFF18202C);
const _kBorder   = Color(0xFF252E3D);
const _kBrand    = Color(0xFF00C8F0);
const _kBrandD   = Color(0xFF0099BB);
const _kGreen    = Color(0xFF00D4AA);
const _kGreenD   = Color(0xFF00A882);
const _kAmber    = Color(0xFFFFBB33);
const _kRed      = Color(0xFFFF3B30);
const _kPurple   = Color(0xFFBF5AF2);
const _kTxt      = Color(0xFFE8EFF8);
const _kTxtSub   = Color(0xFFA8B4C0);
const _kTxtMuted = Color(0xFF5A6578);

const _kBrandGrad = LinearGradient(
  colors: [_kBrand, _kBrandD],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);
const _kGreenGrad = LinearGradient(
  colors: [_kGreen, _kGreenD],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);

// ─── Typography ───────────────────────────────────────────────────────────────
TextStyle _h(double s, {FontWeight w = FontWeight.w800, Color c = _kTxt}) =>
    GoogleFonts.spaceGrotesk(fontSize: s, fontWeight: w, color: c, letterSpacing: -0.4);
TextStyle _t(double s, {FontWeight w = FontWeight.w400, Color c = _kTxt}) =>
    GoogleFonts.inter(fontSize: s, fontWeight: w, color: c);

// ─── App ──────────────────────────────────────────────────────────────────────
class RydeCircleApp extends StatelessWidget {
  const RydeCircleApp({super.key});
  @override
  Widget build(BuildContext ctx) => MaterialApp(
    title: 'RydeCircle',
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    home: const _Bootstrap(),
  );

  ThemeData _theme() {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: _kBg,
      colorScheme: const ColorScheme.dark(primary: _kBrand, secondary: _kGreen, surface: _kCard),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: _kTxt, displayColor: _kTxt),
      appBarTheme: AppBarTheme(
          backgroundColor: _kCard, elevation: 0,
          titleTextStyle: _h(17), iconTheme: const IconThemeData(color: _kTxt),
          systemOverlayStyle: SystemUiOverlayStyle.light),
      cardTheme: CardThemeData(color: _kCard, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: _kBorder))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
          backgroundColor: _kBrand, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: _t(15, w: FontWeight.w700))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
          foregroundColor: _kTxt, side: const BorderSide(color: _kBorder),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: _kCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: _ib(), enabledBorder: _ib(), focusedBorder: _ib(focused: true),
          errorBorder: _ib(error: true), focusedErrorBorder: _ib(focused: true, error: true),
          labelStyle: _t(13, c: _kTxtMuted), prefixIconColor: _kTxtMuted,
          errorStyle: _t(11, c: _kRed)),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _kCard,
          indicatorColor: _kBrand.withOpacity(0.12),
          iconTheme: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? const IconThemeData(color: _kBrand, size: 22)
                  : const IconThemeData(color: _kTxtMuted, size: 22)),
          labelTextStyle: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? _t(10, w: FontWeight.w700, c: _kBrand)
                  : _t(10, c: _kTxtMuted))),
    );
  }

  OutlineInputBorder _ib({bool focused = false, bool error = false}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
          color: error ? _kRed : focused ? _kBrand : _kBorder,
          width: focused || error ? 1.5 : 1));
}

// ─── Bootstrap ────────────────────────────────────────────────────────────────
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}
class _BootstrapState extends State<_Bootstrap> {
  final _store = StorageService();
  bool _loading = true;
  AuthSession? _session;
  @override
  void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    final s = await _store.getSession();
    if (mounted) setState(() { _session = s; _loading = false; });
  }
  @override
  Widget build(BuildContext ctx) {
    if (_loading) return const _Splash();
    if (_session != null && _session!.token.isNotEmpty)
      return HomePage(store: _store, session: _session!);
    return LoginPage(store: _store);
  }
}

// ─── Splash ───────────────────────────────────────────────────────────────────
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: _kBg,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const _Logo(size: 80)
          .animate().scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut, duration: 900.ms),
      const Gap(28),
      SizedBox(width: 120, child: LinearProgressIndicator(
          backgroundColor: _kBorder, color: _kBrand,
          borderRadius: BorderRadius.circular(4)))
          .animate().fadeIn(delay: 500.ms),
    ])),
  );
}

// ─── Logo widget ──────────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  const _Logo({this.size = 40});
  final double size;
  @override
  Widget build(BuildContext ctx) => Image.asset('assets/logo.png',
      width: size, height: size,
      errorBuilder: (_, __, ___) => Container(
        width: size, height: size,
        decoration: BoxDecoration(gradient: _kBrandGrad,
            borderRadius: BorderRadius.circular(size * 0.26),
            boxShadow: [BoxShadow(color: _kBrand.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))]),
        child: Icon(Icons.directions_car_rounded, color: Colors.white, size: size * 0.52),
      ));
}

// ═════════════════════════════════════════════════════════════════════════════
// MODELS
// ═════════════════════════════════════════════════════════════════════════════

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override String toString() => message;
}

class RiderUser {
  final String id, email, phone;
  final String firstName, lastName;
  final String? area, status, nin, ninImageUrl;
  final String? emergencyName, emergencyPhone, emergencyRelationship;
  final String? profileImageUrl;
  final bool profileCompleted;
  RiderUser({
    required this.id, required this.email, required this.phone,
    required this.firstName, required this.lastName,
    this.area, this.status, this.nin, this.ninImageUrl,
    this.emergencyName, this.emergencyPhone, this.emergencyRelationship,
    this.profileImageUrl, this.profileCompleted = false,
  });
  String get fullName => '$firstName $lastName'.trim();
  factory RiderUser.fromJson(Map<String, dynamic> j) => RiderUser(
    id:                      _s(j, ['id']),
    email:                   _s(j, ['email']),
    phone:                   _s(j, ['phone']),
    firstName:               _s(j, ['first_name']),
    lastName:                _s(j, ['last_name']),
    area:                    j['area']?.toString(),
    status:                  j['status']?.toString(),
    nin:                     j['nin']?.toString(),
    ninImageUrl:             j['nin_image_url']?.toString(),
    emergencyName:           j['emergency_contact_name']?.toString(),
    emergencyPhone:          j['emergency_contact_phone']?.toString(),
    emergencyRelationship:   j['emergency_contact_relationship']?.toString(),
    profileImageUrl:         j['profile_image_url']?.toString(),
    profileCompleted:        j['profile_completed'] == true,
  );
  Map<String, dynamic> toJson() => {
    'id': id, 'email': email, 'phone': phone,
    'first_name': firstName, 'last_name': lastName,
    'area': area, 'status': status, 'nin': nin,
    'nin_image_url': ninImageUrl,
    'emergency_contact_name': emergencyName,
    'emergency_contact_phone': emergencyPhone,
    'emergency_contact_relationship': emergencyRelationship,
    'profile_image_url': profileImageUrl,
    'profile_completed': profileCompleted,
  };
}

class AuthSession {
  final String token;
  final RiderUser user;
  AuthSession({required this.token, required this.user});
  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
    token: _s(j, ['token']),
    user:  RiderUser.fromJson(Map<String, dynamic>.from(
        j['user'] is Map ? j['user'] as Map : j)),
  );
  Map<String, dynamic> toJson() => {'token': token, 'user': user.toJson()};
}

class TripResult {
  final String id, status, pickupStop, dropoffStop, departureDate, departureTime;
  final String? route, tripType, driverName, driverPhone, plateNumber;
  final double fare;
  final int seatsAvailable, seatsBooked;
  int get seatsLeft => seatsAvailable - seatsBooked;
  TripResult({
    required this.id, required this.status, required this.pickupStop,
    required this.dropoffStop, required this.departureDate, required this.departureTime,
    required this.fare, required this.seatsAvailable, required this.seatsBooked,
    this.route, this.tripType, this.driverName, this.driverPhone, this.plateNumber,
  });
  factory TripResult.fromJson(Map<String, dynamic> j) => TripResult(
    id:             _s(j, ['id']),
    status:         _s(j, ['status'], fb: 'open'),
    pickupStop:     _s(j, ['pickup_stop']),
    dropoffStop:    _s(j, ['dropoff_stop']),
    departureDate:  _s(j, ['departure_date']),
    departureTime:  _s(j, ['departure_time']),
    fare:           _d(j['fare']),
    seatsAvailable: _i(j['seats_available']),
    seatsBooked:    _i(j['seats_booked']),
    route:          j['route']?.toString(),
    tripType:       j['trip_type']?.toString(),
    driverName:     j['driver_name']?.toString(),
    driverPhone:    j['driver_phone']?.toString(),
    plateNumber:    j['plate_number']?.toString(),
  );
}

class Booking {
  final String id, tripId, status, paymentStatus, pickupStop, dropoffStop;
  final int seats;
  final double fare;
  final bool passengerConfirmedDropoff;
  final String? route, departureDate, departureTime, tripStatus, paymentRef;
  Booking({
    required this.id, required this.tripId, required this.status,
    required this.paymentStatus, required this.pickupStop,
    required this.dropoffStop, required this.seats, required this.fare,
    required this.passengerConfirmedDropoff,
    this.route, this.departureDate, this.departureTime,
    this.tripStatus, this.paymentRef,
  });
  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    id:                        _s(j, ['id']),
    tripId:                    _s(j, ['trip_id']),
    status:                    _s(j, ['status'], fb: 'unknown'),
    paymentStatus:             _s(j, ['payment_status'], fb: 'pending'),
    pickupStop:                _s(j, ['pickup_stop']),
    dropoffStop:               _s(j, ['dropoff_stop']),
    seats:                     _i(j['seats']),
    fare:                      _d(j['fare']),
    passengerConfirmedDropoff: j['passenger_confirmed_dropoff'] == true,
    route:                     j['route']?.toString(),
    departureDate:             j['departure_date']?.toString(),
    departureTime:             j['departure_time']?.toString(),
    tripStatus:                j['trip_status']?.toString(),
    paymentRef:                j['payment_ref']?.toString(),
  );
}

class SupportTicket {
  final String id, subject, message, status;
  final String? category, createdAt;
  SupportTicket({required this.id, required this.subject, required this.message,
    required this.status, required this.category, required this.createdAt});
  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
    id:        _s(j, ['id']),
    subject:   _s(j, ['subject'], fb: 'Untitled'),
    message:   _s(j, ['message', 'description']),
    status:    _s(j, ['status'], fb: 'open'),
    category:  j['category']?.toString(),
    createdAt: j['created_at']?.toString(),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// API SERVICE
// ═════════════════════════════════════════════════════════════════════════════

class ApiService {
  ApiService(this._store);
  final StorageService _store;
  static const _t = Duration(seconds: 30);

  String get _base {
    var b = AppConfig.apiBase.trim();
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    if (!b.endsWith('/api')) b = '$b/api';
    return b;
  }

  Uri _u(String p) => Uri.parse('$_base${p.startsWith('/') ? p : '/$p'}');

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth) {
      final s = await _store.getSession();
      if (s != null && s.token.isNotEmpty) h['Authorization'] = 'Bearer ${s.token}';
    }
    return h;
  }

  Never _throw(Object e) {
    if (e is ApiException) throw e;
    if (e is TimeoutException) throw ApiException('Server took too long to respond');
    if (e is SocketException) throw ApiException('No internet connection');
    throw ApiException(e.toString().replaceFirst('Exception: ', ''));
  }

  Map<String, dynamic> _decode(http.Response r) {
    dynamic d;
    try { d = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body); }
    catch (_) { throw ApiException('Invalid server response'); }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (d is Map<String, dynamic>) return d;
      if (d is Map) return Map<String, dynamic>.from(d);
      return {'data': d};
    }
    String msg = 'Request failed (${r.statusCode})';
    if (d is Map) {
      final m = Map<String, dynamic>.from(d);
      final p = m['error'] ?? m['message'] ?? m['detail'];
      if (p != null && p.toString().trim().isNotEmpty) msg = p.toString();
    }
    throw ApiException(msg, statusCode: r.statusCode);
  }

  // ── Auth ─────────────────────────────────────────────────────────────────
  Future<AuthSession> register({
    required String firstName, required String lastName,
    required String email, required String phone, required String password,
    String? area,
  }) async {
    try {
      final r = await http.post(_u('/users/register'),
          headers: await _headers(),
          body: jsonEncode({
            'first_name': firstName.trim(), 'last_name': lastName.trim(),
            'email': email.trim().toLowerCase(), 'phone': phone.trim(),
            'password': password, if (area != null && area.isNotEmpty) 'area': area,
          })).timeout(_t);
      final d = _decode(r);
      final session = AuthSession.fromJson(d);
      await _store.saveSession(session);
      return session;
    } catch (e) { _throw(e); }
  }

  Future<AuthSession> login(String email, String password) async {
    try {
      final r = await http.post(_u('/users/auth/login'),
          headers: await _headers(),
          body: jsonEncode({'email': email.trim().toLowerCase(), 'password': password}))
          .timeout(_t);
      final d = _decode(r);
      final session = AuthSession.fromJson(d);
      await _store.saveSession(session);
      return session;
    } catch (e) { _throw(e); }
  }

  Future<void> forgotPassword(String email) async {
    try {
      final r = await http.post(_u('/users/auth/forgot-password'),
          headers: await _headers(),
          body: jsonEncode({'email': email.trim().toLowerCase()})).timeout(_t);
      _decode(r);
    } catch (e) { _throw(e); }
  }

  // ── Profile ───────────────────────────────────────────────────────────────
  Future<RiderUser> getMe() async {
    try {
      final r = await http.get(_u('/users/me'), headers: await _headers(auth: true)).timeout(_t);
      final d = _decode(r);
      final u = d['user'] is Map ? Map<String, dynamic>.from(d['user'] as Map) : d;
      return RiderUser.fromJson(u);
    } catch (e) { _throw(e); }
  }

  Future<RiderUser> updateProfile(Map<String, dynamic> fields) async {
    try {
      final r = await http.patch(_u('/users/me/profile'),
          headers: await _headers(auth: true),
          body: jsonEncode(fields)).timeout(_t);
      final d = _decode(r);
      final u = d['user'] is Map ? Map<String, dynamic>.from(d['user'] as Map) : d;
      final user = RiderUser.fromJson(u);
      // Refresh stored session with updated user
      final session = await _store.getSession();
      if (session != null) await _store.saveSession(AuthSession(token: session.token, user: user));
      return user;
    } catch (e) { _throw(e); }
  }

  Future<void> changePassword({required String current, required String next}) async {
    try {
      final r = await http.patch(_u('/users/me/password'),
          headers: await _headers(auth: true),
          body: jsonEncode({'current_password': current, 'new_password': next})).timeout(_t);
      _decode(r);
    } catch (e) { _throw(e); }
  }

  // ── Upload image (multipart) ──────────────────────────────────────────────
  // Backend should accept POST /api/upload/image with field "file"
  // Returns { url: "https://..." }
  Future<String> uploadImage(File file, {String field = 'file'}) async {
    try {
      final s = await _store.getSession();
      final req = http.MultipartRequest('POST', _u('/upload/image'));
      if (s != null && s.token.isNotEmpty) req.headers['Authorization'] = 'Bearer ${s.token}';
      req.files.add(await http.MultipartFile.fromPath(field, file.path));
      final streamed = await req.send().timeout(_t);
      final res = await http.Response.fromStream(streamed);
      final d = _decode(res);
      final url = d['url']?.toString() ?? d['file_url']?.toString() ?? '';
      if (url.isEmpty) throw ApiException('Upload succeeded but no URL returned');
      return url;
    } catch (e) { _throw(e); }
  }

  // ── Trips ─────────────────────────────────────────────────────────────────
  Future<List<TripResult>> searchTrips({String? date}) async {
    try {
      final params = <String, String>{'status': 'open'};
      if (date != null && date.isNotEmpty) params['date'] = date;
      final r = await http.get(_u('/trips').replace(queryParameters: params),
          headers: await _headers(auth: true)).timeout(_t);
      final d = _decode(r);
      final list = d['trips'] is List ? d['trips'] as List : [];
      return list.map((e) => TripResult.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) { _throw(e); }
  }

  // ── Bookings ──────────────────────────────────────────────────────────────
  Future<List<Booking>> getMyBookings() async {
    try {
      final r = await http.get(_u('/bookings'), headers: await _headers(auth: true)).timeout(_t);
      final d = _decode(r);
      final list = d['bookings'] is List ? d['bookings'] as List : [];
      return list.map((e) => Booking.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) { _throw(e); }
  }

  Future<Booking> createBooking({required String tripId, required int seats, String? paymentRef}) async {
    try {
      final s = await _store.getSession();
      final r = await http.post(_u('/bookings'),
          headers: await _headers(auth: true),
          body: jsonEncode({
            'trip_id': tripId, 'user_id': s?.user.id, 'seats': seats,
            if (paymentRef != null) 'payment_ref': paymentRef,
          })).timeout(_t);
      final d = _decode(r);
      final b = d['booking'] is Map ? Map<String, dynamic>.from(d['booking'] as Map) : d;
      return Booking.fromJson(b);
    } catch (e) { _throw(e); }
  }

  Future<Map<String, dynamic>> confirmDropoff(String tripId, String bookingId) async {
    try {
      final r = await http.post(
          _u('/drivers/me/trips/$tripId/bookings/$bookingId/passenger-confirm'),
          headers: await _headers(auth: true), body: '{}').timeout(_t);
      return _decode(r);
    } catch (e) { _throw(e); }
  }

  // ── Support ───────────────────────────────────────────────────────────────
  Future<List<SupportTicket>> getTickets() async {
    try {
      final r = await http.get(_u('/support/tickets'), headers: await _headers(auth: true)).timeout(_t);
      final d = _decode(r);
      final list = d['tickets'] is List ? d['tickets'] as List
          : d['data'] is List ? d['data'] as List : [];
      return list.map((e) => SupportTicket.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) { _throw(e); }
  }

  Future<void> createTicket({required String subject, required String category, required String message}) async {
    try {
      final r = await http.post(_u('/support/tickets'),
          headers: await _headers(auth: true),
          body: jsonEncode({'subject': subject.trim(), 'category': category.trim(), 'message': message.trim()}))
          .timeout(_t);
      _decode(r);
    } catch (e) { _throw(e); }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STORAGE
// ═════════════════════════════════════════════════════════════════════════════
class StorageService {
  static const _k = 'rider_session_v2';
  Future<void> saveSession(AuthSession s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(s.toJson()));
  }
  Future<AuthSession?> getSession() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null || raw.isEmpty) return null;
    try { return AuthSession.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map)); }
    catch (_) { await p.remove(_k); return null; }
  }
  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_k);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message, this.sub});
  final IconData icon; final String message; final String? sub;
  @override
  Widget build(BuildContext ctx) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 72, height: 72,
          decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder)),
          child: Icon(icon, size: 32, color: _kTxtMuted))
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.05, duration: 2.seconds, curve: Curves.easeInOut),
      const Gap(16),
      Text(message, style: _t(14, c: _kTxtMuted), textAlign: TextAlign.center),
      if (sub != null) ...[const Gap(6), Text(sub!, style: _t(12, c: _kTxtMuted), textAlign: TextAlign.center)],
    ]),
  ));
}

class _ErrBar extends StatelessWidget {
  const _ErrBar({required this.message, required this.onRetry});
  final String message; final VoidCallback onRetry;
  @override
  Widget build(BuildContext ctx) => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _kRed.withOpacity(0.06), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kRed.withOpacity(0.2))),
    child: Row(children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: _kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.wifi_off_rounded, color: _kRed, size: 18)),
      const Gap(12),
      Expanded(child: Text(message, style: _t(13, c: _kRed))),
      TextButton(onPressed: onRetry, child: Text('Retry', style: _t(13, c: _kBrand, w: FontWeight.w600))),
    ]),
  );
}

Widget _shimCard({double h = 80}) => Shimmer.fromColors(
  baseColor: _kCard, highlightColor: _kCardEl,
  child: Container(height: h, margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16))));

Widget _shims({int n = 4, double h = 80}) =>
    Column(children: List.generate(n, (_) => _shimCard(h: h)));

class _Spinner extends StatelessWidget {
  const _Spinner({this.color = Colors.white});
  final Color color;
  @override
  Widget build(BuildContext ctx) => SizedBox(width: 20, height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: color));
}

Widget _secLabel(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(color: _kBrand, borderRadius: BorderRadius.circular(2))),
    const Gap(8),
    Text(t.toUpperCase(), style: _t(11, w: FontWeight.w700, c: _kTxtMuted).copyWith(letterSpacing: 0.9)),
  ]),
);

void _snack(BuildContext ctx, String msg, {Color bg = _kGreen}) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg, style: _t(14, c: Colors.white)), backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

// ═════════════════════════════════════════════════════════════════════════════
// LOGIN PAGE
// ═════════════════════════════════════════════════════════════════════════════

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.store});
  final StorageService store;
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final _fk = GlobalKey<FormState>();
  final _eCtrl = TextEditingController();
  final _pCtrl = TextEditingController();
  late final ApiService _api;
  bool _loading = false, _obs = true;
  String? _err;
  @override
  void initState() { super.initState(); _api = ApiService(widget.store); }
  @override
  void dispose() { _eCtrl.dispose(); _pCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_fk.currentState!.validate()) return;
    setState(() { _loading = true; _err = null; });
    try {
      final s = await _api.login(_eCtrl.text.trim(), _pCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomePage(store: widget.store, session: s)));
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    body: Stack(children: [
      Positioned(top: -100, left: -80, child: Container(width: 320, height: 320,
          decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_kBrand.withOpacity(0.12), Colors.transparent])))),
      Positioned(bottom: -80, right: -60, child: Container(width: 260, height: 260,
          decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_kGreen.withOpacity(0.08), Colors.transparent])))),
      SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
          child: Column(children: [
            const _Logo(size: 76)
                .animate().scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut, duration: 800.ms),
            const Gap(18),
            Text('RydeCircle', style: _h(30)).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
            const Gap(4),
            Text('Your ride, your way', style: _t(15, c: _kTxtMuted)).animate().fadeIn(delay: 300.ms),
            const Gap(32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _kBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 12))]),
              child: Column(children: [
                Form(key: _fk, child: Column(children: [
                  TextFormField(controller: _eCtrl, keyboardType: TextInputType.emailAddress,
                      style: _t(15), textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email address',
                          prefixIcon: Icon(Icons.mail_outline_rounded)),
                      validator: (v) { final val = (v ?? '').trim(); if (val.isEmpty) return 'Required';
                        if (!val.contains('@')) return 'Invalid email'; return null; }),
                  const Gap(14),
                  TextFormField(controller: _pCtrl, obscureText: _obs,
                      style: _t(15), textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                              onPressed: () => setState(() => _obs = !_obs),
                              icon: Icon(_obs ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: _kTxtMuted))),
                      validator: (v) { if ((v ?? '').isEmpty) return 'Required'; return null; }),
                ])),
                if (_err != null) ...[const Gap(14), _errBox(_err!)],
                const Gap(20),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading ? const _Spinner() : Text('Sign In', style: _t(16, w: FontWeight.w700, c: Colors.white)),
                )),
                const Gap(10),
                TextButton(
                  onPressed: () => Navigator.push(ctx, MaterialPageRoute(
                      builder: (_) => _ForgotPage(api: _api))),
                  child: Text('Forgot password?', style: _t(13, c: _kBrand)),
                ),
              ]),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
            const Gap(24),
            OutlinedButton(
              onPressed: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => RegisterPage(store: widget.store))),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              child: Text('Create an Account', style: _t(15, w: FontWeight.w600)),
            ).animate().fadeIn(delay: 500.ms),
          ]),
        ),
      ))),
    ]),
  );

  Widget _errBox(String msg) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _kRed.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRed.withOpacity(0.25))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: _kRed, size: 16), const Gap(8),
      Expanded(child: Text(msg, style: _t(13, c: _kRed))),
    ]),
  ).animate().shake(hz: 4, duration: 400.ms);
}

// ─── Forgot Password ──────────────────────────────────────────────────────────
class _ForgotPage extends StatefulWidget {
  const _ForgotPage({required this.api});
  final ApiService api;
  @override State<_ForgotPage> createState() => _ForgotPageState();
}
class _ForgotPageState extends State<_ForgotPage> {
  final _ctrl = TextEditingController();
  bool _loading = false, _sent = false;
  String? _err;
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final email = _ctrl.text.trim();
    if (!email.contains('@')) { setState(() => _err = 'Enter a valid email'); return; }
    setState(() { _loading = true; _err = null; });
    try {
      await widget.api.forgotPassword(email);
      if (mounted) setState(() { _sent = true; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _err = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Reset Password', style: _h(17))),
    body: Padding(padding: const EdgeInsets.all(24), child: _sent
        ? Column(mainAxisSize: MainAxisSize.min, children: [
            const Gap(40),
            Container(width: 72, height: 72,
                decoration: BoxDecoration(gradient: _kGreenGrad, shape: BoxShape.circle),
                child: const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 36))
                .animate().scale(begin: const Offset(0, 0), curve: Curves.elasticOut, duration: 800.ms),
            const Gap(20),
            Text('Check your email', style: _h(22), textAlign: TextAlign.center),
            const Gap(8),
            Text('We sent a reset link to ${_ctrl.text.trim()}',
                style: _t(14, c: _kTxtSub), textAlign: TextAlign.center),
            const Gap(32),
            SizedBox(width: double.infinity, child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Back to Sign In', style: _t(15)))),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Gap(8),
            Text('Enter your email and we\'ll send you a password reset link.',
                style: _t(14, c: _kTxtSub)),
            const Gap(24),
            TextFormField(controller: _ctrl, keyboardType: TextInputType.emailAddress,
                style: _t(15), decoration: const InputDecoration(
                    labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded))),
            if (_err != null) ...[const Gap(10),
              Text(_err!, style: _t(13, c: _kRed))],
            const Gap(20),
            FilledButton(onPressed: _loading ? null : _send,
                child: _loading ? const _Spinner() : Text('Send Reset Link', style: _t(15, w: FontWeight.w700, c: Colors.white))),
          ])),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// REGISTER PAGE  (2 steps)
//   Step 1: Basic info — first name, last name, email, phone, password
//   Step 2: Profile   — NIN, NIN image, emergency contact, profile photo
//           (all optional at registration; profile_completed tracks this)
// ═════════════════════════════════════════════════════════════════════════════

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.store});
  final StorageService store;
  @override State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _step1Key = GlobalKey<FormState>();
  int _step = 0; // 0 = basic, 1 = profile details

  // Step 1
  final _fnCtrl   = TextEditingController();
  final _lnCtrl   = TextEditingController();
  final _emCtrl   = TextEditingController();
  final _phCtrl   = TextEditingController();
  final _pwCtrl   = TextEditingController();
  final _pw2Ctrl  = TextEditingController();
  bool _obs = true, _obs2 = true;

  // Step 2 – stored after account creation so we can upload separately
  late ApiService _api;
  AuthSession? _session;
  bool _loading = false;
  String? _err;

  @override
  void initState() { super.initState(); _api = ApiService(widget.store); }
  @override
  void dispose() {
    for (final c in [_fnCtrl,_lnCtrl,_emCtrl,_phCtrl,_pwCtrl,_pw2Ctrl]) c.dispose();
    super.dispose();
  }

  // ── Step 1: create account ────────────────────────────────────────────────
  Future<void> _submitStep1() async {
    FocusScope.of(context).unfocus();
    if (!_step1Key.currentState!.validate()) return;
    if (_pwCtrl.text != _pw2Ctrl.text) { setState(() => _err = 'Passwords do not match'); return; }
    setState(() { _loading = true; _err = null; });
    try {
      final s = await _api.register(
        firstName: _fnCtrl.text.trim(), lastName: _lnCtrl.text.trim(),
        email: _emCtrl.text.trim(), phone: _phCtrl.text.trim(), password: _pwCtrl.text,
      );
      if (!mounted) return;
      setState(() { _session = s; _step = 1; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _err = '$e'; _loading = false; });
    }
  }

  // ── Step 2: skip to app ───────────────────────────────────────────────────
  void _skipToApp() {
    if (_session == null) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomePage(store: widget.store, session: _session!)),
        (_) => false);
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(
      title: Text(_step == 0 ? 'Create Account' : 'Complete Profile', style: _h(17)),
      leading: _step == 1
          ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() { _step = 0; _err = null; }))
          : null,
    ),
    body: Column(children: [
      // Progress indicator
      Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 0), child: Row(children: [
        _stepDot(0, 'Account', _step >= 0),
        Expanded(child: Container(height: 2, color: _step >= 1 ? _kBrand : _kBorder)),
        _stepDot(1, 'Profile', _step >= 1),
      ])),
      const Gap(4),
      Expanded(child: _step == 0 ? _step1Form() : _Step2Form(
        api: _api, session: _session!, store: widget.store,
        onComplete: _skipToApp,
      )),
    ]),
  );

  Widget _stepDot(int n, String label, bool active) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 28, height: 28,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: active ? _kBrand : _kBorder),
        child: Center(child: Text('${n+1}',
            style: _t(12, w: FontWeight.w700, c: active ? Colors.white : _kTxtMuted)))),
    const Gap(4),
    Text(label, style: _t(10, c: active ? _kBrand : _kTxtMuted, w: active ? FontWeight.w600 : FontWeight.w400)),
  ]);

  Widget _step1Form() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
    child: Form(key: _step1Key, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _secLabel('Your Name'),
      Row(children: [
        Expanded(child: TextFormField(controller: _fnCtrl, style: _t(15), textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'First name'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null)),
        const Gap(12),
        Expanded(child: TextFormField(controller: _lnCtrl, style: _t(15), textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Last name'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null)),
      ]),
      const Gap(14),
      _secLabel('Contact Info'),
      TextFormField(controller: _emCtrl, keyboardType: TextInputType.emailAddress,
          style: _t(15), textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline_rounded)),
          validator: (v) { final val = (v ?? '').trim();
            if (val.isEmpty) return 'Required'; if (!val.contains('@')) return 'Invalid email'; return null; }),
      const Gap(14),
      TextFormField(controller: _phCtrl, keyboardType: TextInputType.phone,
          style: _t(15), textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined)),
          validator: (v) { final val = (v ?? '').trim();
            if (val.isEmpty) return 'Required'; if (val.length < 7) return 'Invalid phone'; return null; }),
      const Gap(20),
      _secLabel('Password'),
      TextFormField(controller: _pwCtrl, obscureText: _obs, style: _t(15), textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: 'Password (min 8 chars)',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(onPressed: () => setState(() => _obs = !_obs),
                  icon: Icon(_obs ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _kTxtMuted))),
          validator: (v) { if ((v ?? '').length < 8) return 'At least 8 characters'; return null; }),
      const Gap(14),
      TextFormField(controller: _pw2Ctrl, obscureText: _obs2, style: _t(15),
          textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _submitStep1(),
          decoration: InputDecoration(labelText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(onPressed: () => setState(() => _obs2 = !_obs2),
                  icon: Icon(_obs2 ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _kTxtMuted))),
          validator: (v) { if ((v ?? '').isEmpty) return 'Required'; return null; }),
      if (_err != null) ...[const Gap(14), Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _kRed.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kRed.withOpacity(0.25))),
          child: Row(children: [const Icon(Icons.error_outline, color: _kRed, size: 16), const Gap(8),
            Expanded(child: Text(_err!, style: _t(13, c: _kRed)))])).animate().shake(hz: 4)],
      const Gap(24),
      FilledButton(onPressed: _loading ? null : _submitStep1,
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
          child: _loading ? const _Spinner()
              : Text('Continue', style: _t(16, w: FontWeight.w700, c: Colors.white))),
      const Gap(12),
      Center(child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Already have an account? Sign In', style: _t(13, c: _kBrand)))),
    ])),
  );
}

// ─── Step 2 — Profile details (stateful widget, can be reused from profile edit) ─
class _Step2Form extends StatefulWidget {
  const _Step2Form({required this.api, required this.session,
    required this.store, required this.onComplete, this.existingUser});
  final ApiService api;
  final AuthSession session;
  final StorageService store;
  final VoidCallback onComplete;
  final RiderUser? existingUser;
  @override State<_Step2Form> createState() => _Step2FormState();
}

class _Step2FormState extends State<_Step2Form> {
  final _picker = ImagePicker();

  // Profile photo
  File? _profileFile;
  String? _profileUrl;
  bool _uploadingProfile = false;

  // NIN
  final _ninCtrl = TextEditingController();
  File? _ninFile;
  String? _ninUrl;
  bool _uploadingNin = false;

  // Emergency contact
  final _enCtrl  = TextEditingController(); // name
  final _epCtrl  = TextEditingController(); // phone
  final _erCtrl  = TextEditingController(); // relationship

  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final u = widget.existingUser;
    if (u != null) {
      _ninCtrl.text = u.nin ?? '';
      _ninUrl       = u.ninImageUrl;
      _profileUrl   = u.profileImageUrl;
      _enCtrl.text  = u.emergencyName ?? '';
      _epCtrl.text  = u.emergencyPhone ?? '';
      _erCtrl.text  = u.emergencyRelationship ?? '';
    }
  }
  @override
  void dispose() {
    for (final c in [_ninCtrl, _enCtrl, _epCtrl, _erCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isProfile) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Gap(8),
        Container(width: 36, height: 4, decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
        const Gap(16),
        ListTile(leading: const Icon(Icons.camera_alt_outlined, color: _kBrand),
            title: Text('Take photo', style: _t(15)),
            onTap: () => Navigator.pop(context, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined, color: _kBrand),
            title: Text('Choose from gallery', style: _t(15)),
            onTap: () => Navigator.pop(context, ImageSource.gallery)),
        const Gap(8),
      ])),
    );
    if (src == null) return;
    final picked = await _picker.pickImage(source: src, imageQuality: 80,
        maxWidth: isProfile ? 600 : 1200, maxHeight: isProfile ? 600 : 1600);
    if (picked == null) return;
    final file = File(picked.path);

    if (isProfile) {
      setState(() { _profileFile = file; _uploadingProfile = true; });
      try {
        final url = await widget.api.uploadImage(file);
        if (mounted) setState(() { _profileUrl = url; _uploadingProfile = false; });
      } catch (e) {
        if (mounted) { setState(() => _uploadingProfile = false); _snack(context, 'Upload failed: $e', bg: _kRed); }
      }
    } else {
      setState(() { _ninFile = file; _uploadingNin = true; });
      try {
        final url = await widget.api.uploadImage(file);
        if (mounted) setState(() { _ninUrl = url; _uploadingNin = false; });
      } catch (e) {
        if (mounted) { setState(() => _uploadingNin = false); _snack(context, 'Upload failed: $e', bg: _kRed); }
      }
    }
  }

  Future<void> _save() async {
    final nin = _ninCtrl.text.trim();
    if (nin.isNotEmpty && !RegExp(r'^\d{11}$').hasMatch(nin)) {
      setState(() => _err = 'NIN must be exactly 11 digits'); return;
    }
    final anyEmergency = _enCtrl.text.trim().isNotEmpty
        || _epCtrl.text.trim().isNotEmpty || _erCtrl.text.trim().isNotEmpty;
    if (anyEmergency && (_enCtrl.text.trim().isEmpty || _epCtrl.text.trim().isEmpty || _erCtrl.text.trim().isEmpty)) {
      setState(() => _err = 'Fill in all three emergency contact fields'); return;
    }
    setState(() { _saving = true; _err = null; });
    try {
      final fields = <String, dynamic>{};
      if (nin.isNotEmpty)            fields['nin'] = nin;
      if (_ninUrl != null)           fields['nin_image_url'] = _ninUrl;
      if (_profileUrl != null)       fields['profile_image_url'] = _profileUrl;
      if (_enCtrl.text.trim().isNotEmpty) {
        fields['emergency_contact_name']         = _enCtrl.text.trim();
        fields['emergency_contact_phone']        = _epCtrl.text.trim();
        fields['emergency_contact_relationship'] = _erCtrl.text.trim();
      }
      if (fields.isNotEmpty) await widget.api.updateProfile(fields);
      if (!mounted) return;
      widget.onComplete();
    } catch (e) {
      if (mounted) setState(() { _err = '$e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext ctx) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

      // ── Profile photo ─────────────────────────────────────────────────────
      _secLabel('Profile Photo'),
      Center(child: Stack(children: [
        GestureDetector(
          onTap: () => _pickImage(true),
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: _kBrand, width: 2),
                color: _kCardEl),
            child: ClipOval(child: _profileFile != null
                ? Image.file(_profileFile!, fit: BoxFit.cover)
                : _profileUrl != null
                    ? CachedNetworkImage(imageUrl: _profileUrl!, fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(child: _Spinner(color: _kBrand)),
                        errorWidget: (_, __, ___) => const Icon(Icons.person_rounded, size: 44, color: _kTxtMuted))
                    : const Icon(Icons.person_rounded, size: 44, color: _kTxtMuted)),
          ),
        ),
        if (_uploadingProfile)
          Positioned.fill(child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
              child: const Center(child: _Spinner(color: _kBrand)))),
        Positioned(bottom: 0, right: 0, child: GestureDetector(
          onTap: () => _pickImage(true),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(gradient: _kBrandGrad, shape: BoxShape.circle,
                border: Border.all(color: _kBg, width: 2)),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15)),
        )),
      ])),
      const Gap(6),
      Center(child: Text('Tap to add photo', style: _t(12, c: _kTxtMuted))),

      const Gap(24),

      // ── NIN ───────────────────────────────────────────────────────────────
      _secLabel('Identity Verification'),
      _infoBox('Your NIN (National Identification Number) is required to complete your profile and gain full access to all features.'),
      const Gap(12),
      TextFormField(
        controller: _ninCtrl, keyboardType: TextInputType.number,
        style: _t(15), maxLength: 11,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'NIN (11 digits)',
            prefixIcon: Icon(Icons.badge_outlined), counterText: ''),
      ),
      const Gap(14),
      // NIN image picker
      GestureDetector(
        onTap: () => _pickImage(false),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _ninFile != null || _ninUrl != null ? _kBrand.withOpacity(0.06) : _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _ninFile != null || _ninUrl != null
                ? _kBrand.withOpacity(0.5) : _kBorder, width: _ninFile != null ? 1.5 : 1),
          ),
          child: _uploadingNin
              ? const Center(child: Padding(padding: EdgeInsets.all(8), child: _Spinner(color: _kBrand)))
              : _ninFile != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(10),
                      child: Image.file(_ninFile!, height: 140, width: double.infinity, fit: BoxFit.cover))
                  : _ninUrl != null
                      ? CachedNetworkImage(imageUrl: _ninUrl!, height: 140, width: double.infinity, fit: BoxFit.cover,
                          imageBuilder: (_, img) => ClipRRect(borderRadius: BorderRadius.circular(10),
                              child: Image(image: img, fit: BoxFit.cover)))
                      : Row(children: [
                          Container(width: 44, height: 44,
                              decoration: BoxDecoration(color: _kBrand.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.upload_rounded, color: _kBrand, size: 22)),
                          const Gap(14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Upload NIN image / slip', style: _t(14, w: FontWeight.w600)),
                            Text('Photo of your NIN card or NIMC slip', style: _t(12, c: _kTxtMuted)),
                          ])),
                          const Icon(Icons.chevron_right_rounded, color: _kTxtMuted, size: 20),
                        ]),
        ),
      ),
      if (_ninFile != null || _ninUrl != null) ...[
        const Gap(8),
        Row(children: [
          const Icon(Icons.check_circle_rounded, color: _kGreen, size: 14), const Gap(5),
          Text('NIN image uploaded', style: _t(12, c: _kGreen)),
          const Spacer(),
          TextButton(onPressed: () => _pickImage(false),
              child: Text('Change', style: _t(12, c: _kBrand))),
        ]),
      ],

      const Gap(24),

      // ── Emergency contact ─────────────────────────────────────────────────
      _secLabel('Emergency Contact'),
      _infoBox('Provide one emergency contact. This is required to activate your account for interstate trips.'),
      const Gap(12),
      TextFormField(controller: _enCtrl, style: _t(15), textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded))),
      const Gap(12),
      TextFormField(controller: _epCtrl, keyboardType: TextInputType.phone,
          style: _t(15), textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined))),
      const Gap(12),
      TextFormField(controller: _erCtrl, style: _t(15), textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
              labelText: 'Relationship (e.g. Parent, Spouse)',
              prefixIcon: Icon(Icons.supervisor_account_outlined))),

      if (_err != null) ...[const Gap(14), Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _kRed.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kRed.withOpacity(0.25))),
          child: Text(_err!, style: _t(13, c: _kRed))).animate().shake(hz: 4)],

      const Gap(28),

      FilledButton(
        onPressed: _saving || _uploadingProfile || _uploadingNin ? null : _save,
        style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
        child: _saving ? const _Spinner()
            : Text('Save & Continue', style: _t(16, w: FontWeight.w700, c: Colors.white)),
      ),
      const Gap(12),
      TextButton(
        onPressed: widget.onComplete,
        child: Text('Skip for now — complete later', style: _t(13, c: _kTxtMuted)),
      ),
    ]),
  );

  Widget _infoBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _kBrand.withOpacity(0.06), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBrand.withOpacity(0.25))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline_rounded, color: _kBrand, size: 15), const Gap(8),
      Expanded(child: Text(msg, style: _t(12, c: _kTxtSub))),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// HOME PAGE (tab shell)
// ═════════════════════════════════════════════════════════════════════════════

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store, required this.session});
  final StorageService store; final AuthSession session;
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  late final ApiService _api;
  int _idx = 0;
  late AuthSession _session;
  @override
  void initState() { super.initState(); _api = ApiService(widget.store); _session = widget.session; }

  Future<void> _logout() async {
    await widget.store.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage(store: widget.store)), (_) => false);
  }

  void _refreshSession(RiderUser user) {
    setState(() => _session = AuthSession(token: _session.token, user: user));
    widget.store.saveSession(_session);
  }

  @override
  Widget build(BuildContext ctx) {
    final pages = [
      _BrowseTab(api: _api, session: _session),
      _BookingsTab(api: _api),
      _SupportTab(api: _api),
      _ProfileTab(api: _api, store: widget.store, session: _session,
          onLogout: _logout, onProfileUpdated: _refreshSession),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [const _Logo(size: 28), const Gap(10), Text('RydeCircle', style: _h(16))]),
        actions: [
          // Profile completion badge
          if (!_session.user.profileCompleted)
            GestureDetector(
              onTap: () => setState(() => _idx = 3), // go to profile
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _kAmber.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kAmber.withOpacity(0.4))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.warning_amber_rounded, size: 13, color: _kAmber),
                  const Gap(5),
                  Text('Complete profile', style: _t(11, c: _kAmber, w: FontWeight.w600)),
                ]),
              ),
            ),
        ],
      ),
      body: IndexedStack(index: _idx, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
        child: NavigationBar(
          selectedIndex: _idx,
          onDestinationSelected: (v) => setState(() => _idx = v),
          height: 64,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search_rounded), label: 'Browse'),
            NavigationDestination(icon: Icon(Icons.confirmation_num_outlined), selectedIcon: Icon(Icons.confirmation_num_rounded), label: 'My Trips'),
            NavigationDestination(icon: Icon(Icons.headset_mic_outlined), selectedIcon: Icon(Icons.headset_mic_rounded), label: 'Support'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BROWSE TAB
// ═════════════════════════════════════════════════════════════════════════════

class _BrowseTab extends StatefulWidget {
  const _BrowseTab({required this.api, required this.session});
  final ApiService api; final AuthSession session;
  @override State<_BrowseTab> createState() => _BrowseTabState();
}
class _BrowseTabState extends State<_BrowseTab> {
  bool _loading = false, _searched = false;
  String? _err;
  List<TripResult> _trips = [];
  final _dateCtrl = TextEditingController();
  String? _selDate;
  @override void initState() { super.initState(); _search(); }
  @override void dispose() { _dateCtrl.dispose(); super.dispose(); }

  Future<void> _search() async {
    setState(() { _loading = true; _err = null; });
    try {
      final trips = await widget.api.searchTrips(date: _selDate);
      if (mounted) setState(() { _trips = trips; _loading = false; _searched = true; });
    } catch (e) {
      if (mounted) setState(() { _err = '$e'; _loading = false; _searched = true; });
    }
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(context: context,
        firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)),
        initialDate: DateTime.now(),
        builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _kBrand)), child: child!));
    if (p != null) setState(() {
      _selDate = DateFormat('yyyy-MM-dd').format(p);
      _dateCtrl.text = DateFormat('d MMM yyyy').format(p);
    });
  }

  @override
  Widget build(BuildContext ctx) => Column(children: [
    // Search header
    Container(color: _kCard, padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(children: [
        Expanded(child: GestureDetector(onTap: _pickDate, child: AbsorbPointer(
            child: TextField(controller: _dateCtrl, style: _t(15),
                decoration: InputDecoration(labelText: 'Date', hintText: 'Today',
                    hintStyle: _t(14, c: _kTxtMuted), prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: _selDate != null ? IconButton(
                        onPressed: () => setState(() { _selDate = null; _dateCtrl.clear(); }),
                        icon: const Icon(Icons.clear, size: 16, color: _kTxtMuted)) : null))))),
        const Gap(10),
        FilledButton(onPressed: _loading ? null : _search,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
            child: _loading ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search_rounded, size: 20)),
      ]),
    ),
    Expanded(child: _loading
        ? ListView(padding: const EdgeInsets.all(16), children: [_shims(n: 5, h: 130)])
        : !_searched ? _EmptyState(icon: Icons.search_rounded, message: 'Search for available trips')
        : _err != null ? ListView(padding: const EdgeInsets.all(16),
            children: [_ErrBar(message: _err!, onRetry: _search)])
        : _trips.isEmpty ? _EmptyState(icon: Icons.directions_car_outlined,
            message: 'No trips available', sub: 'Try a different date')
        : RefreshIndicator(onRefresh: _search, color: _kBrand, backgroundColor: _kCard,
            child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: _trips.length,
                itemBuilder: (_, i) => _TripCard(trip: _trips[i], session: widget.session, api: widget.api,
                    onBooked: _search)
                    .animate(delay: Duration(milliseconds: i * 55)).fadeIn().slideX(begin: 0.04)))),
  ]);
}

// ─── Trip card ────────────────────────────────────────────────────────────────
class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.session, required this.api, required this.onBooked});
  final TripResult trip; final AuthSession session; final ApiService api; final VoidCallback onBooked;
  @override
  Widget build(BuildContext ctx) {
    final left = trip.seatsLeft; final full = left <= 0;
    return GestureDetector(
      onTap: full ? null : () => Navigator.push(ctx, MaterialPageRoute(
          builder: (_) => BookingPage(trip: trip, session: session, api: api, onBooked: onBooked))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: full ? _kBorder : _kBrand.withOpacity(0.3))),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
                gradient: full ? null : LinearGradient(colors: [_kBrand.withOpacity(0.07), Colors.transparent]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
            child: Row(children: [
              Expanded(child: Text(trip.route?.isNotEmpty == true ? trip.route! : '${trip.pickupStop} → ${trip.dropoffStop}',
                  style: _t(15, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: (full ? _kRed : _kGreen).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(full ? 'Full' : '$left seat${left != 1 ? 's' : ''} left',
                      style: _t(11, w: FontWeight.w700, c: full ? _kRed : _kGreen))),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: Column(children: [
            Row(children: [
              const Icon(Icons.radio_button_checked, size: 11, color: _kBrand), const Gap(6),
              Expanded(child: Text(trip.pickupStop, style: _t(12, c: _kTxtSub))),
            ]),
            Padding(padding: const EdgeInsets.only(left: 4.5),
                child: Container(width: 2, height: 10, color: _kBorder)),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 11, color: _kGreen), const Gap(6),
              Expanded(child: Text(trip.dropoffStop, style: _t(12, c: _kTxtSub))),
            ]),
            const Gap(10), Container(height: 1, color: _kBorder), const Gap(10),
            Row(children: [
              _ic(Icons.access_time_rounded, trip.departureTime),
              const Gap(14),
              _ic(Icons.calendar_today_outlined, trip.departureDate),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmt(trip.fare), style: _h(16, w: FontWeight.w700, c: _kBrand)),
                Text('per seat', style: _t(10, c: _kTxtMuted)),
              ]),
            ]),
            if ((trip.driverName ?? '').isNotEmpty) ...[
              const Gap(8), Container(height: 1, color: _kBorder), const Gap(8),
              Row(children: [
                const Icon(Icons.person_outline_rounded, size: 12, color: _kTxtMuted), const Gap(5),
                Text(trip.driverName!, style: _t(12, c: _kTxtSub)),
                if ((trip.plateNumber ?? '').isNotEmpty) ...[
                  const Gap(10), const Icon(Icons.directions_car_outlined, size: 12, color: _kTxtMuted),
                  const Gap(4), Text(trip.plateNumber!, style: _t(12, c: _kTxtSub)),
                ],
                const Spacer(),
                if (!full) Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Book', style: _t(12, c: _kBrand, w: FontWeight.w600)), const Gap(3),
                  const Icon(Icons.arrow_forward_rounded, size: 13, color: _kBrand),
                ]),
              ]),
            ],
          ])),
        ]),
      ),
    );
  }
  Widget _ic(IconData i, String v) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(i, size: 12, color: _kTxtMuted), const Gap(4), Text(v, style: _t(12, c: _kTxtMuted))]);
}

// ═════════════════════════════════════════════════════════════════════════════
// BOOKING PAGE  (Paystack)
// ═════════════════════════════════════════════════════════════════════════════

class BookingPage extends StatefulWidget {
  const BookingPage({super.key, required this.trip, required this.session,
    required this.api, required this.onBooked});
  final TripResult trip; final AuthSession session; final ApiService api; final VoidCallback onBooked;
  @override State<BookingPage> createState() => _BookingPageState();
}
class _BookingPageState extends State<BookingPage> {
  int _seats = 1;
  bool _loading = false;
  String? _err;

  double get _total => widget.trip.fare * _seats;
  int    get _kobo  => (_total * 100).round();
  int    get _max   => widget.trip.seatsLeft.clamp(1, 6);

  String _ref() {
    final ts  = DateTime.now().millisecondsSinceEpoch;
    final tid = widget.trip.id.replaceAll('-', '').substring(0, 8);
    final uid = widget.session.user.id.replaceAll('-', '').substring(0, 8);
    return 'RC-$tid-$uid-$ts';
  }

  Future<void> _pay() async {
    if (AppConfig.paystackKey.isEmpty) {
      setState(() => _err = 'Paystack key not set. Add --dart-define=PAYSTACK_PUBLIC_KEY=pk_test_xxx to your build.');
      return;
    }
    setState(() { _loading = true; _err = null; });
    final ref = _ref();
    try {
      await FlutterPaystackPlus.openPaystackPopup(
        context:       context,
        secretKey:     AppConfig.paystackKey,   // use pk_test_xxx for testing
        customerEmail: widget.session.user.email,
        reference:     ref,
        amount:        _kobo.toString(),          // in kobo
        currency:      'NGN',
        callBackUrl:   'https://rydecircle.com/payment-complete',
        onSuccess: () async {
          // Payment succeeded — create booking on backend
          try {
            final booking = await widget.api.createBooking(
                tripId: widget.trip.id, seats: _seats, paymentRef: ref);
            if (!mounted) return;
            widget.onBooked();
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => BookingConfirmedPage(booking: booking)));
          } catch (e) {
            if (mounted) setState(() => _err = 'Booking failed after payment: \$e');
          }
        },
        onClosed: () {
          if (mounted) setState(() { _err = 'Payment was cancelled'; _loading = false; });
        },
      );
    } catch (e) {
      if (mounted) setState(() => _err = '\$e');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Book Trip', style: _h(16))),
    body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      // Trip summary
      Container(padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kBrand.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.trip.route?.isNotEmpty == true
                ? widget.trip.route!
                : '${widget.trip.pickupStop} → ${widget.trip.dropoffStop}',
                style: _t(16, w: FontWeight.w700)),
            const Gap(12),
            Row(children: [
              _il(Icons.access_time_rounded, widget.trip.departureTime),
              const Gap(14), _il(Icons.calendar_today_outlined, widget.trip.departureDate),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmt(widget.trip.fare), style: _h(18, w: FontWeight.w700, c: _kBrand)),
                Text('per seat', style: _t(10, c: _kTxtMuted)),
              ]),
            ]),
            if ((widget.trip.driverName ?? '').isNotEmpty) ...[
              const Gap(10), const Divider(color: _kBorder, height: 1), const Gap(10),
              Row(children: [
                const Icon(Icons.person_outline_rounded, size: 13, color: _kTxtMuted), const Gap(6),
                Text(widget.trip.driverName!, style: _t(13, c: _kTxtSub)),
                if ((widget.trip.plateNumber ?? '').isNotEmpty) ...[
                  const Gap(12), const Icon(Icons.directions_car_outlined, size: 13, color: _kTxtMuted),
                  const Gap(4), Text(widget.trip.plateNumber!, style: _t(13, c: _kTxtSub)),
                ],
              ]),
            ],
          ])),
      const Gap(20),
      _secLabel('Number of Seats'),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder)),
        child: Row(children: [
          Text('Seats', style: _t(15)),
          const Spacer(),
          IconButton(onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              color: _seats > 1 ? _kBrand : _kTxtMuted,
              padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('$_seats', style: _h(22))),
          IconButton(onPressed: _seats < _max ? () => setState(() => _seats++) : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: _seats < _max ? _kBrand : _kTxtMuted,
              padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
      ),
      const Gap(20),
      // Total banner
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(gradient: _kBrandGrad, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _kBrand.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))]),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total due', style: _t(12, c: Colors.white70)),
            Text(fmt(_total), style: _h(28, c: Colors.white)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$_seats seat${_seats != 1 ? 's' : ''}', style: _t(12, c: Colors.white70)),
            Text('× ${fmt(widget.trip.fare)}', style: _t(12, c: Colors.white60)),
          ]),
        ]),
      ),
      const Gap(14),
      // Paystack badge
      Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBrand.withOpacity(0.25))),
          child: Row(children: [
            Container(width: 40, height: 40,
                decoration: BoxDecoration(gradient: _kBrandGrad, borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: _kBrand.withOpacity(0.3), blurRadius: 8)]),
                child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 20)),
            const Gap(12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pay securely with Paystack', style: _t(14, w: FontWeight.w600)),
              Text('Card · Bank transfer · USSD · QR code', style: _t(12, c: _kTxtMuted)),
            ])),
            const Icon(Icons.verified_rounded, color: _kGreen, size: 18),
          ])),
      if (_err != null) ...[const Gap(12),
        Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _kRed.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kRed.withOpacity(0.25))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline, color: _kRed, size: 15), const Gap(8),
              Expanded(child: Text(_err!, style: _t(13, c: _kRed))),
            ])).animate().shake(hz: 4)],
      const Gap(20),
      SizedBox(width: double.infinity, child: FilledButton(
        onPressed: _loading ? null : _pay,
        style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: _loading ? const _Spinner()
            : Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_rounded, size: 15, color: Colors.white), const Gap(8),
                Text('Pay ${fmt(_total)} with Paystack', style: _t(16, w: FontWeight.w700, c: Colors.white)),
              ]),
      )),
      const Gap(8),
      Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.security_rounded, size: 12, color: _kTxtMuted), const Gap(5),
        Text('Payments encrypted and secured by Paystack', style: _t(11, c: _kTxtMuted)),
      ])),
    ]),
  );
  Widget _il(IconData ic, String v) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(ic, size: 12, color: _kTxtMuted), const Gap(4), Text(v, style: _t(12, c: _kTxtMuted))]);
}

// ─── Booking Confirmed ────────────────────────────────────────────────────────
class BookingConfirmedPage extends StatelessWidget {
  const BookingConfirmedPage({super.key, required this.booking});
  final Booking booking;
  @override
  Widget build(BuildContext ctx) => Scaffold(
    body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 90, height: 90,
            decoration: BoxDecoration(gradient: _kGreenGrad, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _kGreen.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))]),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 46))
            .animate().scale(begin: const Offset(0, 0), curve: Curves.elasticOut, duration: 800.ms),
        const Gap(28),
        Text('Booking Confirmed!', style: _h(26)).animate().fadeIn(delay: 400.ms),
        const Gap(10),
        Text('Show this to your driver on the day of travel.',
            style: _t(14, c: _kTxtSub), textAlign: TextAlign.center).animate().fadeIn(delay: 500.ms),
        const Gap(30),
        Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorder)),
            child: Column(children: [
              _r('Booking Ref', booking.id.substring(0, 8).toUpperCase()),
              _r('Seats Booked', '${booking.seats}'),
              _r('Total Paid', fmt(booking.fare)),
              _r('Payment', booking.paymentStatus == 'paid' ? '✓ Paid' : 'Pending'),
            ])).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
        const Gap(28),
        SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => Navigator.of(ctx).popUntil((r) => r.isFirst),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            child: Text('Done', style: _t(16, w: FontWeight.w700, c: Colors.white))))
            .animate().fadeIn(delay: 700.ms),
      ]),
    ))),
  );
  Widget _r(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [Text(l, style: _t(13, c: _kTxtMuted)), const Spacer(),
        Text(v, style: _t(13, w: FontWeight.w700))]));
}

// ═════════════════════════════════════════════════════════════════════════════
// BOOKINGS TAB
// ═════════════════════════════════════════════════════════════════════════════

class _BookingsTab extends StatefulWidget {
  const _BookingsTab({required this.api});
  final ApiService api;
  @override State<_BookingsTab> createState() => _BookingsTabState();
}
class _BookingsTabState extends State<_BookingsTab> with SingleTickerProviderStateMixin {
  bool _loading = true; String? _err;
  List<Booking> _bookings = [];
  late TabController _tc;
  @override void initState() { super.initState(); _tc = TabController(length: 3, vsync: this); _load(); }
  @override void dispose() { _tc.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    try {
      final b = await widget.api.getMyBookings();
      if (mounted) setState(() { _bookings = b; _loading = false; });
    } catch (e) { if (mounted) setState(() { _err = '$e'; _loading = false; }); }
  }

  List<Booking> _f(String f) {
    if (f == 'all') return _bookings;
    if (f == 'active') return _bookings.where((b) =>
        ['confirmed','in_progress','pending'].contains(b.status.toLowerCase())).toList();
    return _bookings.where((b) => ['completed','cancelled'].contains(b.status.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext ctx) => Column(children: [
    Container(color: _kCard, child: TabBar(controller: _tc,
      labelColor: _kBrand, unselectedLabelColor: _kTxtMuted,
      indicatorColor: _kBrand, indicatorSize: TabBarIndicatorSize.label,
      labelStyle: _t(13, w: FontWeight.w600),
      tabs: const [Tab(text: 'All'), Tab(text: 'Upcoming'), Tab(text: 'Past')],
    )),
    Expanded(child: _loading
        ? ListView(padding: const EdgeInsets.all(16), children: [_shims(n: 5, h: 120)])
        : TabBarView(controller: _tc, children: ['all','active','done'].map((f) {
            final list = _f(f);
            return RefreshIndicator(onRefresh: _load, color: _kBrand, backgroundColor: _kCard,
              child: list.isEmpty && _err == null
                  ? _EmptyState(icon: Icons.confirmation_num_outlined, message: 'No bookings here')
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
                      if (_err != null) _ErrBar(message: _err!, onRetry: _load),
                      ...list.asMap().entries.map((e) => _BookingCard(b: e.value, api: widget.api, onRefresh: _load)
                          .animate(delay: Duration(milliseconds: e.key * 55)).fadeIn().slideX(begin: 0.04)),
                    ]));
          }).toList())),
  ]);
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.b, required this.api, required this.onRefresh});
  final Booking b; final ApiService api; final VoidCallback onRefresh;
  @override
  Widget build(BuildContext ctx) {
    final sc = _bsc(b.status); final active = b.status.toLowerCase() == 'in_progress';
    final canConfirm = active && !b.passengerConfirmedDropoff;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? _kBrand.withOpacity(0.3) : _kBorder)),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(b.route ?? '${b.pickupStop} → ${b.dropoffStop}',
                style: _t(15, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(b.status, style: _t(11, w: FontWeight.w700, c: sc))),
          ]),
          if ((b.departureDate ?? '').isNotEmpty) ...[const Gap(8),
            Row(children: [const Icon(Icons.calendar_today_outlined, size: 12, color: _kTxtMuted), const Gap(4),
              Text('${b.departureDate}  ${b.departureTime ?? ''}', style: _t(12, c: _kTxtMuted))])],
          const Gap(10),
          Row(children: [
            _si(Icons.event_seat_outlined, '${b.seats} seat${b.seats != 1 ? 's' : ''}'),
            const Gap(14),
            _si(Icons.payments_outlined, fmt(b.fare)),
            const Gap(14),
            _si(b.paymentStatus == 'paid' ? Icons.check_circle_outline_rounded : Icons.pending_outlined,
                b.paymentStatus, c: b.paymentStatus == 'paid' ? _kGreen : _kAmber),
          ]),
          if (active) ...[const Gap(10), const Divider(color: _kBorder, height: 1), const Gap(8),
            Row(children: [
              Icon(b.passengerConfirmedDropoff ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 14, color: b.passengerConfirmedDropoff ? _kGreen : _kAmber), const Gap(6),
              Text(b.passengerConfirmedDropoff ? 'Dropoff confirmed ✓' : 'Confirm when you arrive',
                  style: _t(12, c: b.passengerConfirmedDropoff ? _kGreen : _kAmber)),
            ])],
        ])),
        if (canConfirm)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _confirm(ctx),
              icon: const Icon(Icons.location_on_rounded, size: 16),
              label: Text("I've arrived at my stop", style: _t(14, w: FontWeight.w700, c: Colors.white)),
              style: FilledButton.styleFrom(backgroundColor: _kGreen, minimumSize: const Size(double.infinity, 46)),
            ))),
      ]),
    );
  }

  Future<void> _confirm(BuildContext ctx) async {
    final ok = await showDialog<bool>(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Confirm Dropoff?', style: _h(18)),
      content: Text('Only confirm once you have been dropped at your stop. This helps the driver end the trip.',
          style: _t(14, c: _kTxtSub)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Not yet', style: _t(14, c: _kTxtMuted))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _kGreen),
            child: Text("Yes, I'm here", style: _t(14, w: FontWeight.w700, c: Colors.white))),
      ],
    ));
    if (ok != true || !ctx.mounted) return;
    try {
      await api.confirmDropoff(b.tripId, b.id);
      if (!ctx.mounted) return;
      _snack(ctx, 'Arrival confirmed ✓');
      onRefresh();
    } catch (e) {
      if (!ctx.mounted) return;
      _snack(ctx, '$e', bg: _kRed);
    }
  }

  Widget _si(IconData ic, String v, {Color? c}) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(ic, size: 12, color: c ?? _kTxtMuted), const Gap(4), Text(v, style: _t(12, c: c ?? _kTxtSub))]);
}

// ═════════════════════════════════════════════════════════════════════════════
// SUPPORT TAB
// ═════════════════════════════════════════════════════════════════════════════

class _SupportTab extends StatefulWidget {
  const _SupportTab({required this.api});
  final ApiService api;
  @override State<_SupportTab> createState() => _SupportTabState();
}
class _SupportTabState extends State<_SupportTab> {
  bool _loading = true, _submitting = false, _expanded = false;
  String? _err;
  List<SupportTicket> _tickets = [];
  final _subCtrl = TextEditingController(); final _msgCtrl = TextEditingController();
  String _cat = 'Trip Issue';
  static const _cats = ['Trip Issue', 'Payment', 'Account', 'Booking', 'Other'];
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _subCtrl.dispose(); _msgCtrl.dispose(); super.dispose(); }
  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    try { final t = await widget.api.getTickets(); if (mounted) setState(() { _tickets = t; _loading = false; }); }
    catch (e) { if (mounted) setState(() { _err = '$e'; _loading = false; }); }
  }
  Future<void> _submit() async {
    final sub = _subCtrl.text.trim(); final msg = _msgCtrl.text.trim();
    if (sub.isEmpty || msg.isEmpty) { setState(() => _err = 'Subject and message are required'); return; }
    setState(() { _submitting = true; _err = null; });
    try {
      await widget.api.createTicket(subject: sub, category: _cat, message: msg);
      _subCtrl.clear(); _msgCtrl.clear();
      setState(() => _expanded = false);
      await _load();
      if (!mounted) return;
      _snack(context, 'Ticket submitted ✓');
    } catch (e) { if (mounted) setState(() { _err = '$e'; _submitting = false; }); }
    finally { if (mounted) setState(() => _submitting = false); }
  }

  @override
  Widget build(BuildContext ctx) => RefreshIndicator(onRefresh: _load, color: _kBrand, backgroundColor: _kCard,
    child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      AnimatedCrossFade(
        duration: 300.ms, crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () => setState(() => _expanded = true),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: Text('New Support Request', style: _t(15, w: FontWeight.w700, c: Colors.white)),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)))),
        secondChild: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text('New Request', style: _h(16)), const Spacer(),
              IconButton(onPressed: () => setState(() { _expanded = false; _err = null; }),
                  icon: const Icon(Icons.close_rounded, color: _kTxtMuted), padding: EdgeInsets.zero, constraints: const BoxConstraints())]),
            const Gap(14),
            TextField(controller: _subCtrl, style: _t(15),
                decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.title_rounded))),
            const Gap(12),
            Text('Category', style: _t(13, c: _kTxtMuted)),
            const Gap(8),
            Wrap(spacing: 8, runSpacing: 8, children: _cats.map((c) => GestureDetector(
              onTap: () => setState(() => _cat = c),
              child: AnimatedContainer(duration: 200.ms,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: _cat == c ? _kBrand.withOpacity(0.12) : _kCardEl,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _cat == c ? _kBrand.withOpacity(0.5) : _kBorder)),
                child: Text(c, style: _t(13, c: _cat == c ? _kBrand : _kTxtSub,
                    w: _cat == c ? FontWeight.w600 : FontWeight.w400))),
            )).toList()),
            const Gap(12),
            TextField(controller: _msgCtrl, minLines: 4, maxLines: 7, style: _t(15),
                decoration: const InputDecoration(labelText: 'Describe your issue', alignLabelWithHint: true)),
            if (_err != null) ...[const Gap(10),
              Text(_err!, style: _t(13, c: _kRed))],
            const Gap(16),
            SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting ? const _Spinner() : const Icon(Icons.send_rounded, size: 16),
                label: Text(_submitting ? 'Sending…' : 'Submit', style: _t(15, w: FontWeight.w700, c: Colors.white)),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)))),
          ]),
        ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.05),
      ),
      const Gap(20),
      _secLabel('My Tickets'),
      if (_loading) _shims(n: 3, h: 100)
      else if (_tickets.isEmpty) _EmptyState(icon: Icons.support_agent_rounded, message: 'No tickets yet',
          sub: 'Tap "New Support Request" above to get help')
      else AnimationLimiter(child: Column(children: AnimationConfiguration.toStaggeredList(
        duration: 380.ms,
        childAnimationBuilder: (w) => SlideAnimation(verticalOffset: 20, child: FadeInAnimation(child: w)),
        children: _tickets.map((t) {
          final open = t.status.toLowerCase() == 'open';
          final sc = open ? _kBrand : t.status.toLowerCase() == 'resolved' ? _kGreen : _kTxtMuted;
          return Container(margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(18),
                border: Border.all(color: open ? _kBrand.withOpacity(0.25) : _kBorder)),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(t.subject, style: _t(14, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(t.status, style: _t(11, w: FontWeight.w700, c: sc))),
              ]),
              if ((t.category ?? '').isNotEmpty) ...[const Gap(3), Text(t.category!, style: _t(12, c: _kTxtMuted))],
              if (t.message.isNotEmpty) ...[const Gap(6),
                Text(t.message, style: _t(13, c: _kTxtSub), maxLines: 3, overflow: TextOverflow.ellipsis)],
            ])),
          );
        }).toList()))),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.api, required this.store, required this.session,
    required this.onLogout, required this.onProfileUpdated});
  final ApiService api; final StorageService store; final AuthSession session;
  final Future<void> Function() onLogout;
  final void Function(RiderUser) onProfileUpdated;
  @override State<_ProfileTab> createState() => _ProfileTabState();
}
class _ProfileTabState extends State<_ProfileTab> {
  bool _loading = true; String? _err; RiderUser? _user;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    try {
      final u = await widget.api.getMe();
      if (mounted) { setState(() { _user = u; _loading = false; }); widget.onProfileUpdated(u); }
    } catch (e) {
      if (mounted) setState(() { _user = widget.session.user; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final u = _user ?? widget.session.user;
    final initials = u.fullName.isNotEmpty
        ? u.fullName.split(' ').take(2).map((n) => n.isNotEmpty ? n[0].toUpperCase() : '').join() : '?';
    final pct = _profilePct(u);

    return RefreshIndicator(onRefresh: _load, color: _kBrand, backgroundColor: _kCard,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [

        // ── Avatar / hero ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: _kBrandGrad, borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: _kBrand.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))]),
          child: Row(children: [
            Container(width: 70, height: 70,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
              child: ClipOval(child: u.profileImageUrl?.isNotEmpty == true
                  ? CachedNetworkImage(imageUrl: u.profileImageUrl!, fit: BoxFit.cover,
                      placeholder: (_, __) => Center(child: Text(initials, style: _h(26, c: Colors.white))),
                      errorWidget: (_, __, ___) => Center(child: Text(initials, style: _h(26, c: Colors.white))))
                  : Center(child: Text(initials, style: _h(26, c: Colors.white)))),
            ),
            const Gap(16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.fullName.isEmpty ? 'Rider' : u.fullName, style: _h(20, c: Colors.white)),
              const Gap(3), Text(u.email, style: _t(13, c: Colors.white70)),
              const Gap(6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(u.status?.isEmpty == false ? (u.status ?? 'Active') : 'Active',
                      style: _t(12, c: Colors.white, w: FontWeight.w600))),
            ])),
          ]),
        ).animate().fadeIn(duration: 500.ms),

        // ── Profile completion ────────────────────────────────────────────────
        if (!u.profileCompleted) ...[
          const Gap(14),
          GestureDetector(
            onTap: () => Navigator.push(ctx, MaterialPageRoute(
                builder: (_) => EditProfilePage(api: widget.api, store: widget.store, user: u,
                    onSaved: (updated) { _load(); widget.onProfileUpdated(updated); }))),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _kAmber.withOpacity(0.06), borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kAmber.withOpacity(0.35))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: _kAmber, size: 16), const Gap(8),
                  Text('Profile incomplete', style: _t(14, w: FontWeight.w700, c: _kAmber)),
                  const Spacer(),
                  Text('Complete now →', style: _t(12, c: _kAmber)),
                ]),
                const Gap(10),
                LinearPercentIndicator(percent: pct, lineHeight: 6,
                    backgroundColor: _kAmber.withOpacity(0.2), progressColor: _kAmber,
                    barRadius: const Radius.circular(3), padding: EdgeInsets.zero,
                    animation: true, animationDuration: 800),
                const Gap(6),
                Text('${(pct * 100).round()}% complete — add NIN, photo & emergency contact',
                    style: _t(11, c: _kAmber.withOpacity(0.8))),
              ]),
            ),
          ),
        ],

        const Gap(16),

        // ── Personal info ─────────────────────────────────────────────────────
        _secLabel('Personal Information'),
        _infoCard([
          _pr(Icons.person_outline_rounded, 'Name', u.fullName),
          _pr(Icons.mail_outline_rounded, 'Email', u.email),
          _pr(Icons.phone_outlined, 'Phone', u.phone),
          _pr(Icons.location_on_outlined, 'Area', u.area ?? '—', last: true),
        ]),
        const Gap(14),

        // ── Identity ──────────────────────────────────────────────────────────
        _secLabel('Identity'),
        _infoCard([
          _prBadge('NIN', u.nin ?? '—', u.nin != null, 'Verified', 'Not provided'),
          _prBadge('NIN Image', u.ninImageUrl != null ? 'Uploaded ✓' : '—',
              u.ninImageUrl != null, 'Uploaded', 'Not uploaded', last: true),
        ]),
        if (u.ninImageUrl?.isNotEmpty == true) ...[
          const Gap(8),
          ClipRRect(borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(imageUrl: u.ninImageUrl!, height: 120, width: double.infinity,
                  fit: BoxFit.cover, placeholder: (_, __) => Container(height: 120, color: _kCardEl),
                  errorWidget: (_, __, ___) => Container(height: 120, color: _kCardEl,
                      child: const Center(child: Icon(Icons.broken_image_outlined, color: _kTxtMuted))))),
        ],
        const Gap(14),

        // ── Emergency contact ─────────────────────────────────────────────────
        _secLabel('Emergency Contact'),
        _infoCard([
          _pr(Icons.person_outline_rounded, 'Name', u.emergencyName ?? '—'),
          _pr(Icons.phone_outlined, 'Phone', u.emergencyPhone ?? '—'),
          _pr(Icons.supervisor_account_outlined, 'Relationship', u.emergencyRelationship ?? '—', last: true),
        ]),

        const Gap(20),

        // ── Actions ───────────────────────────────────────────────────────────
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => Navigator.push(ctx, MaterialPageRoute(
                builder: (_) => EditProfilePage(api: widget.api, store: widget.store, user: u,
                    onSaved: (updated) { _load(); widget.onProfileUpdated(updated); }))),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text('Edit Profile & Documents', style: _t(14)),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)))),
        const Gap(10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => Navigator.push(ctx, MaterialPageRoute(
                builder: (_) => _ChangePasswordPage(api: widget.api))),
            icon: const Icon(Icons.lock_outline_rounded, size: 16),
            label: Text('Change Password', style: _t(14)),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)))),
        const Gap(10),
        SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: Text('Sign Out', style: _t(14, w: FontWeight.w700, c: Colors.white)),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800,
                minimumSize: const Size(double.infinity, 50)))),
      ]),
    );
  }

  double _profilePct(RiderUser u) {
    int done = 0;
    if (u.nin?.isNotEmpty == true) done++;
    if (u.ninImageUrl?.isNotEmpty == true) done++;
    if (u.emergencyName?.isNotEmpty == true) done++;
    if (u.emergencyPhone?.isNotEmpty == true) done++;
    if (u.emergencyRelationship?.isNotEmpty == true) done++;
    if (u.profileImageUrl?.isNotEmpty == true) done++;
    return done / 6;
  }

  Widget _infoCard(List<Widget> rows) => Container(
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder)),
      child: Column(children: rows));

  Widget _pr(IconData ic, String l, String v, {bool last = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: _kBorder, width: 0.5))),
    child: Row(children: [Icon(ic, size: 16, color: _kTxtMuted), const Gap(12),
      Expanded(child: Text(l, style: _t(13, c: _kTxtMuted))),
      Flexible(child: Text(v.isEmpty ? '—' : v, textAlign: TextAlign.right, style: _t(13, w: FontWeight.w600))),
    ]),
  );

  Widget _prBadge(String l, String v, bool done, String yes, String no, {bool last = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: _kBorder, width: 0.5))),
    child: Row(children: [
      Icon(done ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16,
          color: done ? _kGreen : _kTxtMuted),
      const Gap(12),
      Expanded(child: Text(l, style: _t(13, c: _kTxtMuted))),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: (done ? _kGreen : _kAmber).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Text(done ? yes : no, style: _t(11, w: FontWeight.w700, c: done ? _kGreen : _kAmber))),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// EDIT PROFILE PAGE  (reuses _Step2Form for NIN/emergency/photo)
// ═════════════════════════════════════════════════════════════════════════════

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.api, required this.store,
    required this.user, required this.onSaved});
  final ApiService api; final StorageService store;
  final RiderUser user; final void Function(RiderUser) onSaved;
  @override State<EditProfilePage> createState() => _EditProfilePageState();
}
class _EditProfilePageState extends State<EditProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override void initState() { super.initState(); _tc = TabController(length: 2, vsync: this); }
  @override void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Edit Profile', style: _h(17))),
    body: Column(children: [
      Container(color: _kCard, child: TabBar(controller: _tc,
          labelColor: _kBrand, unselectedLabelColor: _kTxtMuted,
          indicatorColor: _kBrand, indicatorSize: TabBarIndicatorSize.label,
          labelStyle: _t(13, w: FontWeight.w600),
          tabs: const [Tab(text: 'Basic Info'), Tab(text: 'Documents & Emergency')])),
      Expanded(child: TabBarView(controller: _tc, children: [
        _BasicInfoForm(api: widget.api, store: widget.store, user: widget.user, onSaved: (u) { widget.onSaved(u); _snack(ctx, 'Saved ✓'); }),
        _Step2Form(api: widget.api, session: AuthSession(
              token: '', user: widget.user),
            store: widget.store, existingUser: widget.user,
            onComplete: () => Navigator.pop(ctx)),
      ])),
    ]),
  );
}

class _BasicInfoForm extends StatefulWidget {
  const _BasicInfoForm({required this.api, required this.store, required this.user, required this.onSaved});
  final ApiService api; final StorageService store; final RiderUser user;
  final void Function(RiderUser) onSaved;
  @override State<_BasicInfoForm> createState() => _BasicInfoFormState();
}
class _BasicInfoFormState extends State<_BasicInfoForm> {
  late final TextEditingController _fn, _ln, _ph, _ar;
  bool _saving = false; String? _err;
  @override
  void initState() {
    super.initState();
    _fn = TextEditingController(text: widget.user.firstName);
    _ln = TextEditingController(text: widget.user.lastName);
    _ph = TextEditingController(text: widget.user.phone);
    _ar = TextEditingController(text: widget.user.area ?? '');
  }
  @override void dispose() { for (final c in [_fn,_ln,_ph,_ar]) c.dispose(); super.dispose(); }
  Future<void> _save() async {
    setState(() { _saving = true; _err = null; });
    try {
      final u = await widget.api.updateProfile({
        'first_name': _fn.text.trim(), 'last_name': _ln.text.trim(),
        'phone': _ph.text.trim(), 'area': _ar.text.trim(),
      });
      if (mounted) { widget.onSaved(u); setState(() => _saving = false); }
    } catch (e) { if (mounted) setState(() { _err = '$e'; _saving = false; }); }
  }

  @override
  Widget build(BuildContext ctx) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _secLabel('Name'),
      Row(children: [
        Expanded(child: TextFormField(controller: _fn, style: _t(15),
            decoration: const InputDecoration(labelText: 'First name'))),
        const Gap(12),
        Expanded(child: TextFormField(controller: _ln, style: _t(15),
            decoration: const InputDecoration(labelText: 'Last name'))),
      ]),
      const Gap(14), _secLabel('Contact'),
      TextFormField(controller: _ph, keyboardType: TextInputType.phone, style: _t(15),
          decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
      const Gap(14), _secLabel('Location'),
      TextFormField(controller: _ar, style: _t(15),
          decoration: const InputDecoration(labelText: 'Area / Neighbourhood',
              prefixIcon: Icon(Icons.location_on_outlined))),
      if (_err != null) ...[const Gap(12),
        Text(_err!, style: _t(13, c: _kRed))],
      const Gap(24),
      FilledButton(onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          child: _saving ? const _Spinner() : Text('Save Changes', style: _t(16, w: FontWeight.w700, c: Colors.white))),
    ]),
  );
}

// ─── Change Password Page ─────────────────────────────────────────────────────
class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage({required this.api});
  final ApiService api;
  @override State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}
class _ChangePasswordPageState extends State<_ChangePasswordPage> {
  final _curCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _cfmCtrl = TextEditingController();
  bool _saving = false, _o1 = true, _o2 = true, _o3 = true;
  String? _err;
  @override void dispose() { for (final c in [_curCtrl,_newCtrl,_cfmCtrl]) c.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_newCtrl.text != _cfmCtrl.text) { setState(() => _err = 'New passwords do not match'); return; }
    if (_newCtrl.text.length < 8) { setState(() => _err = 'New password must be at least 8 characters'); return; }
    setState(() { _saving = true; _err = null; });
    try {
      await widget.api.changePassword(current: _curCtrl.text, next: _newCtrl.text);
      if (!mounted) return;
      _snack(context, 'Password changed ✓');
      Navigator.pop(context);
    } catch (e) { if (mounted) setState(() { _err = '$e'; _saving = false; }); }
  }
  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Change Password', style: _h(17))),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _passField(_curCtrl, 'Current password', _o1, () => setState(() => _o1 = !_o1)),
      const Gap(14),
      _passField(_newCtrl, 'New password (min 8 chars)', _o2, () => setState(() => _o2 = !_o2)),
      const Gap(14),
      _passField(_cfmCtrl, 'Confirm new password', _o3, () => setState(() => _o3 = !_o3)),
      if (_err != null) ...[const Gap(12),
        Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _kRed.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kRed.withOpacity(0.25))),
            child: Text(_err!, style: _t(13, c: _kRed))).animate().shake(hz: 4)],
      const Gap(24),
      FilledButton(onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          child: _saving ? const _Spinner() : Text('Update Password', style: _t(16, w: FontWeight.w700, c: Colors.white))),
    ])),
  );
  Widget _passField(TextEditingController c, String l, bool obs, VoidCallback toggle) =>
      TextFormField(controller: c, obscureText: obs, style: _t(15),
          decoration: InputDecoration(labelText: l, prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(onPressed: toggle,
                  icon: Icon(obs ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _kTxtMuted))));
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════

String _s(Map<String, dynamic> j, List<String> keys, {String fb = ''}) {
  for (final k in keys) { final v = j[k]; if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim(); }
  return fb;
}
int    _i(dynamic v) { if (v == null) return 0; if (v is int) return v; if (v is num) return v.toInt(); return int.tryParse('$v') ?? 0; }
double _d(dynamic v) { if (v == null) return 0; if (v is double) return v; if (v is num) return v.toDouble(); return double.tryParse('$v') ?? 0; }
String fmt(double v) => '₦${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

Color _bsc(String s) {
  switch (s.toLowerCase()) {
    case 'confirmed': return _kGreen;
    case 'in_progress': return _kBrand;
    case 'completed': return Colors.green;
    case 'cancelled': return _kRed;
    default: return _kAmber;
  }
}
