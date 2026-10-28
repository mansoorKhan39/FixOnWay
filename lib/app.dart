import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/admin_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/customer_controller.dart';
import 'controllers/mechanic_controller.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'services/location_service.dart';
import 'services/photo_service.dart';
import 'routes/app_router.dart';

class FixOnWayApp extends StatelessWidget {
  const FixOnWayApp({
    super.key,
    required this.authController,
    required this.customerController,
    required this.mechanicController,
    required this.chatController,
    required this.adminController,
    this.locationService = const LocationService(),
    this.photoService = const PhotoService(),
  });

  final AuthController authController;
  final CustomerController customerController;
  final MechanicController mechanicController;
  final ChatController chatController;
  final AdminController adminController;
  final LocationService locationService;
  final PhotoService photoService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider<CustomerController>.value(
          value: customerController,
        ),
        ChangeNotifierProvider<MechanicController>.value(
          value: mechanicController,
        ),
        ChangeNotifierProvider<ChatController>.value(value: chatController),
        ChangeNotifierProvider<AdminController>.value(value: adminController),
        Provider<LocationService>.value(value: locationService),
        Provider<PhotoService>.value(value: photoService),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: AppRouter.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
